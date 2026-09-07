import SwiftUI
import Combine

enum FriendshipStatus {
    case currentUser
    case notFriends
    case friends
    case requestSent
    case requestReceived
}

enum FriendStreakStatus {
    case none           // Not friends or no streak
    case active         // Active streak
    case requestSent    // Streak request pending
    case requestReceived // Received streak request
    case canStart       // Friends but no streak yet
}

@MainActor
class UserProfileViewModel: ObservableObject {
    // Static cache for user profiles
    private static var profileCache: [String: CachedProfile] = [:]
    
    struct CachedProfile {
        let profile: UserProfile
        let statistics: UserStatistics?
        let friendshipStatus: FriendshipStatus
        let timestamp: Date
        
        var isValid: Bool {
            // Cache valid for 5 minutes
            Date().timeIntervalSince(timestamp) < 300
        }
    }
    
    @Published var profile: UserProfile?
    @Published var statistics: UserStatistics?
    @Published var solves: [UserSolve] = []
    @Published var achievements: [Achievement] = []
    @Published var friendshipStatus: FriendshipStatus = .notFriends
    @Published var friendStreakStatus: FriendStreakStatus = .none
    @Published var friendStreak: FriendStreak?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab = 0
    @Published var displayedSolvesCount = 5
    
    private var allSolves: [UserSolve] = []
    private var hasLoadedSolves = false
    private var hasLoadedAchievements = false
    private var hasLoadedStreakStatus = false
    private var hasLoadedProfile = false
    
    let username: String
    var currentUsername: String?
    
    init(username: String) {
        self.username = username
    }
    
    func loadProfile(force: Bool = false) async {
        // Check if viewing own profile
        if username == currentUsername {
            friendshipStatus = .currentUser
            return
        }
        
        // Immediately check DataManager for cached friends list to set initial state
        if !force && DataManager.shared.friends.contains(where: { $0.username == username }) {
            friendshipStatus = .friends
            // If we already know they're a friend, don't show loading
            if let cached = Self.profileCache[username], cached.isValid {
                self.profile = cached.profile
                self.statistics = cached.statistics
                hasLoadedProfile = true
                return
            }
        }
        
        // Use cache if valid and not forcing refresh
        if !force, let cached = Self.profileCache[username], cached.isValid {
            self.profile = cached.profile
            self.statistics = cached.statistics
            self.friendshipStatus = cached.friendshipStatus
            hasLoadedProfile = true
            return
        }
        
        // Only show loading on first load, not refresh
        if !hasLoadedProfile {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            async let profileData = NetworkService.shared.getUserProfile(username: username)
            async let statsData = NetworkService.shared.getUserStatistics(username: username)
            async let friendsData = NetworkService.shared.getFriends()
            async let receivedRequests = NetworkService.shared.getReceivedFriendRequests()
            async let sentRequests = NetworkService.shared.getSentFriendRequests()
            
            let userProfile = try await profileData
            profile = userProfile
            
            let statsResponse = try await statsData
            // Combine profile data (currentStreak, totalXp) with stats data
            let userStats = UserStatistics(
                currentStreak: userProfile.currentStreak,
                totalXp: userProfile.totalXp,
                totalSolves: statsResponse.stats.totalSolves,
                totalSubmissions: statsResponse.stats.totalSubmissions,
                totalStreakDays: statsResponse.stats.totalStreakDays,
                problemsByDifficulty: UserProblemsByDifficulty(
                    easy: statsResponse.stats.problemsByDifficulty.easy,
                    medium: statsResponse.stats.problemsByDifficulty.medium,
                    hard: statsResponse.stats.problemsByDifficulty.hard
                )
            )
            statistics = userStats
            
            let friends = try await friendsData
            let received = try await receivedRequests
            let sent = try await sentRequests
            
            // Determine friendship status
            let status: FriendshipStatus
            if friends.contains(where: { $0.username == username }) {
                status = .friends
            } else if received.contains(where: { $0.requester?.username == username }) {
                status = .requestReceived
            } else if sent.contains(where: { $0.addressee?.username == username }) {
                status = .requestSent
            } else {
                status = .notFriends
            }
            friendshipStatus = status
            
            // Cache the result
            Self.profileCache[username] = CachedProfile(
                profile: userProfile,
                statistics: userStats,
                friendshipStatus: status,
                timestamp: Date()
            )
            hasLoadedProfile = true
        } catch is CancellationError {
            // Ignore - user released pull-to-refresh
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore - request was cancelled
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadSolves(force: Bool = false) async {
        guard !hasLoadedSolves || force else { return }
        
        do {
            let solvesResponse: UserSolvesResponse
            if friendshipStatus == .friends {
                solvesResponse = try await NetworkService.shared.getFriendSolves(username: username)
            } else {
                solvesResponse = try await NetworkService.shared.getUserSolves(username: username)
            }
            allSolves = solvesResponse.solves
            updateDisplayedSolves()
            hasLoadedSolves = true
        } catch {
            // Silently fail for solves if user is private
        }
    }
    
    func updateDisplayedSolves() {
        solves = Array(allSolves.prefix(displayedSolvesCount))
    }
    
    func loadMoreSolves() {
        displayedSolvesCount += 5
        updateDisplayedSolves()
    }
    
    var canLoadMoreSolves: Bool {
        solves.count < allSolves.count
    }
    
    func loadAchievements(force: Bool = false) async {
        guard !hasLoadedAchievements || force else { return }
        
        do {
            let achievementsResponse: AchievementsResponse
            if friendshipStatus == .friends {
                achievementsResponse = try await NetworkService.shared.getFriendAchievements(username: username)
            } else {
                achievementsResponse = try await NetworkService.shared.getUserAchievements(username: username)
            }
            achievements = achievementsResponse.achievements
            hasLoadedAchievements = true
        } catch {
            // Silently fail for achievements if user is private
        }
    }
    
    func sendFriendRequest() async {
        do {
            _ = try await NetworkService.shared.sendFriendRequest(username: username)
            friendshipStatus = .requestSent
            HapticManager.shared.success()
        } catch {
            let errorMsg = error.localizedDescription
            // If the error says "already friends", reload profile to update status
            if errorMsg.lowercased().contains("already friends") {
                await loadProfile()
            }
            errorMessage = errorMsg
            HapticManager.shared.error()
        }
    }
    
    func removeFriend() async {
        do {
            try await NetworkService.shared.removeFriend(username: username)
            friendshipStatus = .notFriends
            friendStreakStatus = .none
            friendStreak = nil
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func loadFriendStreakStatus(force: Bool = false) async {
        guard !hasLoadedStreakStatus || force else { return }
        guard friendshipStatus == .friends else {
            friendStreakStatus = .none
            return
        }
        
        do {
            // Check for active streaks
            let streaks = try await NetworkService.shared.getFriendStreaks()
            if let existingStreak = streaks.first(where: { $0.friend.username == username }) {
                friendStreak = existingStreak
                friendStreakStatus = .active
                hasLoadedStreakStatus = true
                return
            }
            
            // Check for pending streak requests
            async let sentRequests = NetworkService.shared.getSentFriendStreakRequests()
            async let receivedRequests = NetworkService.shared.getReceivedFriendStreakRequests()
            
            let sent = try await sentRequests
            let received = try await receivedRequests
            
            if sent.contains(where: { $0.requested?.username == username }) {
                friendStreakStatus = .requestSent
            } else if received.contains(where: { $0.requester?.username == username }) {
                friendStreakStatus = .requestReceived
            } else {
                friendStreakStatus = .canStart
            }
            
            hasLoadedStreakStatus = true
        } catch {
            // Silently fail - not critical
            print("Failed to load friend streak status: \(error)")
            friendStreakStatus = .canStart
        }
    }
    
    func sendStreakRequest() async {
        do {
            _ = try await NetworkService.shared.sendFriendStreakRequest(username: username)
            friendStreakStatus = .requestSent
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func deleteStreak() async {
        do {
            try await NetworkService.shared.deleteFriendStreak(username: username)
            friendStreak = nil
            friendStreakStatus = .canStart
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func giftFreeze() async -> Bool {
        do {
            _ = try await NetworkService.shared.giftFreeze(toUsername: username)
            HapticManager.shared.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
            return false
        }
    }
}

