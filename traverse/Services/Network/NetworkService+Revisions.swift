import Foundation

extension NetworkService {
    // MARK: - Get Revisions
    func getRevisions(upcoming: Bool = false, overdue: Bool = false, limit: Int = 50, offset: Int = 0) async throws -> RevisionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/revisions")!
        var queryItems: [URLQueryItem] = []
        
        if upcoming {
            queryItems.append(URLQueryItem(name: "upcoming", value: "true"))
        }
        if overdue {
            queryItems.append(URLQueryItem(name: "overdue", value: "true"))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
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
                let revisionsResponse = try JSONDecoder().decode(RevisionsResponse.self, from: data)
                return revisionsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get revisions (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Grouped Revisions
    func getGroupedRevisions(includeCompleted: Bool = false) async throws -> GroupedRevisionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/revisions/grouped")!
        urlComponents.queryItems = [
            URLQueryItem(name: "includeCompleted", value: includeCompleted ? "true" : "false")
        ]
        
        guard let url = urlComponents.url else {
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
                let groupedResponse = try JSONDecoder().decode(GroupedRevisionsResponse.self, from: data)
                return groupedResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get grouped revisions (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Get Revision Stats
    func getRevisionStats() async throws -> RevisionStatsResponse {
        guard let url = URL(string: "\(baseURL)/revisions/stats") else {
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
                let statsResponse = try JSONDecoder().decode(RevisionStatsResponse.self, from: data)
                return statsResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get revision stats (Status: \(httpResponse.statusCode))")
        }
    }

    // MARK: - Get ML Revision Analytics
    func getRevisionAnalytics() async throws -> RevisionAnalyticsResponse {
        guard let url = URL(string: "\(baseURL)/revisions/analytics") else {
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
                let analytics = try JSONDecoder().decode(RevisionAnalyticsResponse.self, from: data)
                return analytics
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get revision analytics (Status: \(httpResponse.statusCode))")
        }
    }

    // MARK: - Get ML Daily Revisions (Capped)
    func getTodayRevisions() async throws -> RevisionTodayResponse {
        guard let url = URL(string: "\(baseURL)/revisions/today") else {
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
                let response = try JSONDecoder().decode(RevisionTodayResponse.self, from: data)
                return response
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get today revisions (Status: \(httpResponse.statusCode))")
        }
    }



    // MARK: - Pause / Resume ML Revisions
    func pauseMLRevisions(pauseDays: Int = 7) async throws -> PauseRevisionsResponse {
        guard let url = URL(string: "\(baseURL)/revisions/pause") else {
            throw NetworkError.invalidURL
        }

        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = PauseRevisionsRequest(pauseDays: pauseDays)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(PauseRevisionsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to pause revisions (Status: \(httpResponse.statusCode))")
        }
    }

    func resumeMLRevisions(backlogDays: Int = 3) async throws -> ResumeRevisionsResponse {
        guard let url = URL(string: "\(baseURL)/revisions/resume") else {
            throw NetworkError.invalidURL
        }

        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = ResumeRevisionsRequest(backlogDays: backlogDays)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(ResumeRevisionsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to resume revisions (Status: \(httpResponse.statusCode))")
        }
    }

    
    // MARK: - Get Revision Score
    func getRevisionScore() async throws -> RevisionScoreResponse {
        guard let url = URL(string: "\(baseURL)/revisions/score") else {
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
                let scoreResponse = try JSONDecoder().decode(RevisionScoreResponse.self, from: data)
                return scoreResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to get revision score (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Record ML Revision Attempt
    func recordRevisionAttempt(id: Int, outcome: Int, numTries: Int, timeSpentMinutes: Double) async throws -> RevisionAttemptResponse {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)/attempt") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = RevisionAttemptRequest(
            outcome: outcome,
            numTries: numTries,
            timeSpentMinutes: timeSpentMinutes
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let attemptResponse = try JSONDecoder().decode(RevisionAttemptResponse.self, from: data)
                return attemptResponse
            } catch {
                print("Decoding error: \(error)")
                throw NetworkError.decodingError
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to record revision attempt (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Fetch Single Revision Details (On-Demand)
    func fetchRevisionDetails(id: Int) async throws -> RevisionDetailsResponse {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)") else {
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
            return try JSONDecoder().decode(RevisionDetailsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to fetch revision details (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Delete Revision
    func deleteRevision(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to delete revision (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Reschedule Revision
    func rescheduleRevision(id: Int, days: Int) async throws {
        guard let url = URL(string: "\(baseURL)/revisions/\(id)/reschedule") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        let requestBody = ["days": days]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to reschedule revision (Status: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Delete Problem Revisions
    func deleteProblemRevisions(problemId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/revisions/problem/\(problemId)") else {
            throw NetworkError.invalidURL
        }
        
        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to delete problem revisions (Status: \(httpResponse.statusCode))")
        }
    }
    

}
