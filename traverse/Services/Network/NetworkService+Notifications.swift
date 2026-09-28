import Foundation

/// Notification endpoints: the inbox, the unread badge, preferences, and push
/// token registration.
extension NetworkService {

    struct NotificationPage: Decodable {
        let notifications: [AppNotification]
        let nextCursor: Int?
        let unreadCount: Int
    }

    struct PreferencesEnvelope: Decodable {
        let preferences: NotificationPreferences
        /// False when the server has no APNs credentials. Surfaced so the
        /// settings screen can say pushes are not live yet, instead of letting
        /// the user toggle switches that cannot have any effect.
        let pushConfigured: Bool?
    }

    // MARK: - Inbox

    /// One page of the inbox, newest first.
    ///
    /// Keyset pagination: `cursor` is the id of the last row already held, so
    /// rows arriving while the user scrolls cannot shift the page boundary and
    /// cause a duplicate or a skipped notification.
    func getNotifications(limit: Int = 30, cursor: Int? = nil) async throws -> NotificationPage {
        var path = "/notifications?limit=\(limit)"
        if let cursor {
            path += "&cursor=\(cursor)"
        }
        return try await notificationRequest(path: path, method: "GET", body: nil)
    }

    func getUnreadNotificationCount() async throws -> Int {
        struct Envelope: Decodable { let unreadCount: Int }
        let envelope: Envelope = try await notificationRequest(
            path: "/notifications/unread-count",
            method: "GET",
            body: nil
        )
        return envelope.unreadCount
    }

    func markNotificationRead(id: Int) async throws {
        struct Envelope: Decodable { let success: Bool }
        let _: Envelope = try await notificationRequest(
            path: "/notifications/\(id)/read",
            method: "POST",
            body: [:]
        )
    }

    func markAllNotificationsRead() async throws {
        struct Envelope: Decodable { let success: Bool }
        let _: Envelope = try await notificationRequest(
            path: "/notifications/read-all",
            method: "POST",
            body: [:]
        )
    }

    // MARK: - Preferences

    func getNotificationPreferences() async throws -> (preferences: NotificationPreferences, pushConfigured: Bool) {
        let envelope: PreferencesEnvelope = try await notificationRequest(
            path: "/notifications/preferences",
            method: "GET",
            body: nil
        )
        return (envelope.preferences, envelope.pushConfigured ?? false)
    }

    /// Sends only the switches that changed.
    ///
    /// The server applies a partial patch, so sending one type does not disturb
    /// the others. Sending the whole list would make a stale client able to
    /// revert a change made on another device.
    func updateNotificationPreferences(
        types: [[String: Any]]? = nil,
        quietHours: [String: Any]? = nil
    ) async throws -> NotificationPreferences {
        var body: [String: Any] = [:]
        if let types { body["types"] = types }
        if let quietHours { body["quietHours"] = quietHours }

        struct Envelope: Decodable { let preferences: NotificationPreferences }
        let envelope: Envelope = try await notificationRequest(
            path: "/notifications/preferences",
            method: "PATCH",
            body: body
        )
        return envelope.preferences
    }

    // MARK: - Push tokens

    /// Registers this device's APNs token.
    ///
    /// `sandbox` is sent because sandbox vs production is a property of the
    /// *token*, not of the server: a debug or TestFlight build gets a sandbox
    /// token that the production APNs host rejects. The server stores it per
    /// token and picks the host from it.
    func registerPushToken(_ token: String, sandbox: Bool, deviceId: String? = nil) async throws {
        struct Envelope: Decodable { let success: Bool }

        var body: [String: Any] = [
            "token": token,
            "platform": "ios",
            "sandbox": sandbox,
        ]
        if let deviceId { body["deviceId"] = deviceId }

        let _: Envelope = try await notificationRequest(
            path: "/notifications/push-token",
            method: "POST",
            body: body
        )
    }

    /// Removes this device's token, so a signed-out device stops receiving
    /// pushes for the account that just signed out.
    func unregisterPushToken(_ token: String) async throws {
        struct Envelope: Decodable { let success: Bool }
        let _: Envelope = try await notificationRequest(
            path: "/notifications/push-token",
            method: "DELETE",
            body: ["token": token]
        )
    }

    // MARK: - Transport

    private func notificationRequest<T: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NetworkError.invalidURL
        }

        guard let token = KeychainHelper.shared.getToken() else {
            throw NetworkError.serverError("Not authenticated")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await NetworkService.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error)
            }
            throw NetworkError.serverError("Notification request failed (Status: \(httpResponse.statusCode))")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[Notifications] Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
}
