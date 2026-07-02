import Foundation
import Security

final class TokenStore {
    static let shared = TokenStore()

    private let service = "com.ca5eelo.traversemac"
    private let account = "auth_token"

    private init() {}

    func save(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://traverse-backend-api.azurewebsites.net/api")!
    private let tokenStore = TokenStore.shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private init() {}

    var isAuthenticated: Bool { tokenStore.load() != nil }

    func register(username: String, email: String, password: String) async throws -> AuthResponse {
        let body = RegisterRequest(username: username, email: email, password: password, timezone: TimeZone.current.identifier)
        let response: AuthResponse = try await send("/auth/register", method: "POST", body: body, authorized: false, successCodes: [201])
        if let token = response.token { tokenStore.save(token) }
        return response
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let response: LoginResponse = try await send("/auth/login", method: "POST", body: LoginRequest(username: username, password: password), authorized: false)
        if let token = response.token { tokenStore.save(token) }
        return response
    }

    func logout() async {
        do {
            let _: MessageResponse = try await send("/auth/logout", method: "POST", body: EmptyBody(), authorized: true)
            tokenStore.delete()
        } catch {
            tokenStore.delete()
        }
    }

    func currentUser() async throws -> User {
        let response: UserResponse = try await send("/auth/me", authorized: true)
        return response.user
    }

    func updateProfile(email: String?, timezone: String?, visibility: String?, maxDailyReviews: Int?) async throws -> User {
        let response: UserResponse = try await send(
            "/auth/profile",
            method: "PATCH",
            body: UpdateProfileRequest(email: email, timezone: timezone, visibility: visibility, maxDailyReviews: maxDailyReviews),
            authorized: true
        )
        return response.user
    }

    func changePassword(current: String, new: String) async throws {
        let _: MessageResponse = try await send(
            "/auth/change-password",
            method: "POST",
            body: ChangePasswordRequest(currentPassword: current, newPassword: new),
            authorized: true
        )
    }

    func requestPasswordReset(username: String) async throws -> PasswordResetRequestResponse {
        try await send("/auth/password-reset/request", method: "POST", body: PasswordResetRequest(username: username), authorized: false)
    }

    func confirmPasswordReset(username: String, code: String, newPassword: String) async throws {
        let _: MessageResponse = try await send(
            "/auth/password-reset/confirm",
            method: "POST",
            body: PasswordResetConfirmRequest(username: username, code: code, newPassword: newPassword),
            authorized: false
        )
    }

    func recoverAccount(username: String, password: String?) async throws -> User {
        let response: UserResponse = try await send(
            "/auth/recover",
            method: "POST",
            body: RecoverAccountRequest(username: username, password: password),
            authorized: false
        )
        return response.user
    }

    func deleteAccount(password: String) async throws {
        let _: MessageResponse = try await send("/auth/delete", method: "DELETE", body: DeleteAccountRequest(password: password), authorized: true)
        tokenStore.delete()
    }

    func userStats() async throws -> UserStats {
        try await send("/auth/me/stats", authorized: false)
    }

    func submissionStats() async throws -> SubmissionStats {
        try await send("/submissions/stats/summary", authorized: true)
    }

    func solveStats() async throws -> SolveStats {
        try await send("/solves/stats/summary", authorized: true)
    }

    func solves(limit: Int = 50, offset: Int = 0, difficulty: String? = nil, platform: String? = nil) async throws -> SolvesResponse {
        var items = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let difficulty { items.append(URLQueryItem(name: "difficulty", value: difficulty)) }
        if let platform { items.append(URLQueryItem(name: "platform", value: platform)) }
        return try await send("/solves", queryItems: items, authorized: true)
    }

    func allSolves(pageSize: Int = 100) async throws -> [Solve] {
        var offset = 0
        var results: [Solve] = []
        while true {
            let response = try await solves(limit: pageSize, offset: offset)
            results.append(contentsOf: response.solves)
            offset += response.solves.count
            if response.solves.isEmpty || offset >= response.pagination.total {
                return results
            }
        }
    }

    func achievementStats() async throws -> AchievementStats {
        try await send("/achievements/stats/summary", authorized: true)
    }

    func achievements() async throws -> AllAchievementsResponse {
        try await send("/achievements", authorized: true)
    }

    func searchUsers(_ query: String) async throws -> UsersSearchResponse {
        try await send("/users/search", queryItems: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "10")], authorized: true)
    }

    func userProfile(username: String) async throws -> UserProfile {
        let response: UserProfileResponse = try await send("/users/\(username)", authorized: false)
        return response.user
    }

    func userStatistics(username: String) async throws -> UserStatisticsResponse {
        try await send("/users/\(username)/stats", authorized: false)
    }

    func userSolves(username: String, limit: Int = 100, offset: Int = 0) async throws -> UserSolvesResponse {
        try await send(
            "/solves/user/\(username)",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ],
            authorized: false
        )
    }

    func allUserSolves(username: String, pageSize: Int = 100) async throws -> [UserSolve] {
        var offset = 0
        var results: [UserSolve] = []
        while true {
            let response = try await userSolves(username: username, limit: pageSize, offset: offset)
            results.append(contentsOf: response.solves)
            offset += response.solves.count
            if response.solves.isEmpty || offset >= response.pagination.total {
                return results
            }
        }
    }

    func userAchievements(username: String) async throws -> AchievementsResponse {
        try await send("/achievements/user/\(username)", authorized: false)
    }

    func sendFriendRequest(username: String) async throws {
        let _: SendFriendRequestResponse = try await send("/friends/requests", method: "POST", body: SendFriendRequestBody(username: username), authorized: true)
    }

    func receivedFriendRequests() async throws -> [FriendRequest] {
        let response: FriendRequestsResponse = try await send("/friends/requests/received", authorized: true)
        return response.requests
    }

    func sentFriendRequests() async throws -> [FriendRequest] {
        let response: FriendRequestsResponse = try await send("/friends/requests/sent", authorized: true)
        return response.requests
    }

    func acceptFriendRequest(_ id: Int) async throws {
        let _: MessageResponse = try await send("/friends/requests/\(id)/accept", method: "POST", body: EmptyBody(), authorized: true)
    }

    func rejectFriendRequest(_ id: Int) async throws {
        try await delete("/friends/requests/\(id)")
    }

    func cancelFriendRequest(_ id: Int) async throws {
        try await delete("/friends/requests/\(id)")
    }

    func friends() async throws -> [Friend] {
        let response: FriendsListResponse = try await send("/friends", authorized: true)
        return response.friends
    }

    func removeFriend(username: String) async throws {
        try await delete("/friends/\(username)")
    }

    func revisions(upcoming: Bool = false, overdue: Bool = false, limit: Int = 50, offset: Int = 0, type: String = "normal") async throws -> RevisionsResponse {
        var items = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "type", value: type)
        ]
        if upcoming { items.append(URLQueryItem(name: "upcoming", value: "true")) }
        if overdue { items.append(URLQueryItem(name: "overdue", value: "true")) }
        return try await send("/revisions", queryItems: items, authorized: true)
    }

    func groupedRevisions(includeCompleted: Bool = false, type: String = "normal") async throws -> GroupedRevisionsResponse {
        try await send(
            "/revisions/grouped",
            queryItems: [
                URLQueryItem(name: "includeCompleted", value: includeCompleted ? "true" : "false"),
                URLQueryItem(name: "type", value: type)
            ],
            authorized: true
        )
    }

    func revisionStats(type: String = "normal") async throws -> RevisionStatsResponse {
        try await send("/revisions/stats", queryItems: [URLQueryItem(name: "type", value: type)], authorized: true)
    }

    func revisionAnalytics() async throws -> RevisionAnalyticsResponse {
        try await send("/revisions/analytics", authorized: true)
    }

    func todayRevisions() async throws -> RevisionTodayResponse {
        try await send("/revisions/today", authorized: true)
    }

    func recalibrateMLRevisions() async throws -> RevisionRecalibrationResponse {
        try await send("/revisions/recalibrate", method: "POST", body: EmptyBody(), authorized: true)
    }

    func completeRevision(id: Int) async throws -> CompleteRevisionResponse {
        try await send("/revisions/\(id)/complete", method: "POST", body: EmptyBody(), authorized: true)
    }

    func recordRevisionAttempt(id: Int, outcome: Int, numTries: Int, timeSpentMinutes: Double) async throws -> RevisionAttemptResponse {
        try await send(
            "/revisions/\(id)/attempt",
            method: "POST",
            body: RevisionAttemptRequest(outcome: outcome, numTries: numTries, timeSpentMinutes: timeSpentMinutes),
            authorized: true
        )
    }

    func deleteRevision(id: Int) async throws {
        try await delete("/revisions/\(id)")
    }

    func sendFriendStreakRequest(username: String) async throws {
        let _: MessageResponse = try await send("/friend-streaks/requests", method: "POST", body: SendFriendStreakRequestBody(username: username), authorized: true)
    }

    func receivedFriendStreakRequests() async throws -> [FriendStreakRequest] {
        let response: FriendStreakRequestsResponse = try await send("/friend-streaks/requests/received", authorized: true)
        return response.requests
    }

    func sentFriendStreakRequests() async throws -> [FriendStreakRequest] {
        let response: FriendStreakRequestsResponse = try await send("/friend-streaks/requests/sent", authorized: true)
        return response.requests
    }

    func acceptFriendStreakRequest(_ id: Int) async throws {
        let _: MessageResponse = try await send("/friend-streaks/requests/\(id)/accept", method: "POST", body: EmptyBody(), authorized: true)
    }

    func rejectFriendStreakRequest(_ id: Int) async throws {
        try await delete("/friend-streaks/requests/\(id)")
    }

    func friendStreaks() async throws -> [FriendStreak] {
        let response: FriendStreaksResponse = try await send("/friend-streaks", authorized: true)
        return response.streaks
    }

    func deleteFriendStreak(username: String) async throws {
        try await delete("/friend-streaks/\(username)")
    }

    func subscriptionStatus() async throws -> SubscriptionStatusResponse {
        try await send("/subscription/status", authorized: true)
    }

    func freezeInfo() async throws -> FreezeInfoResponse {
        try await send("/users/me/freezes", authorized: true)
    }

    func purchaseFreezes(count: Int) async throws -> FreezePurchaseResponse {
        try await send("/users/me/freezes/purchase", method: "POST", body: FreezePurchaseRequest(count: count), authorized: true)
    }

    func giftFreeze(to username: String, count: Int) async throws -> FreezeGiftResponse {
        try await send("/users/\(username)/freezes/gift", method: "POST", body: FreezeGiftRequest(username: username, count: count), authorized: true)
    }

    func usedFreezeDates() async throws -> FreezeDatesResponse {
        try await send("/users/me/freezes/used", authorized: true)
    }

    private func delete(_ path: String) async throws {
        let _: MessageResponse = try await send(path, method: "DELETE", body: EmptyBody(), authorized: true, successCodes: [200, 204])
    }

    private func send<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        authorized: Bool
    ) async throws -> Response {
        try await send(path, method: "GET", body: Optional<EmptyBody>.none, queryItems: queryItems, authorized: authorized)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body,
        queryItems: [URLQueryItem] = [],
        authorized: Bool,
        successCodes: Set<Int> = [200]
    ) async throws -> Response {
        try await send(path, method: method, body: Optional(body), queryItems: queryItems, authorized: authorized, successCodes: successCodes)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Body?,
        queryItems: [URLQueryItem] = [],
        authorized: Bool,
        successCodes: Set<Int> = [200]
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized {
            guard let token = tokenStore.load() else { throw NetworkError.unauthenticated }
            request.setValue("auth_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard successCodes.contains(http.statusCode) else {
            if let error = try? decoder.decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(error.error ?? error.message ?? "Request failed (\(http.statusCode))")
            }
            throw NetworkError.serverError("Request failed (\(http.statusCode))")
        }
        if data.isEmpty, Response.self == MessageResponse.self {
            return MessageResponse(message: "OK") as! Response
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
}
