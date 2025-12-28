import ActivityKit
import Foundation

@MainActor
@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<StreakReminderAttributes>?
    
    private init() {}
    
    // Start a streak reminder Live Activity
    func startStreakReminder(hoursRemaining: Int, currentStreak: Int, streakEndsAt: Date) {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        
        // Check if there's already an active live activity
        let existingActivities = Activity<StreakReminderAttributes>.activities
        
        // If there's an active activity, update it instead of creating a new one
        if let existingActivity = existingActivities.first ?? currentActivity {
            currentActivity = existingActivity
            updateActivity(hoursRemaining: hoursRemaining, currentStreak: currentStreak)
            return
        }
        
        let attributes = StreakReminderAttributes(streakEndsAt: streakEndsAt)
        let contentState = StreakReminderAttributes.ContentState(
            hoursRemaining: hoursRemaining,
            currentStreak: currentStreak
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    // Update the Live Activity with new hours remaining
    func updateActivity(hoursRemaining: Int, currentStreak: Int) {
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            let contentState = StreakReminderAttributes.ContentState(
                hoursRemaining: hoursRemaining,
                currentStreak: currentStreak
            )
            
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
        }
    }
    
    // End the Live Activity
    func endActivity() {
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
