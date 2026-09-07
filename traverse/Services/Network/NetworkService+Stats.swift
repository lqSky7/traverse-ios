import Foundation

extension NetworkService {
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
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
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get achievements (Status: \(httpResponse.statusCode))")
        }
    }
    

}
