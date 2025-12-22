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
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.unknown
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
                return loginResponse
            } catch {
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.unknown
        }
    }
    
    // MARK: - Check if user is authenticated
    func isAuthenticated() -> Bool {
        return KeychainHelper.shared.getToken() != nil
    }
    
    // MARK: - Logout
    func logout() {
        KeychainHelper.shared.deleteToken()
    }
}
