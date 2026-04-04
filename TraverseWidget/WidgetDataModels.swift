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
    let achievements: AchievementsData?
    let lastUpdated: Date
}

struct AchievementsData: Codable {
    let unlocked: Int
    let total: Int
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
    let slug: String
    let platform: String
    let difficulty: String
    let revisionNumber: Int
    let scheduledFor: String
    let isOverdue: Bool
    
    var scheduledDate: Date {
        ISO8601DateFormatter().date(from: scheduledFor) ?? Date()
    }
    
    // Memberwise init with slug defaulting to "" for backward compat
    init(id: Int, problemTitle: String, slug: String = "", platform: String, difficulty: String, revisionNumber: Int, scheduledFor: String, isOverdue: Bool) {
        self.id = id
        self.problemTitle = problemTitle
        self.slug = slug
        self.platform = platform
        self.difficulty = difficulty
        self.revisionNumber = revisionNumber
        self.scheduledFor = scheduledFor
        self.isOverdue = isOverdue
    }
    
    // Decoder init — handles missing slug in older encoded data
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
        userDefaults?.synchronize() // Force immediate write for widget access
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
