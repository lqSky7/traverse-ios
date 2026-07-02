import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    @Published var userStats: UserStats?
    @Published var submissionStats: SubmissionStats?
    @Published var solveStats: SolveStats?
    @Published var achievementStats: AchievementStats?
    @Published var achievements: [AchievementDetail] = []
    @Published var recentSolves: [Solve] = []
    @Published var allSolves: [Solve] = []

    @Published var revisionGroups: [RevisionGroup] = []
    @Published var revisionStats: RevisionStatsResponse?
    @Published var revisionAnalytics: RevisionAnalyticsResponse?
    @Published var todayRevisions: RevisionTodayResponse?
    @Published var revisionMode = "normal"

    @Published var friends: [Friend] = []
    @Published var receivedRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var receivedStreakRequests: [FriendStreakRequest] = []
    @Published var sentStreakRequests: [FriendStreakRequest] = []
    @Published var friendStreaks: [FriendStreak] = []

    @Published var subscriptionStatus: SubscriptionStatusResponse?
    @Published var freezeInfo: FreezeInfoResponse?
    @Published var freezeDates: [String] = []
    @Published var panelStatuses: [PanelKey: PanelLoadStatus] = Dictionary(uniqueKeysWithValues: PanelKey.allCases.map { ($0, .idle) })
    @Published var lastCacheDate: Date?

    private let api = APIClient.shared
    private let cache = LocalCacheStore()

    var isAuthenticated: Bool { user != nil }

    init() {
        restoreCache()
        if api.isAuthenticated {
            Task { await bootstrap() }
        }
    }

    func bootstrap() async {
        await run {
            user = try await api.currentUser()
            await refreshAll()
        }
    }

    func login(username: String, password: String) async {
        await run {
            user = try await api.login(username: username, password: password).user
            await refreshAll()
        }
    }

    func register(username: String, email: String, password: String) async {
        await run {
            user = try await api.register(username: username, email: email, password: password).user
            await refreshAll()
        }
    }

    func logout() async {
        await api.logout()
        user = nil
        clearData()
    }

    func refreshAll() async {
        guard user != nil else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshHomePanels() }
            group.addTask { await self.refreshAllSolves() }
            group.addTask { await self.refreshFriends() }
            group.addTask { await self.refreshFreezes() }
            group.addTask { await self.refreshRevisions() }
        }
        persistCache()
    }

    func refreshRevisions() async {
        revisionMode = "ml"
        await run(panel: .revisions) {
            async let grouped = api.groupedRevisions(includeCompleted: false, type: "ml")
            async let stats = api.revisionStats(type: "ml")
            self.revisionGroups = try await grouped.groups
            self.revisionStats = try await stats
            async let analytics = api.revisionAnalytics()
            async let today = api.todayRevisions()
            self.revisionAnalytics = try await analytics
            self.todayRevisions = try await today
        }
    }

    func refreshHomePanels() async {
        await run(panel: .home) {
            async let userStats = api.userStats()
            async let submissionStats = api.submissionStats()
            async let solveStats = api.solveStats()
            async let achievementStats = api.achievementStats()
            async let achievements = api.achievements()
            self.userStats = try await userStats
            self.submissionStats = try await submissionStats
            self.solveStats = try await solveStats
            self.achievementStats = try await achievementStats
            self.achievements = try await achievements.achievements
            self.recentSolves = Array(self.allSolves.prefix(10))
        }
        if case .failed = panelStatuses[.home] {
            return
        }
        panelStatuses[.charts] = panelStatuses[.home] ?? .idle
        panelStatuses[.achievements] = panelStatuses[.home] ?? .idle
    }

    func refreshAllSolves() async {
        await run(panel: .solves) {
            self.allSolves = try await api.allSolves()
            self.recentSolves = Array(self.allSolves.prefix(10))
        }
    }

    func refreshFriends() async {
        await run(panel: .friends) {
            async let friends = api.friends()
            async let received = api.receivedFriendRequests()
            async let sent = api.sentFriendRequests()
            async let streaks = api.friendStreaks()
            async let receivedStreaks = api.receivedFriendStreakRequests()
            async let sentStreaks = api.sentFriendStreakRequests()
            self.friends = try await friends
            self.receivedRequests = try await received
            self.sentRequests = try await sent
            self.friendStreaks = try await streaks
            self.receivedStreakRequests = try await receivedStreaks
            self.sentStreakRequests = try await sentStreaks
        }
    }

    func refreshFreezes() async {
        await run(panel: .freezes) {
            async let subscription = api.subscriptionStatus()
            async let freezes = api.freezeInfo()
            async let freezeDates = api.usedFreezeDates()
            self.subscriptionStatus = try await subscription
            self.freezeInfo = try await freezes
            self.freezeDates = try await freezeDates.freezeDates
        }
    }

    func completeRevision(_ revision: Revision) async {
        await run {
            _ = try await api.completeRevision(id: revision.id)
            statusMessage = "Revision completed"
            await refreshRevisions()
        }
    }

    func recordAttempt(_ revision: Revision, success: Bool, tries: Int, minutes: Double) async {
        await run {
            let response = try await api.recordRevisionAttempt(id: revision.id, outcome: success ? 1 : 0, numTries: tries, timeSpentMinutes: minutes)
            statusMessage = "Next review in \(Int(response.prediction.nextReviewIntervalDays.rounded())) days"
            await refreshRevisions()
        }
    }

    func deleteRevision(_ revision: Revision) async {
        await run {
            try await api.deleteRevision(id: revision.id)
            await refreshRevisions()
        }
    }

    func sendFriendRequest(_ username: String) async {
        await run {
            try await api.sendFriendRequest(username: username)
            statusMessage = "Friend request sent"
            await refreshAll()
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async {
        await run {
            try await api.acceptFriendRequest(request.id)
            await refreshAll()
        }
    }

    func rejectFriendRequest(_ request: FriendRequest) async {
        await run {
            try await api.rejectFriendRequest(request.id)
            await refreshAll()
        }
    }

    func removeFriend(_ friend: Friend) async {
        await run {
            try await api.removeFriend(username: friend.username)
            await refreshFriends()
        }
    }

    func sendFriendStreakRequest(_ username: String) async {
        await run {
            try await api.sendFriendStreakRequest(username: username)
            statusMessage = "Streak request sent"
            await refreshAll()
        }
    }

    func acceptFriendStreakRequest(_ request: FriendStreakRequest) async {
        await run {
            try await api.acceptFriendStreakRequest(request.id)
            await refreshAll()
        }
    }

    func rejectFriendStreakRequest(_ request: FriendStreakRequest) async {
        await run {
            try await api.rejectFriendStreakRequest(request.id)
            await refreshAll()
        }
    }

    func updateProfile(email: String?, timezone: String?, visibility: String?, maxDailyReviews: Int?) async {
        await run {
            user = try await api.updateProfile(email: email, timezone: timezone, visibility: visibility, maxDailyReviews: maxDailyReviews)
        }
    }

    func changePassword(current: String, new: String) async {
        await run {
            try await api.changePassword(current: current, new: new)
            statusMessage = "Password changed"
        }
    }

    func deleteAccount(password: String) async {
        await run {
            try await api.deleteAccount(password: password)
            user = nil
            clearData()
        }
    }

    func purchaseFreezes(count: Int) async {
        await run {
            let result = try await api.purchaseFreezes(count: count)
            statusMessage = result.message
            freezeInfo = try await api.freezeInfo()
            user = try await api.currentUser()
        }
    }

    func giftFreeze(to username: String, count: Int) async {
        await run {
            let result = try await api.giftFreeze(to: username, count: count)
            statusMessage = result.message
            freezeInfo = try await api.freezeInfo()
            user = try await api.currentUser()
        }
    }

    func recalibrateRevisions() async {
        await run {
            let response = try await api.recalibrateMLRevisions()
            statusMessage = "\(response.rescheduled) revisions rescheduled"
            await refreshRevisions()
        }
    }

    func panelStatus(_ panel: PanelKey) -> PanelLoadStatus {
        panelStatuses[panel] ?? .idle
    }

    private func run(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func run(panel: PanelKey, _ operation: () async throws -> Void) async {
        panelStatuses[panel] = .loading
        do {
            try await operation()
            panelStatuses[panel] = .loaded(Date())
            persistCache()
        } catch {
            panelStatuses[panel] = .failed(error.localizedDescription)
        }
    }

    private func restoreCache() {
        guard let cached = cache.load() else { return }
        user = cached.user
        userStats = cached.userStats
        submissionStats = cached.submissionStats
        solveStats = cached.solveStats
        achievementStats = cached.achievementStats
        achievements = cached.achievements
        recentSolves = cached.recentSolves
        allSolves = cached.allSolves
        friends = cached.friends
        receivedRequests = cached.receivedRequests
        sentRequests = cached.sentRequests
        receivedStreakRequests = cached.receivedStreakRequests
        sentStreakRequests = cached.sentStreakRequests
        friendStreaks = cached.friendStreaks
        revisionGroups = cached.revisionGroups
        revisionStats = cached.revisionStats
        revisionAnalytics = cached.revisionAnalytics
        todayRevisions = cached.todayRevisions
        subscriptionStatus = cached.subscriptionStatus
        freezeInfo = cached.freezeInfo
        freezeDates = cached.freezeDates
        lastCacheDate = cached.cachedAt
    }

    private func persistCache() {
        cache.save(LocalAppCache(
            user: user,
            userStats: userStats,
            submissionStats: submissionStats,
            solveStats: solveStats,
            achievementStats: achievementStats,
            achievements: achievements,
            recentSolves: recentSolves,
            allSolves: allSolves,
            friends: friends,
            receivedRequests: receivedRequests,
            sentRequests: sentRequests,
            receivedStreakRequests: receivedStreakRequests,
            sentStreakRequests: sentStreakRequests,
            friendStreaks: friendStreaks,
            revisionGroups: revisionGroups,
            revisionStats: revisionStats,
            revisionAnalytics: revisionAnalytics,
            todayRevisions: todayRevisions,
            subscriptionStatus: subscriptionStatus,
            freezeInfo: freezeInfo,
            freezeDates: freezeDates,
            cachedAt: Date()
        ))
    }

    private func clearData() {
        userStats = nil
        submissionStats = nil
        solveStats = nil
        achievementStats = nil
        achievements = []
        recentSolves = []
        allSolves = []
        revisionGroups = []
        revisionStats = nil
        revisionAnalytics = nil
        todayRevisions = nil
        friends = []
        receivedRequests = []
        sentRequests = []
        receivedStreakRequests = []
        sentStreakRequests = []
        friendStreaks = []
        subscriptionStatus = nil
        freezeInfo = nil
        freezeDates = []
        cache.clear()
    }
}

final class LocalCacheStore {
    private let filename = "traverse-mac-cache.json"

    private var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TraverseMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(filename)
    }

    func load() -> LocalAppCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LocalAppCache.self, from: data)
    }

    func save(_ cache: LocalAppCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
