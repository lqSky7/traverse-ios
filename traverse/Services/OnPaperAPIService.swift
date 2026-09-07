//
//  OnPaperAPIService.swift
//  traverse
//
//  Network and Cognito Authentication client for OnPaper AWS Serverless backend
//  Completely isolated authentication state from Traverse main app.
//

import Foundation
import Combine
import SwiftUI
import Security

// MARK: - Isolated Keychain Helper for OnPaper
public class OnPaperKeychainHelper {
    public static let shared = OnPaperKeychainHelper()
    private init() {}
    
    private let service = "com.traverse.onpaper.auth"
    private let account = "onpaperAuthToken"
    
    public func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        deleteToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }
    
    public func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - OnPaper API Service
public class OnPaperAPIService: ObservableObject {
    public static let shared = OnPaperAPIService()
    
    @Published public var endpoint: String = "https://xa9njv2kaf.execute-api.ap-south-1.amazonaws.com"
    @Published public var userPoolClientId: String = "4e9q03na5smhc5pm49kunb0oi3"
    @Published public var region: String = "ap-south-1"
    
    @Published public var authToken: String? {
        didSet {
            if let token = authToken {
                _ = OnPaperKeychainHelper.shared.saveToken(token)
            } else {
                OnPaperKeychainHelper.shared.deleteToken()
            }
        }
    }
    @Published public var currentUsername: String? {
        didSet {
            if let user = currentUsername {
                UserDefaults.standard.set(user, forKey: "onpaper_standalone_username")
            } else {
                UserDefaults.standard.removeObject(forKey: "onpaper_standalone_username")
            }
        }
    }
    
    @Published public var summary: OnPaperProgressSummary?
    @Published public var preferences: OnPaperUserPreferences?
    @Published public var projects: [OnPaperProject] = []
    @Published public var sessions: [OnPaperSession] = []
    @Published public var mistakes: [OnPaperMistake] = []
    @Published public var dueCards: [OnPaperFSRSCard] = []
    @Published public var isLoading: Bool = false
    @Published public var lastSyncTime: Date?
    @Published public var errorMessage: String?
    
    private init() {
        self.authToken = OnPaperKeychainHelper.shared.getToken()
        self.currentUsername = UserDefaults.standard.string(forKey: "onpaper_standalone_username")
    }
    
    // MARK: - Cognito Authentication
    public func loginWithCognito(username: String, password: String) async throws {
        let url = URL(string: "\(endpoint)/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                await MainActor.run {
                    self.authToken = token
                    self.currentUsername = username
                }
                await refreshAll()
            }
        } else {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = errorJson["message"] as? String ?? "Authentication failed (Status \(httpResponse.statusCode))"
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    public func registerWithCognito(username: String, email: String, password: String) async throws {
        let url = URL(string: "\(endpoint)/v1/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["username": username, "email": email, "password": password])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                await MainActor.run {
                    self.authToken = token
                    self.currentUsername = username
                }
                await refreshAll()
            }
        } else {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = errorJson["message"] as? String ?? "Registration failed"
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    public func signOut() {
        self.authToken = nil
        self.currentUsername = nil
        self.summary = nil
        self.preferences = nil
        self.projects = []
        self.sessions = []
        self.mistakes = []
        self.dueCards = []
        OnPaperKeychainHelper.shared.deleteToken()
    }
    
    // MARK: - Data Synchronization
    public func refreshAll() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            async let summaryTask = fetchSummary()
            async let prefsTask = fetchPreferences()
            async let projectsTask = fetchProjects()
            async let sessionsTask = fetchSessions()
            async let mistakesTask = fetchMistakes()
            async let dueCardsTask = fetchDueCards()
            
            let (sum, prefs, projs, sess, mists, cards) = try await (summaryTask, prefsTask, projectsTask, sessionsTask, mistakesTask, dueCardsTask)
            
            await MainActor.run {
                self.summary = sum
                self.preferences = prefs
                self.projects = projs
                self.sessions = sess
                self.mistakes = mists
                self.dueCards = cards
                self.lastSyncTime = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func createRequest(path: String, method: String = "GET") -> URLRequest {
        let url = URL(string: "\(endpoint)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    public func fetchSummary() async throws -> OnPaperProgressSummary {
        let request = createRequest(path: "/v1/progress/summary")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(OnPaperProgressSummary.self, from: data)
    }
    
    public func fetchPreferences() async throws -> OnPaperUserPreferences {
        let request = createRequest(path: "/v1/preferences")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(OnPaperUserPreferences.self, from: data)
    }
    
    public func fetchProjects() async throws -> [OnPaperProject] {
        let request = createRequest(path: "/v1/projects")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OnPaperProject].self, from: data)
    }
    
    public func fetchSessions() async throws -> [OnPaperSession] {
        let request = createRequest(path: "/v1/sessions")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OnPaperSession].self, from: data)
    }
    
    public func fetchMistakes(status: String? = nil) async throws -> [OnPaperMistake] {
        var path = "/v1/mistakes"
        if let status = status {
            path += "?status=\(status)"
        }
        let request = createRequest(path: path)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OnPaperMistake].self, from: data)
    }
    
    public func fetchDueCards() async throws -> [OnPaperFSRSCard] {
        let request = createRequest(path: "/v1/cards/due")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OnPaperFSRSCard].self, from: data)
    }
    
    public func submitFSRSReview(cardId: String, rating: String) async throws -> OnPaperFSRSCard {
        var request = createRequest(path: "/v1/cards/\(cardId)/reviews", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["rating": rating])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let updated = try JSONDecoder().decode(OnPaperFSRSCard.self, from: data)
        
        await MainActor.run {
            self.dueCards.removeAll(where: { $0.cardId == cardId })
        }
        
        return updated
    }
}
