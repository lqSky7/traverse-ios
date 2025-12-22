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
            isAuthenticated = true
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
            isAuthenticated = true
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Login failed"
            throw error
        }
    }
    
    func logout() {
        networkService.logout()
        isAuthenticated = false
        currentUser = nil
        username = ""
        email = ""
        password = ""
    }
}

