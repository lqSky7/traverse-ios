//
//  NetworkService.swift
//  traverse
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return message
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private let baseURL = "https://traverse-backend-api.azurewebsites.net/api"
    
    private init() {}
    
    // MARK: - Register User
    func register(username: String, email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw NetworkError.invalidURL
        }
        
        let timezone = TimeZone.current.identifier
        let requestBody = RegisterRequest(username: username, email: email, password: password, timezone: timezone)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                
                // Save token to Keychain if present
                if let token = authResponse.token {
                    _ = KeychainHelper.shared.saveToken(token)
                }
                
                return authResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Error response: \(responseString)")
            }
            
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Registration failed (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Login User
    func login(username: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw NetworkError.invalidURL
        }
        
        let requestBody = LoginRequest(username: username, password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                
                // Save token to Keychain if present
                if let token = loginResponse.token {
                    _ = KeychainHelper.shared.saveToken(token)
                }
                
                return loginResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Error response: \(responseString)")
            }
            
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Authentication failed (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Check if user is authenticated
    func isAuthenticated() -> Bool {
        return KeychainHelper.shared.getToken() != nil
    }
    
    // MARK: - Logout
    func logout() async throws {
        guard let url = URL(string: "\(baseURL)/auth/logout") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            // Already logged out
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            KeychainHelper.shared.deleteToken()
        } else {
            throw NetworkError.serverError("Logout failed (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Current User
    func getCurrentUser() async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                return userResponse.user
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(email: String?, timezone: String?, visibility: String?) async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/profile") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = UpdateProfileRequest(email: email, timezone: timezone, visibility: visibility)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                return userResponse.user
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to update profile (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Change Password
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/change-password") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to change password (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount(password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/account") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = DeleteAccountRequest(password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let deleteResponse = try JSONDecoder().decode(MessageResponse.self, from: data)
                KeychainHelper.shared.deleteToken()
                return deleteResponse.message
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to delete account (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Recover Account
    func recoverAccount(username: String, password: String?) async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/recover") else {
            throw NetworkError.invalidURL
        }
        
        let requestBody = RecoverAccountRequest(username: username, password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add existing token if available
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let recoveryResponse = try JSONDecoder().decode(RecoveryResponse.self, from: data)
                return recoveryResponse.user
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to recover account (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get User Statistics (Authenticated - for own stats)
    func getUserStats(username: String) async throws -> UserStats {
        guard let url = URL(string: "\(baseURL)/auth/me/stats") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let userStats = try JSONDecoder().decode(UserStats.self, from: data)
                return userStats
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user stats (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Submission Statistics
    func getSubmissionStats() async throws -> SubmissionStats {
        guard let url = URL(string: "\(baseURL)/submissions/stats/summary") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let submissionStats = try JSONDecoder().decode(SubmissionStats.self, from: data)
                return submissionStats
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get submission stats (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Solve Statistics
    func getSolveStats() async throws -> SolveStats {
        guard let url = URL(string: "\(baseURL)/solves/stats/summary") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let solveStats = try JSONDecoder().decode(SolveStats.self, from: data)
                return solveStats
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get solve stats (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - List Solves
    func getSolves(limit: Int = 50, offset: Int = 0, difficulty: String? = nil, platform: String? = nil) async throws -> SolvesResponse {
        var components = URLComponents(string: "\(baseURL)/solves")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let difficulty = difficulty {
            components?.queryItems?.append(URLQueryItem(name: "difficulty", value: difficulty))
        }
        
        if let platform = platform {
            components?.queryItems?.append(URLQueryItem(name: "platform", value: platform))
        }
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let solvesResponse = try JSONDecoder().decode(SolvesResponse.self, from: data)
                return solvesResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get solves (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Achievement Statistics
    func getAchievementStats() async throws -> AchievementStats {
        guard let url = URL(string: "\(baseURL)/achievements/stats/summary") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let achievementStats = try JSONDecoder().decode(AchievementStats.self, from: data)
                return achievementStats
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get achievement stats (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get All Achievements
    func getAllAchievements() async throws -> AllAchievementsResponse {
        guard let url = URL(string: "\(baseURL)/achievements") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let achievementsResponse = try JSONDecoder().decode(AllAchievementsResponse.self, from: data)
                return achievementsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get achievements (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Search Users
    func searchUsers(query: String, limit: Int = 10) async throws -> UsersSearchResponse {
        var components = URLComponents(string: "\(baseURL)/users")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let searchResponse = try JSONDecoder().decode(UsersSearchResponse.self, from: data)
                return searchResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to search users (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get User Profile
    func getUserProfile(username: String) async throws -> UserProfile {
        guard let url = URL(string: "\(baseURL)/users/\(username)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
                return profileResponse.user
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user profile (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get User Statistics (Public)
    func getUserStatistics(username: String) async throws -> UserStatisticsResponse {
        guard let url = URL(string: "\(baseURL)/users/\(username)/stats") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let statsResponse = try JSONDecoder().decode(UserStatisticsResponse.self, from: data)
                return statsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user statistics (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get User's Public Solves
    func getUserSolves(username: String, limit: Int = 50, offset: Int = 0) async throws -> UserSolvesResponse {
        var components = URLComponents(string: "\(baseURL)/solves/user/\(username)")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let solvesResponse = try JSONDecoder().decode(UserSolvesResponse.self, from: data)
                return solvesResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user solves (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get User's Achievements
    func getUserAchievements(username: String) async throws -> AchievementsResponse {
        guard let url = URL(string: "\(baseURL)/achievements/user/\(username)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let achievementsResponse = try JSONDecoder().decode(AchievementsResponse.self, from: data)
                return achievementsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get user achievements (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Send Friend Request
    func sendFriendRequest(username: String) async throws -> SendFriendRequestResponse {
        guard let url = URL(string: "\(baseURL)/friends/request") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = SendFriendRequestBody(username: username)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let friendRequestResponse = try JSONDecoder().decode(SendFriendRequestResponse.self, from: data)
                return friendRequestResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("Friend request error (\(httpResponse.statusCode)): \(errorResponse.message)")
                throw NetworkError.serverError(errorResponse.message)
            }
            let responseString = String(data: data, encoding: .utf8) ?? "unknown"
            print("Failed to send friend request. Status: \(httpResponse.statusCode), Response: \(responseString)")
            throw NetworkError.serverError("Failed to send friend request (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Received Friend Requests
    func getReceivedFriendRequests() async throws -> [FriendRequest] {
        guard let url = URL(string: "\(baseURL)/friends/requests/received") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let requestsResponse = try JSONDecoder().decode(FriendRequestsResponse.self, from: data)
                return requestsResponse.requests
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get received requests (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Sent Friend Requests
    func getSentFriendRequests() async throws -> [FriendRequest] {
        guard let url = URL(string: "\(baseURL)/friends/requests/sent") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let requestsResponse = try JSONDecoder().decode(FriendRequestsResponse.self, from: data)
                return requestsResponse.requests
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get sent requests (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Accept Friend Request
    func acceptFriendRequest(requestId: Int) async throws -> AcceptFriendRequestResponse {
        guard let url = URL(string: "\(baseURL)/friends/requests/\(requestId)/accept") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let acceptResponse = try JSONDecoder().decode(AcceptFriendRequestResponse.self, from: data)
                return acceptResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to accept friend request (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Reject Friend Request
    func rejectFriendRequest(requestId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/friends/requests/\(requestId)/reject") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to reject friend request (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Cancel Friend Request
    func cancelFriendRequest(requestId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/friends/requests/\(requestId)") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to cancel friend request (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - List Friends
    func getFriends() async throws -> [Friend] {
        guard let url = URL(string: "\(baseURL)/friends") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let friendsResponse = try JSONDecoder().decode(FriendsListResponse.self, from: data)
                return friendsResponse.friends
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get friends (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Remove Friend
    func removeFriend(username: String) async throws {
        guard let url = URL(string: "\(baseURL)/friends/\(username)") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to remove friend (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Friend's Solves
    func getFriendSolves(username: String, limit: Int = 50, offset: Int = 0) async throws -> UserSolvesResponse {
        var components = URLComponents(string: "\(baseURL)/friends/\(username)/solves")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let solvesResponse = try JSONDecoder().decode(UserSolvesResponse.self, from: data)
                return solvesResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get friend's solves (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Friend's Statistics
    func getFriendStatistics(username: String) async throws -> UserStatisticsResponse {
        guard let url = URL(string: "\(baseURL)/friends/\(username)/stats") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let statsResponse = try JSONDecoder().decode(UserStatisticsResponse.self, from: data)
                return statsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get friend's statistics (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Friend's Achievements
    func getFriendAchievements(username: String) async throws -> AchievementsResponse {
        guard let url = URL(string: "\(baseURL)/friends/\(username)/achievements") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let achievementsResponse = try JSONDecoder().decode(AchievementsResponse.self, from: data)
                return achievementsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get friend's achievements (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Revisions
    func getRevisions(upcoming: Bool = false, overdue: Bool = false, limit: Int = 50, offset: Int = 0, type: String = "normal") async throws -> RevisionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/revisions")!
        var queryItems: [URLQueryItem] = []
        
        if upcoming {
            queryItems.append(URLQueryItem(name: "upcoming", value: "true"))
        }
        if overdue {
            queryItems.append(URLQueryItem(name: "overdue", value: "true"))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        queryItems.append(URLQueryItem(name: "type", value: type))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let revisionsResponse = try JSONDecoder().decode(RevisionsResponse.self, from: data)
                return revisionsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get revisions (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Grouped Revisions
    func getGroupedRevisions(includeCompleted: Bool = false, type: String = "normal") async throws -> GroupedRevisionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/revisions/grouped")!
        urlComponents.queryItems = [
            URLQueryItem(name: "includeCompleted", value: includeCompleted ? "true" : "false"),
            URLQueryItem(name: "type", value: type)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let groupedResponse = try JSONDecoder().decode(GroupedRevisionsResponse.self, from: data)
                return groupedResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get grouped revisions (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Revision Stats
    func getRevisionStats(type: String = "normal") async throws -> RevisionStatsResponse {
        var components = URLComponents(string: "\(baseURL)/revisions/stats")!
        components.queryItems = [
            URLQueryItem(name: "type", value: type)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let statsResponse = try JSONDecoder().decode(RevisionStatsResponse.self, from: data)
                return statsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to get revision stats (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Complete Revision
    func completeRevision(id: Int) async throws -> CompleteRevisionResponse {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)/complete") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let completeResponse = try JSONDecoder().decode(CompleteRevisionResponse.self, from: data)
                return completeResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to complete revision (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Record ML Revision Attempt
    func recordRevisionAttempt(id: Int, outcome: Int, numTries: Int, timeSpentMinutes: Double) async throws -> RevisionAttemptResponse {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)/attempt") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = RevisionAttemptRequest(
            outcome: outcome,
            numTries: numTries,
            timeSpentMinutes: timeSpentMinutes
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let attemptResponse = try JSONDecoder().decode(RevisionAttemptResponse.self, from: data)
                return attemptResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("Failed to record revision attempt (Status: \(httpResponse.statusCode))")
        }
    }
}
