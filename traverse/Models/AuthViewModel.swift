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
    @Published var profileImageUrl: String?
    
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
            // Clear saved cat image
            if let userId = currentUser?.id {
                deleteLocalCatImage(for: userId)
                UserDefaults.standard.removeObject(forKey: "catImageURL_\(userId)")
            }
            // Clear DataManager cache
            DataManager.shared.clearAllData()
            isAuthenticated = false
            currentUser = nil
            profileImageUrl = nil
            username = ""
            email = ""
            password = ""
        } catch {
            // Even if server logout fails, clear local state
            if let userId = currentUser?.id {
                deleteLocalCatImage(for: userId)
                UserDefaults.standard.removeObject(forKey: "catImageURL_\(userId)")
            }
            KeychainHelper.shared.deleteToken()
            // Clear DataManager cache
            DataManager.shared.clearAllData()
            isAuthenticated = false
            currentUser = nil
            profileImageUrl = nil
            username = ""
            email = ""
            password = ""
            throw error
        }
    }
    
    func fetchCurrentUser() async throws {
        do {
            let user = try await networkService.getCurrentUser()
            
            // Fetch cat image if not already set
            var updatedUser = user
            if updatedUser.profileImageURL == nil {
                // Check if we have a saved image for this user
                if let savedImageURL = getSavedCatImageURL(for: user.id) {
                    updatedUser.profileImageURL = savedImageURL
                } else {
                    // Fetch new cat image
                    let catImageURL = try await fetchCatImage()
                    updatedUser.profileImageURL = catImageURL
                    saveCatImageURL(catImageURL, for: user.id)
                }
            }
            
            currentUser = updatedUser
            profileImageUrl = updatedUser.profileImageURL
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
    
    private func fetchCatImage() async throws -> String {
        guard let url = URL(string: "https://api.thecatapi.com/v1/images/search") else {
            throw NetworkError.serverError("Invalid cat API URL")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct CatImage: Codable {
            let url: String
        }
        
        guard let catImages = try? JSONDecoder().decode([CatImage].self, from: data),
              let firstImage = catImages.first else {
            throw NetworkError.serverError("Failed to decode cat image")
        }
        
        // Download the actual image data
        guard let imageURL = URL(string: firstImage.url),
              let (imageData, _) = try? await URLSession.shared.data(from: imageURL) else {
            throw NetworkError.serverError("Failed to download cat image")
        }
        
        // Save image data locally
        let localURL = try saveImageDataLocally(imageData)
        
        return localURL.absoluteString
    }
    
    private func saveImageDataLocally(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let imagesDirectory = cacheDirectory.appendingPathComponent("catImages", isDirectory: true)
        
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func saveCatImageURL(_ url: String, for userId: Int) {
        UserDefaults.standard.set(url, forKey: "catImageURL_\(userId)")
    }
    
    private func getSavedCatImageURL(for userId: Int) -> String? {
        UserDefaults.standard.string(forKey: "catImageURL_\(userId)")
    }
    
    private func deleteLocalCatImage(for userId: Int) {
        if let localURLString = getSavedCatImageURL(for: userId),
           let localURL = URL(string: localURLString) {
            try? FileManager.default.removeItem(at: localURL)
        }
    }
}

