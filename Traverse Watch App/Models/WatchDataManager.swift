//
//  WatchDataManager.swift
//  Traverse Watch App
//
//  Watch-side data layer. Receives data from iPhone via WatchConnectivity
//  and persists it to local UserDefaults for the app and Watch widgets.
//
//  Data flow:
//    iPhone WidgetDataUpdater → WatchSyncManager → (WCSession) → WatchDataManager → UserDefaults
//    Watch widgets read from the same UserDefaults via WatchWidgetDataProvider.
//

import Foundation
import Combine
import WatchConnectivity
import WidgetKit

// MARK: - Shared Data Models (mirrored from widget data)

struct WatchWidgetData: Codable {
    let streak: WatchStreakData?
    let recentSolve: WatchRecentSolveData?
    let revisions: [WatchRevisionData]?
    let revisionsDueCount: Int
    let achievements: WatchAchievementsData?
    let lastUpdated: Date
}

struct WatchStreakData: Codable {
    let currentStreak: Int
    let solvedToday: Bool
    let totalXp: Int
    let totalSolves: Int
}

struct WatchRecentSolveData: Codable {
    let problemTitle: String
    let platform: String
    let difficulty: String
    let xpAwarded: Int
    let solvedAt: String
    let language: String
}

struct WatchRevisionData: Codable, Identifiable {
    let id: Int
    let problemTitle: String
    let slug: String
    let platform: String
    let difficulty: String
    let revisionNumber: Int
    let scheduledFor: String
    let isOverdue: Bool
    
    // Backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        problemTitle = try container.decode(String.self, forKey: .problemTitle)
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        platform = try container.decode(String.self, forKey: .platform)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        revisionNumber = try container.decode(Int.self, forKey: .revisionNumber)
        scheduledFor = try container.decode(String.self, forKey: .scheduledFor)
        isOverdue = try container.decode(Bool.self, forKey: .isOverdue)
    }
    
    var problemURL: String {
        switch platform.lowercased() {
        case "leetcode": return "https://leetcode.com/problems/\(slug)/"
        case "codeforces": return "https://codeforces.com/problemset/problem/\(slug)"
        case "hackerrank": return "https://www.hackerrank.com/challenges/\(slug)/problem"
        default: return "https://google.com/search?q=\(slug)"
        }
    }
    
    var difficultyColor: String {
        switch difficulty.lowercased() {
        case "easy": return "34C759"    // systemGreen
        case "medium": return "FF9F0A"  // systemOrange
        case "hard": return "FF453A"    // systemRed
        default: return "8E8E93"        // systemGray
        }
    }
    
    var platformIcon: String {
        switch platform.lowercased() {
        case "leetcode": return "chevron.left.forwardslash.chevron.right"
        case "codeforces": return "bolt.fill"
        case "hackerrank": return "terminal.fill"
        default: return "doc.text.fill"
        }
    }
}

struct WatchAchievementsData: Codable {
    let unlocked: Int
    let total: Int
}

// MARK: - Sync Status

enum WatchSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(String)
    case waitingForPhone
    
    var displayText: String {
        switch self {
        case .idle:
            return "Not synced"
        case .syncing:
            return "Syncing…"
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .error(let msg):
            return msg
        case .waitingForPhone:
            return "Open iPhone app to sync"
        }
    }
}

// MARK: - Watch Data Manager

class WatchDataManager: NSObject, ObservableObject {
    static let shared = WatchDataManager()
    
    private static let suiteName = "group.com.traverse.app"
    private static let dataKey = "widgetData"
    private static let lastSyncKey = "lastWatchSync"
    
    @Published var data: WatchWidgetData?
    @Published var syncStatus: WatchSyncStatus = .idle
    @Published var isLoading: Bool = false
    
    private let userDefaults: UserDefaults?
    private var session: WCSession?
    private var retryTimer: Timer?
    
    private override init() {
        userDefaults = UserDefaults(suiteName: WatchDataManager.suiteName)
        super.init()
        loadData()
        activateSession()
    }
    
    // MARK: - Computed properties
    
    var streak: Int {
        data?.streak?.currentStreak ?? 0
    }
    
    var solvedToday: Bool {
        data?.streak?.solvedToday ?? false
    }
    
    var totalXp: Int {
        data?.streak?.totalXp ?? 0
    }
    
    var totalSolves: Int {
        data?.streak?.totalSolves ?? 0
    }
    
    var revisionsDueCount: Int {
        data?.revisionsDueCount ?? 0
    }
    
    var revisions: [WatchRevisionData] {
        data?.revisions ?? []
    }
    
    var recentSolve: WatchRecentSolveData? {
        data?.recentSolve
    }
    
    var achievementsUnlocked: Int {
        data?.achievements?.unlocked ?? 0
    }
    
    var achievementsTotal: Int {
        data?.achievements?.total ?? 0
    }
    
    var lastUpdated: Date? {
        data?.lastUpdated
    }
    
    var lastUpdatedString: String {
        guard let date = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - WCSession Activation
    
    private func activateSession() {
        guard WCSession.isSupported() else {
            print("[WatchData] WCSession not supported")
            DispatchQueue.main.async {
                self.syncStatus = .error("Watch connectivity not available")
            }
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        print("[WatchData] WCSession activation requested")
    }
    
    // MARK: - Data Loading (from local UserDefaults)
    
    func loadData() {
        guard let rawData = userDefaults?.data(forKey: WatchDataManager.dataKey),
              let decoded = try? JSONDecoder().decode(WatchWidgetData.self, from: rawData) else {
            self.data = nil
            
            // If we have no data, update sync status
            if syncStatus != .syncing {
                syncStatus = .waitingForPhone
            }
            return
        }
        self.data = decoded
        
        // Update sync status if we haven't set it yet
        if syncStatus == .idle || syncStatus == .waitingForPhone {
            syncStatus = .synced(decoded.lastUpdated)
        }
    }
    
    // MARK: - Data Persistence (to local UserDefaults — feeds Watch widgets too)
    
    private func persistData(_ data: Data) {
        userDefaults?.set(data, forKey: WatchDataManager.dataKey)
        userDefaults?.set(Date(), forKey: WatchDataManager.lastSyncKey)
        userDefaults?.synchronize()
        
        // Reload Watch widget timelines so complications update
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Process Received Data
    
    /// Processes raw data received from iPhone via any WC channel.
    private func processReceivedPayload(_ payload: [String: Any]) {
        guard let rawData = payload["widgetData"] as? Data else {
            print("[WatchData] Received payload missing widgetData key")
            return
        }
        
        // Decode to verify validity
        guard let decoded = try? JSONDecoder().decode(WatchWidgetData.self, from: rawData) else {
            print("[WatchData] Failed to decode received widgetData")
            DispatchQueue.main.async {
                self.syncStatus = .error("Data decode error")
            }
            return
        }
        
        // Check if this data is newer than what we have
        if let existing = self.data, existing.lastUpdated >= decoded.lastUpdated {
            print("[WatchData] Received data is not newer, ignoring")
            return
        }
        
        // Persist to UserDefaults (for widgets)
        persistData(rawData)
        
        // Update in-memory state on main thread
        DispatchQueue.main.async {
            self.data = decoded
            self.syncStatus = .synced(decoded.lastUpdated)
            self.isLoading = false
            print("[WatchData] Data updated from iPhone (last updated: \(decoded.lastUpdated))")
        }
    }
    
    // MARK: - Request Fresh Data from iPhone
    
    /// Actively request data from the iPhone.
    /// Uses sendMessage (requires iPhone app in foreground/reachable).
    /// Falls back to using whatever is in the applicationContext.
    func requestDataFromPhone() {
        guard let session = session,
              session.activationState == .activated else {
            print("[WatchData] Session not activated, can't request data")
            syncStatus = .error("Not connected")
            return
        }
        
        isLoading = true
        syncStatus = .syncing
        
        if session.isReachable {
            // iPhone app is reachable — request fresh data
            session.sendMessage(
                ["action": "requestData"],
                replyHandler: { [weak self] reply in
                    self?.processReceivedPayload(reply)
                },
                errorHandler: { [weak self] error in
                    print("[WatchData] sendMessage failed: \(error)")
                    // Fall back to applicationContext
                    self?.loadFromApplicationContext()
                }
            )
        } else {
            // iPhone not reachable — use cached applicationContext
            print("[WatchData] iPhone not reachable, using applicationContext")
            loadFromApplicationContext()
        }
    }
    
    /// Load data from the last applicationContext (always available after first sync).
    private func loadFromApplicationContext() {
        guard let session = session else { return }
        
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            processReceivedPayload(context)
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
                if self.data == nil {
                    self.syncStatus = .waitingForPhone
                }
            }
        }
    }
    
    // MARK: - Manual Refresh
    
    func refresh() {
        isLoading = true
        syncStatus = .syncing
        
        // Try to get fresh data from iPhone
        requestDataFromPhone()
        
        // Safety timeout — don't leave loading state forever
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.isLoading {
                self.isLoading = false
                if self.data != nil {
                    // We have cached data, just show it
                    self.syncStatus = .synced(self.data!.lastUpdated)
                } else {
                    self.syncStatus = .waitingForPhone
                }
            }
        }
    }
    
    // MARK: - Open Problem on iPhone
    
    /// Ask iPhone to open a problem URL in Safari.
    /// With Handoff enabled, the URL will appear on Mac automatically.
    @Published var urlOpenStatus: String?
    
    func openProblemOnPhone(_ revision: WatchRevisionData) {
        guard let session = session,
              session.activationState == .activated else {
            urlOpenStatus = "Not connected"
            clearStatus()
            return
        }
        
        let url = revision.problemURL
        
        if session.isReachable {
            session.sendMessage(
                ["action": "openURL", "url": url],
                replyHandler: { [weak self] reply in
                    DispatchQueue.main.async {
                        if let status = reply["status"] as? String, status == "opened" {
                            self?.urlOpenStatus = "Opened on iPhone"
                        } else {
                            self?.urlOpenStatus = "Failed to open"
                        }
                        self?.clearStatus()
                    }
                },
                errorHandler: { [weak self] error in
                    print("[WatchData] Failed to send openURL: \(error)")
                    DispatchQueue.main.async {
                        self?.urlOpenStatus = "iPhone not reachable"
                        self?.clearStatus()
                    }
                }
            )
            urlOpenStatus = "Opening…"
        } else {
            urlOpenStatus = "Open iPhone app first"
            clearStatus()
        }
    }
    
    private func clearStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.urlOpenStatus = nil
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchDataManager: WCSessionDelegate {
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WatchData] WCSession activation error: \(error)")
            DispatchQueue.main.async {
                self.syncStatus = .error("Connection error")
            }
            return
        }
        
        switch activationState {
        case .activated:
            print("[WatchData] WCSession activated")
            
            // Check applicationContext for data that arrived while we were inactive
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                processReceivedPayload(context)
            } else if data == nil {
                // No data at all — request from iPhone
                DispatchQueue.main.async {
                    self.requestDataFromPhone()
                }
            }
            
        case .inactive:
            print("[WatchData] WCSession inactive")
        case .notActivated:
            print("[WatchData] WCSession not activated")
        @unknown default:
            print("[WatchData] Unknown WCSession state")
        }
    }
    
    // MARK: Receive applicationContext updates (primary sync channel)
    
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        print("[WatchData] Received applicationContext update")
        processReceivedPayload(applicationContext)
    }
    
    // MARK: Receive transferUserInfo (fallback/guaranteed delivery)
    
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        print("[WatchData] Received userInfo transfer")
        processReceivedPayload(userInfo)
    }
    
    // MARK: Receive instant messages (when Watch app is in foreground)
    
    func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        print("[WatchData] Received instant message data")
        
        // Decode and apply
        if let decoded = try? JSONDecoder().decode(WatchWidgetData.self, from: messageData) {
            let payload: [String: Any] = [
                "widgetData": messageData,
                "timestamp": Date().timeIntervalSince1970
            ]
            processReceivedPayload(payload)
        }
        
        // Acknowledge
        replyHandler(Data("ok".utf8))
    }
    
    // MARK: Reachability changes
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchData] Reachability changed: \(session.isReachable)")
        
        // When iPhone becomes reachable and we have no data, request it
        if session.isReachable && data == nil {
            DispatchQueue.main.async {
                self.requestDataFromPhone()
            }
        }
    }
}
