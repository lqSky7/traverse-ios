//
//  DataManager.swift
//  traverse
//

import Foundation
import Combine

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Friends data
    @Published var friends: [Friend] = []
    @Published var receivedRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    
    // Home data
    @Published var userStats: UserStats?
    @Published var submissionStats: SubmissionStats?
    @Published var solveStats: SolveStats?
    @Published var achievementStats: AchievementStats?
    @Published var recentSolves: [Solve]?
    
    private var hasFetchedInitialData = false
    
    private init() {}
    
    func fetchAllData(username: String) async throws {
        // Fetch all required data in parallel
        async let friendsTask = NetworkService.shared.getFriends()
        async let receivedRequestsTask = NetworkService.shared.getReceivedFriendRequests()
        async let sentRequestsTask = NetworkService.shared.getSentFriendRequests()
        async let userStatsTask = NetworkService.shared.getUserStats(username: username)
        async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
        async let solveStatsTask = NetworkService.shared.getSolveStats()
        async let achievementStatsTask = NetworkService.shared.getAchievementStats()
        async let recentSolvesTask = NetworkService.shared.getSolves(limit: 10)
        
        // Wait for all data to be fetched
        let results = try await (
            friendsTask,
            receivedRequestsTask,
            sentRequestsTask,
            userStatsTask,
            submissionStatsTask,
            solveStatsTask,
            achievementStatsTask,
            recentSolvesTask
        )
        
        // Store all fetched data
        self.friends = results.0
        self.receivedRequests = results.1
        self.sentRequests = results.2
        self.userStats = results.3
        self.submissionStats = results.4
        self.solveStats = results.5
        self.achievementStats = results.6
        self.recentSolves = results.7.solves
        
        hasFetchedInitialData = true
    }
    
    func clearAllData() {
        friends = []
        receivedRequests = []
        sentRequests = []
        userStats = nil
        submissionStats = nil
        solveStats = nil
        achievementStats = nil
        recentSolves = nil
        hasFetchedInitialData = false
    }
    
    var hasData: Bool {
        hasFetchedInitialData
    }
}
