//
//  AuthModels.swift
//  traverse
//

import Foundation

// MARK: - Request Models
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

// MARK: - Response Models
struct User: Codable {
    let id: Int
    let username: String
    let email: String
    let timezone: String
    let visibility: String
    let currentStreak: Int
    let totalXp: Int
    let createdAt: String?
}

struct AuthResponse: Codable {
    let message: String
    let user: User
    let token: String?
}

struct LoginResponse: Codable {
    let message: String
    let user: User
    let token: String?
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let message: String
}
