import Foundation

/// Ring endpoints.
///
/// The day's rings and the user's configured goals arrive together from
/// `GET /rings`. They are read together on every card render, and splitting them
/// into two requests would only create a window where the rings are drawn
/// against yesterday's goals.
extension NetworkService {

    private struct RingsEnvelope: Decodable {
        let rings: RingProgress
    }

    private struct GoalsEnvelope: Decodable {
        let goals: RingGoals
        let rings: RingProgress
    }

    /// Today's rings plus the goals in force.
    func getRings() async throws -> RingProgress {
        try await ringsRequest(path: "/rings", method: "GET", body: nil, decode: RingsEnvelope.self).rings
    }

    /// Saves new goals and returns the server's recomputed view of today.
    ///
    /// The server decides whether a change applies today or tomorrow, so its
    /// answer is authoritative — the client must not assume its optimistic
    /// update survived.
    func updateRingGoals(_ goals: RingGoals) async throws -> (goals: RingGoals, rings: RingProgress) {
        let body: [String: Any] = [
            "solveGoal": goals.solveGoal,
            "revisionGoal": goals.revisionGoal,
        ]

        let envelope = try await ringsRequest(
            path: "/rings/goals",
            method: "PATCH",
            body: body,
            decode: GoalsEnvelope.self
        )
        return (envelope.goals, envelope.rings)
    }

    private func ringsRequest<T: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        decode: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NetworkError.invalidURL
        }

        guard let token = keychain.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Ring request failed (Status: \(httpResponse.statusCode))")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[Rings] Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
}
