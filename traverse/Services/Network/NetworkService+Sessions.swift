import Foundation

extension NetworkService {
    func getAuthSessions() async throws -> AuthSessionsResponse {
        guard let url = URL(string: "\(baseURL)/auth/sessions") else {
            throw NetworkError.invalidURL
        }
        guard let token = keychain.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError(
                "Failed to load active sessions (Status: \(httpResponse.statusCode))"
            )
        }

        do {
            return try JSONDecoder().decode(AuthSessionsResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    func revokeAuthSession(id: String) async throws -> AuthSessionActionResponse {
        guard let url = URL(string: "\(baseURL)/auth/sessions")?.appendingPathComponent(id) else {
            throw NetworkError.invalidURL
        }
        return try await performSessionRevocationRequest(url: url)
    }

    func revokeOtherAuthSessions() async throws -> AuthSessionActionResponse {
        guard let url = URL(string: "\(baseURL)/auth/sessions/others") else {
            throw NetworkError.invalidURL
        }
        return try await performSessionRevocationRequest(url: url)
    }

    private func performSessionRevocationRequest(url: URL) async throws -> AuthSessionActionResponse {
        guard let token = keychain.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Failed to revoke session (Status: \(httpResponse.statusCode))")
        }

        do {
            return try JSONDecoder().decode(AuthSessionActionResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
