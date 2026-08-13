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
    
    private var seenUnlockedKeys: Set<String> {
        get {
            Set(seenUnlockedKeysData.split(separator: ",").map(String.init))
        }
        set {
            seenUnlockedKeysData = newValue.joined(separator: ",")
        }
    }
    
    private init() {}
    
    /// Check list of achievements from backend response
    /// If >1 unlocked at once, show a single summary toast ("x achievements unlocked")
    func checkNewAchievements(_ achievements: [AchievementDetail]) {
        var localSeen = seenUnlockedKeys
        var newItems: [AchievementDetail] = []
        
        for item in achievements where item.unlocked {
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
                    // Multiple achievements unlocked -> single summary toast
                    let multiToast = AchievementToastItem(
                        id: UUID().uuidString,
                        name: "\(newItems.count) achievements unlocked",
                        category: "multi",
                        icon: "sparkles",
                        count: newItems.count
                    )
                    self.enqueueToast(multiToast)
                } else if let single = newItems.first {
                    // Single achievement unlocked -> show icon & title
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
    
    /// Manually show a toast for an achievement
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
}
