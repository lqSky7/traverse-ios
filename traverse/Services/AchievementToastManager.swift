import SwiftUI
import Combine

struct AchievementToastItem: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let icon: String?
    let count: Int
    
    static func == (lhs: AchievementToastItem, rhs: AchievementToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

class AchievementToastManager: ObservableObject {
    static let shared = AchievementToastManager()
    
    @Published var currentToast: AchievementToastItem? = nil
    private var toastQueue: [AchievementToastItem] = []
    private var dismissWorkItem: DispatchWorkItem?
    
    @AppStorage("seenUnlockedAchievementKeys") private var seenUnlockedKeysData: String = ""
    @AppStorage("seenFriendRequestKeys") private var seenFriendRequestKeysData: String = ""
    @AppStorage("seenStreakRequestKeys") private var seenStreakRequestKeysData: String = ""
    @AppStorage("lastAvailableFreezesCount") private var lastAvailableFreezesCount: Int = -1
    @AppStorage("hasInitializedAchievements") private var hasInitializedAchievements: Bool = false
    
    private var lastSyncTimestamp: Date?
    private var isSyncing = false
    
    private var seenUnlockedKeys: Set<String> {
        get { Set(seenUnlockedKeysData.split(separator: ",").map(String.init)) }
        set { seenUnlockedKeysData = newValue.joined(separator: ",") }
    }
    
    private var seenFriendRequestKeys: Set<String> {
        get { Set(seenFriendRequestKeysData.split(separator: ",").map(String.init)) }
        set { seenFriendRequestKeysData = newValue.joined(separator: ",") }
    }
    
    private var seenStreakRequestKeys: Set<String> {
        get { Set(seenStreakRequestKeysData.split(separator: ",").map(String.init)) }
        set { seenStreakRequestKeysData = newValue.joined(separator: ",") }
    }
    
    private init() {}
    
    /// Sync updates on app open / foregrounding with throttling (minimum 10s between checks)
    func syncAppOpenUpdates(force: Bool = false) async {
        guard NetworkService.shared.isAuthenticated() else { return }
        
        if !force, let lastSync = lastSyncTimestamp, Date().timeIntervalSince(lastSync) < 10 {
            return
        }
        
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let updates = try await NetworkService.shared.getAppUpdates()
            lastSyncTimestamp = Date()
            
            await MainActor.run {
                // Update DataManager cached requests
                DataManager.shared.receivedRequests = updates.friendRequests
                DataManager.shared.receivedStreakRequests = updates.streakRequests
                
                // Evaluate and display toasts for newly unlocked or received items
                self.checkNewAchievements(updates.achievements)
                self.checkFriendRequests(updates.friendRequests)
                self.checkStreakRequests(updates.streakRequests)
                self.checkFreezeInfo(updates.freezeInfo)
            }
        } catch {
            print("[AchievementToastManager] syncAppOpenUpdates failed: \(error.localizedDescription)")
        }
    }
    
    /// Check list of achievements from backend response
    /// If >1 unlocked at once, show a single summary toast ("x achievements unlocked")
    func checkNewAchievements(_ achievements: [AchievementDetail]) {
        let unlockedItems = achievements.filter { $0.unlocked }
        
        // On very first launch / clean install for an existing user with unlocked achievements,
        // seed the keys without spamming historical toasts
        if !hasInitializedAchievements && seenUnlockedKeysData.isEmpty {
            seenUnlockedKeys = Set(unlockedItems.map { "\($0.id)" })
            hasInitializedAchievements = true
            return
        }
        hasInitializedAchievements = true
        
        var localSeen = seenUnlockedKeys
        var newItems: [AchievementDetail] = []
        
        for item in unlockedItems {
            let key = "\(item.id)"
            if !localSeen.contains(key) {
                localSeen.insert(key)
                newItems.append(item)
            }
        }
        
        if !newItems.isEmpty {
            seenUnlockedKeys = localSeen
            DispatchQueue.main.async {
                if newItems.count > 1 {
                    let multiToast = AchievementToastItem(
                        id: UUID().uuidString,
                        name: "\(newItems.count) achievements unlocked",
                        category: "multi",
                        icon: "sparkles",
                        count: newItems.count
                    )
                    self.enqueueToast(multiToast)
                } else if let single = newItems.first {
                    let singleToast = AchievementToastItem(
                        id: "\(single.id)",
                        name: single.name,
                        category: single.category,
                        icon: single.icon,
                        count: 1
                    )
                    self.enqueueToast(singleToast)
                }
            }
        }
    }
    
    /// Check list of received friend requests for newly received requests
    func checkFriendRequests(_ requests: [FriendRequest]) {
        var localSeen = seenFriendRequestKeys
        var newRequesters: [String] = []
        
        for req in requests {
            let key = "\(req.id)"
            if !localSeen.contains(key) {
                localSeen.insert(key)
                if let username = req.requester?.username, !username.isEmpty {
                    newRequesters.append(username)
                }
            }
        }
        
        if !newRequesters.isEmpty {
            seenFriendRequestKeys = localSeen
            DispatchQueue.main.async {
                if newRequesters.count > 1 {
                    self.showToast(
                        name: "\(newRequesters.count) friend requests received",
                        category: "friend_request",
                        icon: "person.badge.plus.fill",
                        count: newRequesters.count
                    )
                } else if let requester = newRequesters.first {
                    self.showToast(
                        name: "\(requester) sent a friend request",
                        category: "friend_request",
                        icon: "person.badge.plus.fill"
                    )
                }
            }
        }
    }
    
    /// Check list of received streak requests for newly received requests
    func checkStreakRequests(_ requests: [FriendStreakRequest]) {
        var localSeen = seenStreakRequestKeys
        var newRequesters: [String] = []
        
        for req in requests {
            let key = "\(req.id)"
            if !localSeen.contains(key) {
                localSeen.insert(key)
                if let username = req.requester?.username, !username.isEmpty {
                    newRequesters.append(username)
                }
            }
        }
        
        if !newRequesters.isEmpty {
            seenStreakRequestKeys = localSeen
            DispatchQueue.main.async {
                if newRequesters.count > 1 {
                    self.showToast(
                        name: "\(newRequesters.count) streak requests received",
                        category: "streak_request",
                        icon: "flame.circle.fill",
                        count: newRequesters.count
                    )
                } else if let requester = newRequesters.first {
                    self.showToast(
                        name: "\(requester) sent a streak request",
                        category: "streak_request",
                        icon: "flame.circle.fill"
                    )
                }
            }
        }
    }
    
    @AppStorage("lastSeenGiftedFreezeID") private var lastSeenGiftedFreezeID: Int = -1
    
    /// Check freeze info to detect gifted freezes with sender details
    func checkFreezeInfo(_ freezeInfo: FreezeInfoResponse, isUserPurchase: Bool = false) {
        // If first time initializing, save baseline without triggering historical toast
        if lastSeenGiftedFreezeID == -1 {
            lastSeenGiftedFreezeID = freezeInfo.latestGift?.id ?? 0
            lastAvailableFreezesCount = freezeInfo.availableFreezes
            return
        }
        
        if let latestGift = freezeInfo.latestGift, !isUserPurchase {
            if latestGift.id != lastSeenGiftedFreezeID {
                lastSeenGiftedFreezeID = latestGift.id
                let sender = latestGift.giftedBy
                DispatchQueue.main.async {
                    self.showGiftedFreezeToast(from: sender)
                }
                lastAvailableFreezesCount = freezeInfo.availableFreezes
                return
            }
        }
        
        if lastAvailableFreezesCount >= 0 {
            let diff = freezeInfo.availableFreezes - lastAvailableFreezesCount
            if diff > 0 && !isUserPurchase {
                DispatchQueue.main.async {
                    self.showGiftedFreezeToast(count: diff)
                }
            }
        }
        lastAvailableFreezesCount = freezeInfo.availableFreezes
    }
    
    /// Show a toast for a gifted freeze
    func showGiftedFreezeToast(from username: String? = nil, count: Int = 1) {
        let nameText: String
        if let username = username, !username.isEmpty {
            nameText = "\(username) gifted you a freeze!"
        } else if count > 1 {
            nameText = "Received \(count) gifted streak freezes!"
        } else {
            nameText = "Received a gifted streak freeze!"
        }
        
        showToast(
            name: nameText,
            category: "gift_freeze",
            icon: "snowflake"
        )
    }
    
    /// Show a friend request toast directly
    func showFriendRequestToast(from username: String) {
        showToast(
            name: "\(username) sent a friend request",
            category: "friend_request",
            icon: "person.badge.plus.fill"
        )
    }
    
    /// Show a streak request toast directly
    func showStreakRequestToast(from username: String) {
        showToast(
            name: "\(username) sent a streak request",
            category: "streak_request",
            icon: "flame.circle.fill"
        )
    }
    
    /// Generic toast presenter
    func showToast(name: String, category: String, icon: String? = nil, count: Int = 1) {
        let toast = AchievementToastItem(
            id: UUID().uuidString,
            name: name,
            category: category,
            icon: icon,
            count: count
        )
        DispatchQueue.main.async {
            self.enqueueToast(toast)
        }
    }
    
    private func enqueueToast(_ item: AchievementToastItem) {
        // Prevent duplicate queuing of exact same toast
        guard !toastQueue.contains(item) && currentToast?.id != item.id else { return }
        toastQueue.append(item)
        processQueue()
    }
    
    private func processQueue() {
        guard currentToast == nil, !toastQueue.isEmpty else { return }
        
        let nextToast = toastQueue.removeFirst()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.currentToast = nextToast
        }
        
        // Auto dismiss after 4 seconds
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrentToast()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: workItem)
    }
    
    func dismissCurrentToast() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        
        withAnimation(.easeOut(duration: 0.25)) {
            self.currentToast = nil
        }
        
        // Process next toast after current transition finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.processQueue()
        }
    }
    
    /// Reset cached seen state (e.g. on logout)
    func resetState() {
        seenUnlockedKeysData = ""
        seenFriendRequestKeysData = ""
        seenStreakRequestKeysData = ""
        lastAvailableFreezesCount = -1
        lastSeenGiftedFreezeID = -1
        hasInitializedAchievements = false
        lastSyncTimestamp = nil
        isSyncing = false
        currentToast = nil
        toastQueue.removeAll()
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }
}

