//
//  DataManager.swift
//  traverse
//

import Foundation
import Combine

extension Notification.Name {
    static let revisionCompleted = Notification.Name("revisionCompleted")
}

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Friends data
    @Published var friends: [Friend] = []
    @Published var receivedRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var receivedStreakRequests: [FriendStreakRequest] = []
    @Published var sentStreakRequests: [FriendStreakRequest] = []
    @Published var friendStreaks: [FriendStreak] = []
    
    // Home data
    @Published var userStats: UserStats?
    @Published var submissionStats: SubmissionStats?
    @Published var solveStats: SolveStats?
    @Published var achievementStats: AchievementStats?
    @Published var recentSolves: [Solve]?
    @Published var todayRevisions: [Revision] = []
    @Published var completedRevisions: [Revision] = []
    @Published var lastFetchTimestamp: Date?
    
    // Revision data
    @Published var revisionGroups: [RevisionGroup] = []
    @Published var revisionStats: RevisionStatsResponse?
    @Published var revisionMode: String = "normal"
    
    private var hasFetchedInitialData = false
    
    var isCacheFresh: Bool {
        guard let timestamp = lastFetchTimestamp else { return false }
        let cacheAge = Date().timeIntervalSince(timestamp)
        return cacheAge < 7200 // 2 hours in seconds
    }
    
    private init() {
        loadPersistedData()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadPersistedData() {
        let decoder = JSONDecoder()
        
        // Load friends data
        if let friendsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("friends.json")),
           let decodedFriends = try? decoder.decode([Friend].self, from: friendsData) {
            self.friends = decodedFriends
        }
        
        if let receivedRequestsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("receivedRequests.json")),
           let decodedRequests = try? decoder.decode([FriendRequest].self, from: receivedRequestsData) {
            self.receivedRequests = decodedRequests
        }
        
        if let sentRequestsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("sentRequests.json")),
           let decodedRequests = try? decoder.decode([FriendRequest].self, from: sentRequestsData) {
            self.sentRequests = decodedRequests
        }
        
        if let receivedStreakRequestsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("receivedStreakRequests.json")),
           let decodedRequests = try? decoder.decode([FriendStreakRequest].self, from: receivedStreakRequestsData) {
            self.receivedStreakRequests = decodedRequests
        }
        
        if let sentStreakRequestsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("sentStreakRequests.json")),
           let decodedRequests = try? decoder.decode([FriendStreakRequest].self, from: sentStreakRequestsData) {
            self.sentStreakRequests = decodedRequests
        }
        
        if let friendStreaksData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("friendStreaks.json")),
           let decodedStreaks = try? decoder.decode([FriendStreak].self, from: friendStreaksData) {
            self.friendStreaks = decodedStreaks
        }
        
        // Load home data
        if let userStatsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("userStats.json")),
           let decodedStats = try? decoder.decode(UserStats.self, from: userStatsData) {
            self.userStats = decodedStats
        }
        
        if let submissionStatsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("submissionStats.json")),
           let decodedStats = try? decoder.decode(SubmissionStats.self, from: submissionStatsData) {
            self.submissionStats = decodedStats
        }
        
        if let solveStatsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("solveStats.json")),
           let decodedStats = try? decoder.decode(SolveStats.self, from: solveStatsData) {
            self.solveStats = decodedStats
        }
        
        if let achievementStatsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("achievementStats.json")),
           let decodedStats = try? decoder.decode(AchievementStats.self, from: achievementStatsData) {
            self.achievementStats = decodedStats
        }
        
        if let recentSolvesData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("recentSolves.json")),
           let decodedSolves = try? decoder.decode([Solve].self, from: recentSolvesData) {
            self.recentSolves = decodedSolves
        }
        
        if let todayRevisionsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("todayRevisions.json")),
           let decodedRevisions = try? decoder.decode([Revision].self, from: todayRevisionsData) {
            self.todayRevisions = decodedRevisions
        }
        
        if let completedRevisionsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("completedRevisions.json")),
           let decodedRevisions = try? decoder.decode([Revision].self, from: completedRevisionsData) {
            self.completedRevisions = decodedRevisions
        }
        
        // Load timestamp
        if let timestampData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("lastFetchTimestamp.json")),
           let decodedTimestamp = try? decoder.decode(Date.self, from: timestampData) {
            self.lastFetchTimestamp = decodedTimestamp
        }
        
        // If we have any data, mark as fetched
        if userStats != nil || submissionStats != nil || solveStats != nil || achievementStats != nil || recentSolves != nil || !todayRevisions.isEmpty || !completedRevisions.isEmpty {
            hasFetchedInitialData = true
        }
        
        // Load revision data
        if let revisionGroupsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("revisionGroups.json")),
           let decodedGroups = try? decoder.decode([RevisionGroup].self, from: revisionGroupsData) {
            self.revisionGroups = decodedGroups
        }
        
        if let revisionStatsData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("revisionStats.json")),
           let decodedStats = try? decoder.decode(RevisionStatsResponse.self, from: revisionStatsData) {
            self.revisionStats = decodedStats
        }
        
        if let revisionModeData = try? Data(contentsOf: getDocumentsDirectory().appendingPathComponent("revisionMode.json")),
           let decodedMode = try? decoder.decode(String.self, from: revisionModeData) {
            self.revisionMode = decodedMode
        }
    }
    
    private func saveData<T: Encodable>(_ data: T, filename: String) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(data)
            try data.write(to: getDocumentsDirectory().appendingPathComponent(filename))
        } catch {
            print("Failed to save \(filename): \(error)")
        }
    }
    
    func persistData() {
        saveData(friends, filename: "friends.json")
        saveData(receivedRequests, filename: "receivedRequests.json")
        saveData(sentRequests, filename: "sentRequests.json")
        saveData(receivedStreakRequests, filename: "receivedStreakRequests.json")
        saveData(sentStreakRequests, filename: "sentStreakRequests.json")
        saveData(friendStreaks, filename: "friendStreaks.json")
        
        if let userStats = userStats {
            saveData(userStats, filename: "userStats.json")
        }
        if let submissionStats = submissionStats {
            saveData(submissionStats, filename: "submissionStats.json")
        }
        if let solveStats = solveStats {
            saveData(solveStats, filename: "solveStats.json")
        }
        if let achievementStats = achievementStats {
            saveData(achievementStats, filename: "achievementStats.json")
        }
        if let recentSolves = recentSolves {
            saveData(recentSolves, filename: "recentSolves.json")
        }
        if let timestamp = lastFetchTimestamp {
            saveData(timestamp, filename: "lastFetchTimestamp.json")
        }
        
        // Save revision data
        saveData(todayRevisions, filename: "todayRevisions.json")
        saveData(completedRevisions, filename: "completedRevisions.json")
        saveData(revisionGroups, filename: "revisionGroups.json")
        if let revisionStats = revisionStats {
            saveData(revisionStats, filename: "revisionStats.json")
        }
        saveData(revisionMode, filename: "revisionMode.json")
    }
    
    func mergeAndPersistSolves(_ fetchedSolves: [Solve]) -> [Solve] {
        var solvesDict = [String: Solve]()
        
        // 1. Load existing ones into dict
        if let current = recentSolves {
            for solve in current {
                let key = "\(solve.problem.platform):\(solve.problem.slug)"
                solvesDict[key] = solve
            }
        }
        
        // 2. Merge new ones (overwriting or adding)
        for solve in fetchedSolves {
            let key = "\(solve.problem.platform):\(solve.problem.slug)"
            solvesDict[key] = solve
        }
        
        // 3. Convert back to array sorted by solvedAt descending
        let merged = solvesDict.values.sorted { s1, s2 in
            s1.solvedAt > s2.solvedAt
        }
        
        self.recentSolves = merged
        saveData(merged, filename: "recentSolves.json")
        return merged
    }
    
    func fetchAllData(username: String) async throws {
        // Fetch all required data in parallel
        async let friendsTask = NetworkService.shared.getFriends()
        async let receivedRequestsTask = NetworkService.shared.getReceivedFriendRequests()
        async let sentRequestsTask = NetworkService.shared.getSentFriendRequests()
        async let userStatsTask = NetworkService.shared.getUserStats(username: username)
        async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
        async let solveStatsTask = NetworkService.shared.getSolveStats()
        async let achievementStatsTask = NetworkService.shared.getAchievementStats()
        async let recentSolvesTask = NetworkService.shared.getSolves(limit: 200)
        let revisionType = self.revisionMode
        async let revisionsTask = NetworkService.shared.getRevisions(upcoming: true, limit: 50, type: revisionType)
        async let completedRevisionsTask = NetworkService.shared.getGroupedRevisions(includeCompleted: true, type: revisionType)
        
        // Wait for all data to be fetched
        let results = try await (
            friendsTask,
            receivedRequestsTask,
            sentRequestsTask,
            userStatsTask,
            submissionStatsTask,
            solveStatsTask,
            achievementStatsTask,
            recentSolvesTask,
            revisionsTask,
            completedRevisionsTask
        )
        
        // Filter for today + overdue only
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todayAndOverdue = results.8.revisions.filter { revision in
            let revisionDate = calendar.startOfDay(for: revision.scheduledDate)
            return revisionDate <= today
        }

        // Extract completed revisions from last 7 days
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let recentCompletedRevisions = results.9.groups.flatMap { $0.revisions }
            .filter { revision in
                guard let completedAtString = revision.completedAt else { return false }
                var completedDate = formatter.date(from: completedAtString)
                if completedDate == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    completedDate = formatter.date(from: completedAtString)
                }
                guard let date = completedDate else { return false }
                return date >= sevenDaysAgo
            }

        // Store all fetched data
        self.friends = results.0
        self.receivedRequests = results.1
        self.sentRequests = results.2
        self.userStats = results.3
        self.submissionStats = results.4
        self.solveStats = results.5
        self.achievementStats = results.6
        self.todayRevisions = todayAndOverdue
        self.completedRevisions = recentCompletedRevisions
        
        // Merge and persist solves to the local cache
        _ = mergeAndPersistSolves(results.7.solves)
        
        hasFetchedInitialData = true
        
        // Update timestamp
        self.lastFetchTimestamp = Date()
        
        // Persist the data (recentSolves already saved in mergeAndPersistSolves)
        persistData()
        
        // Check if user has solved today and end Live Activity if active
        checkSolvedTodayAndEndActivity()
        
        // Asynchronously check for newly unlocked achievements, friend requests, streak requests & gifted freezes
        Task {
            await AchievementToastManager.shared.syncAppOpenUpdates(force: true)
        }
    }
    
    func checkSolvedTodayAndEndActivity() {
        // Check if user solved today based on recent solves
        let calendar = Calendar.current
        let now = Date()
        
        // Create ISO8601 formatter that handles optional fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let recentSolves = recentSolves {
            let solvedToday = recentSolves.contains { solve in
                // Try with fractional seconds first, then without
                var date = formatter.date(from: solve.solvedAt)
                if date == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    date = formatter.date(from: solve.solvedAt)
                }
                
                if let solveDate = date {
                    return calendar.isDate(solveDate, inSameDayAs: now)
                }
                return false
            }
        }
    }
    
    func clearAllData() {
        friends = []
        receivedRequests = []
        sentRequests = []
        receivedStreakRequests = []
        sentStreakRequests = []
        friendStreaks = []
        userStats = nil
        submissionStats = nil
        solveStats = nil
        achievementStats = nil
        recentSolves = nil
        todayRevisions = []
        completedRevisions = []
        revisionGroups = []
        revisionStats = nil
        revisionMode = "normal"
        hasFetchedInitialData = false
    }
    
    
    var hasData: Bool {
        hasFetchedInitialData
    }
}
