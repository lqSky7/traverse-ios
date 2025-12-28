//
//  WidgetDataModels.swift
//  TraverseWidget
//

import Foundation

// MARK: - Widget Data Models
struct WidgetData: Codable {
    let streak: StreakData?
    let recentSolve: RecentSolveData?
    let revisions: [RevisionData]?
    let revisionsDueCount: Int  // Simple count - no datetime BS
    let lastUpdated: Date
}

struct StreakData: Codable {
    let currentStreak: Int
    let solvedToday: Bool
    let totalXp: Int
    let totalSolves: Int
}

struct RecentSolveData: Codable {
    let problemTitle: String
    let platform: String
    let difficulty: String
    let xpAwarded: Int
    let solvedAt: String
    let language: String
}

struct RevisionData: Codable, Identifiable {
    let id: Int
    let problemTitle: String
    let platform: String
    let difficulty: String
    let revisionNumber: Int
    let scheduledFor: String
    let isOverdue: Bool
    
    var scheduledDate: Date {
        ISO8601DateFormatter().date(from: scheduledFor) ?? Date()
    }
}

// MARK: - Widget Data Manager
class WidgetDataManager {
    static let shared = WidgetDataManager()
    static let suiteName = "group.com.traverse.app"
    static let dataKey = "widgetData"
    
    private let userDefaults: UserDefaults?
    
    private init() {
        userDefaults = UserDefaults(suiteName: WidgetDataManager.suiteName)
    }
    
    func saveWidgetData(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        userDefaults?.set(encoded, forKey: WidgetDataManager.dataKey)
    }
    
    func loadWidgetData() -> WidgetData? {
        guard let data = userDefaults?.data(forKey: WidgetDataManager.dataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    func clearWidgetData() {
        userDefaults?.removeObject(forKey: WidgetDataManager.dataKey)
    }
}
