//
//  StatsModels.swift
//  traverse
//

import Foundation

// MARK: - User Statistics
struct UserStats: Codable {
    let username: String
    let stats: UserStatsData
}

struct UserStatsData: Codable {
    let currentStreak: Int
    let totalXp: Int
    let totalSolves: Int
    let totalSubmissions: Int
    let totalStreakDays: Int
    let problemsByDifficulty: ProblemsByDifficulty
}

struct ProblemsByDifficulty: Codable {
    let easy: Int
    let medium: Int
    let hard: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        easy = try container.decodeIfPresent(Int.self, forKey: .easy) ?? 0
        medium = try container.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        hard = try container.decodeIfPresent(Int.self, forKey: .hard) ?? 0
    }
}

// MARK: - Submission Statistics
struct SubmissionStats: Codable {
    let stats: SubmissionStatsData
}

struct SubmissionStatsData: Codable {
    let total: Int
    let accepted: Int
    let failed: Int
    let acceptanceRate: String
    let languageBreakdown: [LanguageBreakdown]
}

struct LanguageBreakdown: Codable, Identifiable {
    var id: String { language }
    let language: String
    let count: Int
}

// MARK: - Solve Statistics
struct SolveStats: Codable {
    let stats: SolveStatsData
}

struct SolveStatsData: Codable {
    let totalSolves: Int
    let totalXp: Int
    let totalStreakDays: Int
    let byDifficulty: ProblemsByDifficulty
    let byPlatform: [String: Int]
}

// MARK: - Solves List
struct SolvesResponse: Codable {
    let solves: [Solve]
    let pagination: Pagination
}

struct Solve: Codable, Identifiable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let problem: Problem
    let submission: Submission
    let highlight: Highlight?
}

struct Problem: Codable {
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
}

struct Submission: Codable {
    let language: String
    let happenedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let numberOfTries: Int?
    let timeTaken: Int?
}

struct Highlight: Codable {
    let id: Int
    let content: String
    let note: String
    let tags: [String]
}

struct Pagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Achievement Statistics
struct AchievementStats: Codable {
    let stats: AchievementStatsData
}

struct AchievementStatsData: Codable {
    let total: Int
    let unlocked: Int
    let percentage: String
    let byCategory: [String: Int]
}

// MARK: - All Achievements
struct AllAchievementsResponse: Codable {
    let achievements: [AchievementDetail]
}

struct AchievementDetail: Codable, Identifiable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let icon: String?
    let category: String
    let unlocked: Bool
    let unlockedAt: String?
}

// MARK: - Subscription Status
struct SubscriptionStatusResponse: Codable {
    let isSubscriptionActive: Bool
}
