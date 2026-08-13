import SwiftUI
import Combine

struct AchievementToastItem: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String
    let icon: String?
    
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
    
    /// Check list of achievements from backend response and queue toasts for any newly unlocked ones
    func checkNewAchievements(_ achievements: [AchievementDetail]) {
        var localSeen = seenUnlockedKeys
        var newToasts: [AchievementToastItem] = []
        
        for item in achievements where item.unlocked {
            let key = "\(item.id)"
            if !localSeen.contains(key) {
                localSeen.insert(key)
                let toast = AchievementToastItem(
                    id: key,
                    name: item.name,
                    description: item.description,
                    category: item.category,
                    icon: item.icon
                )
                newToasts.append(toast)
            }
        }
        
        if !newToasts.isEmpty {
            seenUnlockedKeys = localSeen
            DispatchQueue.main.async {
                for toast in newToasts {
                    self.enqueueToast(toast)
                }
            }
        }
    }
    
    /// Manually show a toast for an achievement
    func showToast(name: String, description: String, category: String, icon: String? = nil) {
        let toast = AchievementToastItem(
            id: UUID().uuidString,
            name: name,
            description: description,
            category: category,
            icon: icon
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
        
        // Auto dismiss after 5 seconds
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrentToast()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    func dismissCurrentToast() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        
        withAnimation(.easeOut(duration: 0.3)) {
            self.currentToast = nil
        }
        
        // Process next toast after current transition finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.processQueue()
        }
    }
}
