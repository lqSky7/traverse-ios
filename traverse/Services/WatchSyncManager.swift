//
//  WatchSyncManager.swift
//  traverse
//
//  iPhone-side WatchConnectivity manager.
//  Sends widget data to the paired Apple Watch via `updateApplicationContext`.
//  This is the correct mechanism (not App Group UserDefaults, which is device-local only).
//

import Foundation
import WatchConnectivity
import WidgetKit
import Combine

final class WatchSyncManager: NSObject, ObservableObject {
    static let shared = WatchSyncManager()
    
    /// Whether the paired Watch is reachable right now
    @Published private(set) var isWatchReachable = false
    @Published private(set) var isWatchPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var lastSyncDate: Date?
    
    private var session: WCSession?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Activation
    
    /// Call once from app launch (traverseApp.swift). Must be called on main thread.
    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchSync] WCSession not supported on this device")
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        print("[WatchSync] WCSession activation requested")
    }
    
    // MARK: - Sending Data
    
    /// Send the latest widget data snapshot to the Watch via applicationContext.
    /// `updateApplicationContext` guarantees the Watch always gets the latest state,
    /// coalescing any pending updates. It queues if the Watch is not reachable,
    /// and delivers when the Watch wakes.
    func syncWidgetData(_ data: WidgetData) {
        guard let session = session,
              session.activationState == .activated else {
            print("[WatchSync] Session not activated, skipping sync")
            return
        }
        
        guard session.isPaired else {
            print("[WatchSync] No paired Watch, skipping sync")
            return
        }
        
        guard session.isWatchAppInstalled else {
            print("[WatchSync] Watch app not installed, skipping sync")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            
            // updateApplicationContext replaces any pending context — Watch always gets latest
            try session.updateApplicationContext([
                "widgetData": encoded,
                "timestamp": Date().timeIntervalSince1970
            ])
            
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
            }
            
            print("[WatchSync] Application context updated successfully (\(encoded.count) bytes)")
        } catch {
            print("[WatchSync] Failed to update application context: \(error)")
            
            // Fallback: try transferUserInfo for guaranteed delivery
            sendViaTransferUserInfo(data)
        }
    }
    
    /// Send data via message (only works if Watch app is in foreground)
    /// Used for instant updates when user is actively looking at the Watch.
    func sendImmediateUpdate(_ data: WidgetData) {
        guard let session = session,
              session.activationState == .activated,
              session.isReachable else {
            // Fall back to applicationContext
            syncWidgetData(data)
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            session.sendMessageData(encoded, replyHandler: { _ in
                print("[WatchSync] Immediate message delivered and acknowledged")
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                }
            }, errorHandler: { error in
                print("[WatchSync] Immediate message failed: \(error), falling back to context")
                self.syncWidgetData(data)
            })
        } catch {
            print("[WatchSync] Failed to encode data for immediate send: \(error)")
        }
    }
    
    /// Fallback: transferUserInfo is guaranteed delivery (queued, FIFO).
    /// Used when updateApplicationContext fails.
    private func sendViaTransferUserInfo(_ data: WidgetData) {
        guard let session = session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            session.transferUserInfo([
                "widgetData": encoded,
                "timestamp": Date().timeIntervalSince1970
            ])
            print("[WatchSync] Queued data via transferUserInfo")
        } catch {
            print("[WatchSync] transferUserInfo fallback also failed: \(error)")
        }
    }
    
    /// Respond to a data request from the Watch
    private func handleDataRequest(from session: WCSession, replyHandler: @escaping ([String: Any]) -> Void) {
        // Load current widget data from the shared UserDefaults (same as iOS widgets use)
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let encoded = try? JSONEncoder().encode(widgetData) {
            replyHandler([
                "widgetData": encoded,
                "timestamp": Date().timeIntervalSince1970
            ])
            print("[WatchSync] Responded to Watch data request")
        } else {
            replyHandler(["error": "No data available"])
            print("[WatchSync] Watch requested data but none available")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
        
        if let error = error {
            print("[WatchSync] Activation failed: \(error)")
            return
        }
        
        switch activationState {
        case .activated:
            print("[WatchSync] Session activated. Paired: \(session.isPaired), App installed: \(session.isWatchAppInstalled)")
            
            // Send current data immediately after activation
            if session.isPaired && session.isWatchAppInstalled {
                if let widgetData = WidgetDataManager.shared.loadWidgetData() {
                    syncWidgetData(widgetData)
                }
            }
        case .inactive:
            print("[WatchSync] Session inactive")
        case .notActivated:
            print("[WatchSync] Session not activated")
        @unknown default:
            print("[WatchSync] Unknown activation state")
        }
    }
    
    // Required for iOS — handles Watch switching on multi-Watch setups
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSync] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchSync] Session deactivated, reactivating...")
        // Reactivate for the new Watch
        session.activate()
    }
    
    // Monitor reachability changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        
        print("[WatchSync] Watch reachability changed: \(session.isReachable)")
        
        // When Watch becomes reachable, push latest data
        if session.isReachable {
            if let widgetData = WidgetDataManager.shared.loadWidgetData() {
                syncWidgetData(widgetData)
            }
        }
    }
    
    // Handle messages from Watch (e.g., data requests)
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let action = message["action"] as? String, action == "requestData" {
            handleDataRequest(from: session, replyHandler: replyHandler)
        } else {
            replyHandler(["status": "unknown action"])
        }
    }
    
    // Watch app installation state changed
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        
        print("[WatchSync] Watch state changed. Paired: \(session.isPaired), App installed: \(session.isWatchAppInstalled)")
        
        // If Watch app just got installed, push current data
        if session.isWatchAppInstalled {
            if let widgetData = WidgetDataManager.shared.loadWidgetData() {
                syncWidgetData(widgetData)
            }
        }
    }
}
