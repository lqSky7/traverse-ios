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

// MARK: - Response Models
struct User: Codable {
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
    var calendarToken: String?
    var isSubscriptionActive: Bool?
}

struct AuthResponse: Codable {
    let message: String
    let user: User
    let token: String?
    let refreshToken: String?
}

struct LoginResponse: Codable {
    let message: String
    let user: User
    let token: String?
    let refreshToken: String?
}

struct UserResponse: Codable {
    let user: User
}

struct MessageResponse: Codable {
    let message: String
}

struct PasswordResetRequestResponse: Codable {
    let status: String
    let message: String
    let expiresInMinutes: Int?
}

struct RecoveryResponse: Codable {
    let message: String
    let user: User
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Social (WorkOS) Auth

/// Social identity providers exposed by the backend via WorkOS.
/// The raw value is what the backend's `/auth/social/:provider` route expects.
enum SocialProvider: String, CaseIterable, Identifiable {
    case google
    case github
    case apple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .github: return "GitHub"
        case .apple: return "Apple"
        }
    }

    var systemImage: String {
        switch self {
        case .google: return "globe"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .apple: return "apple.logo"
        }
    }
}

/// Response of `GET /auth/social/:provider` — the WorkOS authorization URL.
struct SocialAuthURLResponse: Codable {
    let url: String
}

/// Request body for `POST /auth/social/callback`.
struct SocialCallbackRequest: Codable {
    let code: String
}
