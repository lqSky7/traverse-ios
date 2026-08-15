import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(String)
    case serverError(String)
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response from server"
        case .decodingError(let message): "Failed to decode response: \(message)"
        case .serverError(let message): message
        case .unauthenticated: "Not authenticated"
        }
    }
}

struct EmptyBody: Encodable {}

struct ErrorResponse: Codable {
    let error: String?
    let message: String?
}

struct MessageResponse: Codable {
    let message: String
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let timezone: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct UpdateProfileRequest: Codable {
    let email: String?
    let timezone: String?
    let visibility: String?
    let maxDailyReviews: Int?
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

struct PasswordResetRequest: Codable {
    let username: String
}

struct PasswordResetConfirmRequest: Codable {
    let username: String
    let code: String
    let newPassword: String
}

struct DeleteAccountRequest: Codable {
    let password: String
}

struct RecoverAccountRequest: Codable {
    let username: String
    let password: String?
}

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let email: String?
    let timezone: String
    let visibility: String
    let currentStreak: Int
    let totalXp: Int
    let maxDailyReviews: Int?
    let createdAt: String?
    var profileImageURL: String?
}

struct AuthResponse: Codable {
    let message: String
    let user: User
    let token: String?
}

typealias LoginResponse = AuthResponse

struct UserResponse: Codable {
    let user: User
}

struct PasswordResetRequestResponse: Codable {
    let status: String
    let message: String
    let expiresInMinutes: Int?
}

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
    let availableFreezes: Int?
}

struct ProblemsByDifficulty: Codable, Hashable {
    let easy: Int
    let medium: Int
    let hard: Int

    init(easy: Int = 0, medium: Int = 0, hard: Int = 0) {
        self.easy = easy
        self.medium = medium
        self.hard = hard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        easy = try container.decodeIfPresent(Int.self, forKey: .easy) ?? 0
        medium = try container.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        hard = try container.decodeIfPresent(Int.self, forKey: .hard) ?? 0
    }
}

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

struct LanguageBreakdown: Codable, Identifiable, Hashable {
    var id: String { language }
    let language: String
    let count: Int
}

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

struct SolvesResponse: Codable {
    let solves: [Solve]
    let pagination: Pagination
}

struct UserStatisticsResponse: Codable {
    let username: String
    let stats: UserStatisticsData
}

struct UserStatisticsData: Codable, Hashable {
    let totalSolves: Int
    let totalSubmissions: Int
    let totalStreakDays: Int
    let problemsByDifficulty: ProblemsByDifficulty
}

struct UserSolvesResponse: Codable {
    let username: String
    let solves: [UserSolve]
    let pagination: Pagination
}

struct UserSolve: Codable, Identifiable, Hashable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    let aiAnalysis: String?
    let problem: Problem
    let submission: Submission?
    let highlight: Highlight?
}

struct AchievementsResponse: Codable {
    let username: String
    let achievements: [Achievement]
}

struct Achievement: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let category: String
    let unlockedAt: String
}

struct Pagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
}

struct Solve: Codable, Identifiable, Hashable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let problem: Problem
    let submission: Submission
    let highlight: Highlight?
}

struct Problem: Codable, Hashable {
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
}

struct Submission: Codable, Hashable {
    let language: String
    let happenedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let numberOfTries: Int?
    let timeTaken: Int?
}

struct Highlight: Codable, Hashable {
    let id: Int
    let content: String
    let note: String
    let tags: [String]
}

struct AchievementStats: Codable {
    let stats: AchievementStatsData
}

struct AchievementStatsData: Codable {
    let total: Int
    let unlocked: Int
    let percentage: String
    let byCategory: [String: Int]
}

struct AllAchievementsResponse: Codable {
    let achievements: [AchievementDetail]
}

struct AchievementDetail: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let icon: String?
    let category: String
    let unlocked: Bool
    let unlockedAt: String?
}

struct UserBasic: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let currentStreak: Int
    let totalXp: Int
}

struct UsersSearchResponse: Codable {
    let users: [UserBasic]
}

struct UserProfile: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let timezone: String
    let visibility: String
    let currentStreak: Int
    let totalXp: Int
    let createdAt: String
}

struct UserProfileResponse: Codable {
    let user: UserProfile
}

struct FriendRequest: Codable, Identifiable, Hashable {
    let id: Int
    let status: String
    let createdAt: String
    let requester: UserBasic?
    let addressee: UserBasic?
}

struct FriendRequestsResponse: Codable {
    let requests: [FriendRequest]
}

struct SendFriendRequestBody: Codable {
    let username: String
}

struct SendFriendRequestResponse: Codable {
    let message: String
    let request: FriendRequest
}

struct Friend: Codable, Identifiable, Hashable {
    let friendshipId: String
    let friendedAt: String
    let id: Int
    let username: String
    let currentStreak: Int
    let totalXp: Int
    let visibility: String
}

struct FriendsListResponse: Codable {
    let friends: [Friend]
}

struct FriendStreakUser: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let currentStreak: Int
}

struct FriendStreakRequest: Codable, Identifiable, Hashable {
    let id: Int
    let status: String
    let createdAt: String
    let requester: FriendStreakUser?
    let requested: FriendStreakUser?
}

struct FriendStreakRequestsResponse: Codable {
    let requests: [FriendStreakRequest]
}

struct SendFriendStreakRequestBody: Codable {
    let username: String
}

struct FriendStreak: Codable, Identifiable, Hashable {
    let friend: FriendStreakUser
    let currentStreak: Int
    let longestStreak: Int
    let lastIncrementDate: String?
    let createdAt: String
    var id: Int { friend.id }
}

struct FriendStreaksResponse: Codable {
    let streaks: [FriendStreak]
}

struct Revision: Codable, Identifiable, Hashable {
    let id: Int
    let solveId: Int
    let userId: Int
    let problemId: Int
    let revisionNumber: Int
    let scheduledFor: String
    let completedAt: String?
    let createdAt: String
    let problem: RevisionProblem
    let solve: RevisionSolve?

    var scheduledDate: Date { DateParser.parse(scheduledFor) ?? .now }
    var isCompleted: Bool { completedAt != nil }
    var isOverdue: Bool { !isCompleted && scheduledDate < Calendar.current.startOfDay(for: .now) }
}

struct RevisionProblem: Codable, Hashable {
    let id: Int
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
}

struct RevisionSolve: Codable, Hashable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
}

struct RevisionsResponse: Codable {
    let revisions: [Revision]
    let pagination: Pagination?
}

struct GroupedRevisionsResponse: Codable {
    let groups: [RevisionGroup]
}

struct RevisionGroup: Codable, Identifiable, Hashable {
    let date: String
    let revisions: [Revision]
    let count: Int
    var id: String { date }
    var displayDate: Date { DateParser.parseDateOnly(date) ?? .now }
}

struct RevisionStatsResponse: Codable, Hashable {
    let total: Int
    let completed: Int
    let overdue: Int
    let dueToday: Int
    let completionRate: Int
}

struct CompleteRevisionResponse: Codable {
    let message: String
    let revision: Revision
}

struct RevisionAttemptRequest: Codable {
    let outcome: Int
    let numTries: Int
    let timeSpentMinutes: Double
}

struct RevisionAttemptResponse: Codable {
    let message: String
    let attempt: RevisionAttempt
    let prediction: MLPrediction
    let nextRevision: Revision?
}

struct RevisionAttempt: Codable {
    let id: Int
    let revisionId: Int
    let userId: Int
    let problemId: Int
    let attemptNumber: Int
    let daysSinceLastAttempt: Double
    let outcome: Int
    let numTries: Int
    let timeSpentMinutes: Double
    let attemptedAt: String
}

struct MLPrediction: Codable {
    let nextReviewIntervalDays: Double
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case nextReviewIntervalDays = "next_review_interval_days"
        case confidence
    }
}

struct RevisionTodayResponse: Codable {
    let revisions: [Revision]
    let total: Int
    let maxDaily: Int
    let overflow: Int
    let overdue: Int
}

struct RevisionAnalyticsResponse: Codable {
    let overview: RevisionAnalyticsOverview
    let stabilityDistribution: RevisionStabilityDistribution
    let projectedLoad: [RevisionProjectedLoad]
    let weeklyCompletion: [WeeklyCompletion]
    let retentionHeatmap: [RevisionRetentionItem]
    let streaks: RevisionAnalyticsStreaks
}

struct RevisionAnalyticsOverview: Codable {
    let totalProblemsTracked: Int
    let masteredProblems: Int
    let leechProblems: Int
    let averageStability: Double
    let averageRetrievability: Double
}

struct RevisionStabilityDistribution: Codable {
    let critical: Int
    let weak: Int
    let developing: Int
    let strong: Int
    let mastered: Int
}

struct WeeklyCompletion: Codable, Identifiable {
    var id: String { week }
    let week: String
    let count: Int
}

struct RevisionProjectedLoad: Codable, Identifiable {
    var id: String { date }
    let date: String
    let dueCount: Int
    let overdueCount: Int
}

struct RevisionRetentionItem: Codable, Identifiable {
    var id: Int { problemId }
    let problemId: Int
    let problemTitle: String
    let problemSlug: String
    let platform: String
    let difficulty: String
    let retrievability: Double
    let stability: Double
    let difficulty_D: Double
    let lapses: Int
    let lastReviewAt: String?
    let isLeech: Bool
}

struct RevisionAnalyticsStreaks: Codable {
    let totalRevisionsCompleted: Int
}


struct SubscriptionStatusResponse: Codable {
    let isSubscriptionActive: Bool
}

struct FreezeInfoResponse: Codable {
    let availableFreezes: Int
    let usedFreezes: Int
    let totalFreezes: Int
    let costs: FreezeCosts
}

struct FreezeCosts: Codable {
    let purchase: Int
    let gift: Int
}

struct FreezePurchaseRequest: Codable {
    let count: Int
}

struct FreezeGiftRequest: Codable {
    let username: String
    let count: Int
}

struct FreezePurchaseResponse: Codable {
    let message: String
    let freezesPurchased: Int
    let xpSpent: Int
    let availableFreezes: Int
    let remainingXp: Int
}

struct FreezeGiftResponse: Codable {
    let message: String
    let freezesGifted: Int
    let xpSpent: Int
    let recipient: String
    let remainingXp: Int
}

struct FreezeDatesResponse: Codable {
    let freezeDates: [String]
}

struct LocalAppCache: Codable {
    var user: User?
    var userStats: UserStats?
    var submissionStats: SubmissionStats?
    var solveStats: SolveStats?
    var achievementStats: AchievementStats?
    var achievements: [AchievementDetail]
    var recentSolves: [Solve]
    var allSolves: [Solve]
    var friends: [Friend]
    var receivedRequests: [FriendRequest]
    var sentRequests: [FriendRequest]
    var receivedStreakRequests: [FriendStreakRequest]
    var sentStreakRequests: [FriendStreakRequest]
    var friendStreaks: [FriendStreak]
    var revisionGroups: [RevisionGroup]
    var revisionStats: RevisionStatsResponse?
    var revisionAnalytics: RevisionAnalyticsResponse?
    var todayRevisions: RevisionTodayResponse?
    var subscriptionStatus: SubscriptionStatusResponse?
    var freezeInfo: FreezeInfoResponse?
    var freezeDates: [String]
    var cachedAt: Date
}

enum PanelKey: String, CaseIterable, Identifiable {
    case home
    case charts
    case solves
    case achievements
    case revisions
    case friends
    case freezes
    case settings

    var id: String { rawValue }
}

enum PanelLoadStatus: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)
}

enum DateParser {
    static func parse(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        return parseDateOnly(string)
    }

    static func parseDateOnly(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)
    }
}
