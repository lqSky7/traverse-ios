import Foundation

extension NetworkService {
    // MARK: - Subscription Status
    
    /// Get subscription status for the authenticated user
    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        guard let url = URL(string: "\(baseURL)/subscription/status") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let statusResponse = try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
                return statusResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get subscription status (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Streak Freezes
    
    /// Get freeze info for the authenticated user
    func getFreezeInfo() async throws -> FreezeInfoResponse {
        guard let url = URL(string: "\(baseURL)/users/me/freezes") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let freezeResponse = try JSONDecoder().decode(FreezeInfoResponse.self, from: data)
                return freezeResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get freeze info (Status: \(httpResponse.statusCode))")
        }
    }
    
    /// Purchase streak freezes (costs XP)
    func purchaseFreezes(count: Int = 1) async throws -> FreezePurchaseResponse {
        guard let url = URL(string: "\(baseURL)/users/me/freezes/purchase") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = ["count": count]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let purchaseResponse = try JSONDecoder().decode(FreezePurchaseResponse.self, from: data)
                return purchaseResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to purchase freezes (Status: \(httpResponse.statusCode))")
        }
    }
    
    /// Gift a freeze to a friend (costs XP)
    func giftFreeze(toUsername username: String, count: Int = 1) async throws -> FreezeGiftResponse {
        guard let url = URL(string: "\(baseURL)/users/\(username)/freezes/gift") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = ["count": count]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let giftResponse = try JSONDecoder().decode(FreezeGiftResponse.self, from: data)
                return giftResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to gift freeze (Status: \(httpResponse.statusCode))")
        }
    }
    
    /// Get dates when streak freezes were used
    func getUsedFreezeDates() async throws -> FreezeDatesResponse {
        guard let url = URL(string: "\(baseURL)/users/me/freezes/used") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let freezeResponse = try JSONDecoder().decode(FreezeDatesResponse.self, from: data)
                return freezeResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get used freeze dates (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - App Updates & Sync
    
    /// Get unified updates on app open (achievements, friend requests, streak requests, freeze info)
    func getAppUpdates() async throws -> AppUpdatesResponse {
        guard let url = URL(string: "\(baseURL)/users/me/updates") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let updatesResponse = try JSONDecoder().decode(AppUpdatesResponse.self, from: data)
                return updatesResponse
            } catch {
                print("Decoding error in getAppUpdates: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get app updates (Status: \(httpResponse.statusCode))")
        }
    }

}
