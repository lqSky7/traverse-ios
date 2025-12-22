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
}
