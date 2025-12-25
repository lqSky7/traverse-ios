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
        
        // If we have any data, mark as fetched
        if userStats != nil || submissionStats != nil || solveStats != nil || achievementStats != nil || recentSolves != nil {
            hasFetchedInitialData = true
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
        
        // Persist the data
        persistData()
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
