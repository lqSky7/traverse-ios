//
//  AuthViewModel.swift
//  traverse
//

import Foundation
import Combine
import UserNotifications

@MainActor
class AuthViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var otpCode: String = ""
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
        // Detached before the token is deleted, because the request needs the
        // session. Without this the signed-out device keeps receiving pushes for
        // an account nobody is logged into, and the next user to sign in on this
        // phone would see the previous user's notifications on the lock screen.
        await PushRegistrationService.shared.unregisterFromServer()

        do {
            try await networkService.logout()
        } catch {
            clearLocalSessionData()
            throw error
        }

        clearLocalSessionData()
    }

    private func clearLocalSessionData() {
        let fileManager = FileManager.default
        if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: cacheDirectory.appendingPathComponent("catImages", isDirectory: true))
        }
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("catImageURL_") {
            UserDefaults.standard.removeObject(forKey: key)
        }

        DataManager.shared.clearAllData()
        AchievementToastManager.shared.resetState()
        NotificationInboxManager.shared.clear()
        RingsManager.shared.clearCache()
        PushRegistrationService.shared.clearLocalRegistrationState()
        UserDefaults.standard.removeObject(forKey: "cachedExamModeActive")

        if let sharedDefaults = UserDefaults(suiteName: "group.com.traverse.app") {
            sharedDefaults.removeObject(forKey: "widgetData")
        }

        KeychainHelper.shared.deleteToken()
        isAuthenticated = false
        currentUser = nil
        profileImageUrl = nil
        username = ""
        email = ""
        password = ""
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

            // A session now exists, which is the first moment a device token can
            // be uploaded. Doing it here rather than at each call site covers
            // sign-in, sign-up and a session restored from the keychain in one
            // place.
            await registerForPushIfAuthorized()
        } catch let error as NetworkError {
            if case .unauthorized = error {
                clearLocalSessionData()
            }
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Failed to fetch user data"
            throw error
        }
    }

    /// Registers with APNs and uploads the token, but only when the user has
    /// already granted permission.
    ///
    /// Registering before permission is granted yields a token APNs will not
    /// deliver to, so the prompt has to come first. The prompt is raised from the
    /// notification settings screen and from the revisions screen; this path only
    /// handles the case where it has already been answered.
    private func registerForPushIfAuthorized() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        PushRegistrationService.shared.register()
        // Uploads the cached token, or does nothing when iOS has not issued one
        // yet — in which case the app delegate's callback uploads it shortly.
        await PushRegistrationService.shared.uploadIfPossible()
    }
    
    func updateProfile(
        email: String?,
        timezone: String?,
        visibility: String?,
        maxDailyReviews: Int? = nil
    ) async throws {
        do {
            let updatedUser = try await networkService.updateProfile(
                email: email,
                timezone: timezone,
                visibility: visibility,
                maxDailyReviews: maxDailyReviews
            )
            var mergedUser = updatedUser
            if mergedUser.profileImageURL == nil {
                mergedUser.profileImageURL = currentUser?.profileImageURL
            }
            currentUser = mergedUser
            profileImageUrl = mergedUser.profileImageURL
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
            _ = try await networkService.deleteAccount(password: password)
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
