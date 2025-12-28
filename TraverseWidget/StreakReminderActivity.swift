import ActivityKit
import Foundation

struct StreakReminderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var hoursRemaining: Int
        var currentStreak: Int
    }
    
    var streakEndsAt: Date
}
