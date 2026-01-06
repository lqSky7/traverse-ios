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
    let request: FriendStreakRequest
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
    
    // Use a computed ID based on friend's ID
    var id: Int { friend.id }
}

struct FriendStreaksResponse: Codable {
    let streaks: [FriendStreak]
}

struct AcceptFriendStreakRequestResponse: Codable {
    let message: String
    let streak: FriendStreakInfo
}

struct FriendStreakInfo: Codable {
    let userId1: Int
    let userId2: Int
    let currentStreak: Int
    let longestStreak: Int
    let users: [FriendStreakUser]
}

struct DeleteFriendStreakResponse: Codable {
    let message: String
}
