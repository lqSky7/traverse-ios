//
//  AuthViewModel.swift
//  traverse
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    
    init() {
        checkAuthentication()
        if isAuthenticated {
            Task {
                try? await fetchCurrentUser()
            }
        }
    }
    
    func checkAuthentication() {
        isAuthenticated = networkService.isAuthenticated()
    }
    
    func register() async throws {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            throw NetworkError.serverError("Please fill in all fields")
        }
        
        do {
            let response = try await networkService.register(
                username: username,
                email: email,
                password: password
            )
            
            currentUser = response.user
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Registration failed"
            throw error
        }
    }
    
    func login(username: String, password: String) async throws {
        do {
            let response = try await networkService.login(
                username: username,
                password: password
            )
            
            currentUser = response.user
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Login failed"
            throw error
        }
    }
    
    func logout() async throws {
        do {
            try await networkService.logout()
            isAuthenticated = false
            currentUser = nil
            username = ""
            email = ""
            password = ""
        } catch {
            // Even if server logout fails, clear local state
            KeychainHelper.shared.deleteToken()
            isAuthenticated = false
            currentUser = nil
            username = ""
            email = ""
            password = ""
            throw error
        }
    }
    
    func fetchCurrentUser() async throws {
        do {
            let user = try await networkService.getCurrentUser()
            currentUser = user
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to fetch user data"
            throw error
        }
    }
    
    func updateProfile(email: String, timezone: String, visibility: String) async throws {
        do {
            let updatedUser = try await networkService.updateProfile(
                email: email,
                timezone: timezone,
                visibility: visibility
            )
            currentUser = updatedUser
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to update profile"
            throw error
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        do {
            try await networkService.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to change password"
            throw error
        }
    }
    
    func deleteAccount(password: String) async throws {
        do {
            let message = try await networkService.deleteAccount(password: password)
            // Account deleted - logout
            isAuthenticated = false
            currentUser = nil
            username = ""
            email = ""
            self.password = ""
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to delete account"
            throw error
        }
    }
    
    func recoverAccount(username: String, password: String?) async throws {
        do {
            let user = try await networkService.recoverAccount(
                username: username,
                password: password
            )
            currentUser = user
            isAuthenticated = true
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to recover account"
            throw error
        }
    }
}

