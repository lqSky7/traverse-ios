import Foundation

struct WidgetCache: Codable {
    let user: WidgetUser?
    let userStats: WidgetUserStats?
    let todayRevisions: WidgetTodayRevisions?
}

struct WidgetUser: Codable {
    let username: String
    let currentStreak: Int
    let totalXp: Int
}

struct WidgetUserStats: Codable {
    let stats: WidgetUserStatsData
}

struct WidgetUserStatsData: Codable {
    let currentStreak: Int
    let totalXp: Int
}

struct WidgetTodayRevisions: Codable {
    let revisions: [WidgetRevision]
    let total: Int
    let maxDaily: Int
    let overflow: Int
    let overdue: Int
}

struct WidgetRevision: Codable, Identifiable {
    let id: Int
    let revisionNumber: Int
    let scheduledFor: String
    let problem: WidgetProblem
    
    var platform: String { problem.platform }
    var title: String { problem.title }
    var difficulty: String { problem.difficulty }
}

struct WidgetProblem: Codable {
    let platform: String
    let title: String
    let difficulty: String
}

class WidgetCacheReader {
    static func readCache() -> WidgetCache? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let cacheURL = homeDirectory
            .appendingPathComponent("Library/Application Support/TraverseMac/traverse-mac-cache.json")
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(WidgetCache.self, from: data)
    }
}
