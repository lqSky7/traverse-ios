//
//  FriendStreakModels.swift
//  traverse
//

import Foundation

// MARK: - Friend Streak Request Models

struct FriendStreakRequest: Codable, Identifiable {
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

struct SendFriendStreakRequestResponse: Codable {
    let message: String
    /// Optional: the server returns `null` when the request was already sent,
    /// when a streak is already active, or when a mutual request was auto-accepted.
    let request: FriendStreakRequest?
    let alreadyRequested: Bool?
    let alreadyActive: Bool?
    let autoAccepted: Bool?
    let streak: FriendStreak?
}

struct FriendStreakRequestActionResponse: Codable {
    let message: String
}

// MARK: - Active Friend Streak Models

struct FriendStreakUser: Codable, Identifiable {
    let id: Int
    let username: String
    let currentStreak: Int
}

struct FriendStreak: Codable, Identifiable {
    let friend: FriendStreakUser
    let currentStreak: Int
    let longestStreak: Int
    let lastIncrementDate: String?
    let createdAt: String
    /// Set when the streak was reset. Lets the UI say *when* it ended instead of
    /// reporting the loss with no context.
    let brokenAt: String?
    /// True once a day has passed without the streak advancing, so the UI can warn
    /// before it dies rather than after.
    let atRisk: Bool?
    /// Whole days since the streak last advanced.
    let daysSinceIncrement: Int?

    // Use a computed ID based on friend's ID
    var id: Int { friend.id }
}

struct FriendStreaksResponse: Codable {
    let streaks: [FriendStreak]
}

struct AcceptFriendStreakRequestResponse: Codable {
    let message: String
    /// Optional: the accept is idempotent, and the server reports "already active"
    /// without a payload when the streak was started by a concurrent call.
    let streak: FriendStreak?
    let alreadyActive: Bool?
}

struct DeleteFriendStreakResponse: Codable {
    let message: String
}
