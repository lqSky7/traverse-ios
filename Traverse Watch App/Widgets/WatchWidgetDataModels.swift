//
//  WatchWidgetDataModels.swift
//  Traverse Watch App
//
//  Data models shared between Watch widgets.
//  These read from the local UserDefaults where WatchDataManager
//  persists data received from iPhone via WatchConnectivity.
//

import Foundation

// MARK: - Watch Widget Data Manager

final class WatchWidgetDataProvider: Sendable {
    static let shared = WatchWidgetDataProvider()
    
    private static let suiteName = "group.com.traverse.app"
    private static let dataKey = "widgetData"
    
    private let userDefaults: UserDefaults?
    
    private init() {
        userDefaults = UserDefaults(suiteName: WatchWidgetDataProvider.suiteName)
    }
    
    nonisolated func loadWidgetData() -> WatchWidgetSnapshot? {
        let ud = UserDefaults(suiteName: WatchWidgetDataProvider.suiteName)
        guard let data = ud?.data(forKey: WatchWidgetDataProvider.dataKey),
              let decoded = try? JSONDecoder().decode(WatchWidgetSnapshot.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Snapshot Model (lightweight for widget timeline)

struct WatchWidgetSnapshot: Codable, Sendable {
    let streak: WatchSnapshotStreak?
    let recentSolve: WatchSnapshotRecentSolve?
    let revisions: [WatchSnapshotRevision]?
    let revisionsDueCount: Int
    let achievements: WatchSnapshotAchievements?
    let lastUpdated: Date
}

struct WatchSnapshotStreak: Codable, Sendable {
    let currentStreak: Int
    let solvedToday: Bool
    let totalXp: Int
    let totalSolves: Int
}

struct WatchSnapshotRecentSolve: Codable, Sendable {
    let problemTitle: String
    let platform: String
    let difficulty: String
    let xpAwarded: Int
    let solvedAt: String
    let language: String
}

struct WatchSnapshotRevision: Codable, Identifiable, Sendable {
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
}

struct WatchSnapshotAchievements: Codable, Sendable {
    let unlocked: Int
    let total: Int
}
