import Foundation

extension NetworkService {
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get user achievements (Status: \(httpResponse.statusCode))")
        }
    }
    

}
