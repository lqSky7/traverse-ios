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
}

struct FriendsListResponse: Codable {
    let friends: [Friend]
}

struct RemoveFriendResponse: Codable {
    let message: String
}
