//
//  FriendsModels.swift
//  traverse
//

import Foundation

// MARK: - User Models
struct UserBasic: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let currentStreak: Int
    let totalXp: Int
}

struct UserProfile: Codable, Identifiable {
    let id: Int
    let username: String
    let timezone: String
    let visibility: String
    let currentStreak: Int
    let totalXp: Int
    let createdAt: String
}

struct UsersSearchResponse: Codable {
    let users: [UserBasic]
}

struct UserProfileResponse: Codable {
    let user: UserProfile
}

// MARK: - Statistics Models
struct UserStatistics: Codable {
    let currentStreak: Int
    let totalXp: Int
    let totalSolves: Int
    let totalSubmissions: Int
    let totalStreakDays: Int
    let problemsByDifficulty: UserProblemsByDifficulty
}

struct UserProblemsByDifficulty: Codable {
    let easy: Int
    let medium: Int
    let hard: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        easy = try container.decodeIfPresent(Int.self, forKey: .easy) ?? 0
        medium = try container.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        hard = try container.decodeIfPresent(Int.self, forKey: .hard) ?? 0
    }
    
    init(easy: Int, medium: Int, hard: Int) {
        self.easy = easy
        self.medium = medium
        self.hard = hard
    }
}

struct UserStatisticsData: Codable {
    let totalSolves: Int
    let totalSubmissions: Int
    let totalStreakDays: Int
    let problemsByDifficulty: UserProblemsByDifficulty
}

struct UserStatisticsResponse: Codable {
    let username: String
    let stats: UserStatisticsData
}

// MARK: - Solves Models
struct UserSolve: Codable, Identifiable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    let aiAnalysis: String?
    let problem: Problem
    let submission: Submission?
    let highlight: Highlight?
}

struct SolvesPagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
}

struct UserSolvesResponse: Codable {
    let username: String
    let solves: [UserSolve]
    let pagination: SolvesPagination
}

// MARK: - Achievements Models
struct Achievement: Codable, Identifiable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let category: String
    let unlockedAt: String
}

struct AchievementsResponse: Codable {
    let username: String
    let achievements: [Achievement]
}

// MARK: - Friend Request Models
struct FriendRequest: Codable, Identifiable {
    let id: Int
    let status: String
    let createdAt: String
    let requester: UserBasic?
    let addressee: UserBasic?
}

struct SendFriendRequestBody: Codable {
    let username: String
}

struct SendFriendRequestResponse: Codable {
    let message: String
    let request: FriendRequest
}

struct FriendRequestsResponse: Codable {
    let requests: [FriendRequest]
}

struct AcceptFriendRequestResponse: Codable {
    let message: String
    let friendship: Friendship
}

struct Friendship: Codable {
    let createdAt: String
    let user1: UserBasic
    let user2: UserBasic
}

struct FriendRequestActionResponse: Codable {
    let message: String
}

// MARK: - Friends Models
struct Friend: Codable, Identifiable {
    let friendshipId: String
    let friendedAt: String
    let id: Int
    let username: String
    let currentStreak: Int
    let totalXp: Int
    let visibility: String
    /// "Close friends" flag. Optional so older cached payloads still decode.
    let favorite: Bool?
}

struct FriendsListResponse: Codable {
    let friends: [Friend]
    /// Cursor for the next page. `nil` when this is the last page.
    let nextCursor: Int?
}

struct RemoveFriendResponse: Codable {
    let message: String
}

// MARK: - Relationship State
//
// The server's authoritative answer to "what is my relationship with this user".
// The client renders the button from `status` and never infers it.
struct RelationshipState: Codable {
    /// One of: self, none, pending_outgoing, pending_incoming, friends, blocked.
    let status: String
    let username: String
    /// Whether an "Add friend" action is available. False when either side has
    /// blocked the other, without disclosing which.
    let canRequest: Bool
    let blockedByMe: Bool
    let friendship: RelationshipFriendship?
    let streak: RelationshipStreak?
    let pendingRequest: RelationshipPendingRequest?

    var isFriends: Bool { status == "friends" }
    var isBlocked: Bool { status == "blocked" }
    var isSelf: Bool { status == "self" }
}

struct RelationshipFriendship: Codable {
    let createdAt: String
    let favorite: Bool
}

struct RelationshipStreak: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastIncrementDate: String?
    let brokenAt: String?
    /// True once a day has passed without the streak advancing. Lets the UI warn
    /// *before* the streak dies rather than reporting the loss afterwards.
    let atRisk: Bool
}

struct RelationshipPendingRequest: Codable {
    let id: Int
    /// "outgoing" if this user sent it, "incoming" if it is waiting for them.
    let direction: String
    let createdAt: String
}

// MARK: - Blocked Users
struct BlockedUser: Codable, Identifiable {
    let id: Int
    let username: String
    let currentStreak: Int
    let totalXp: Int
    let blockedAt: String
}

struct BlockedUsersResponse: Codable {
    let blocked: [BlockedUser]
}
