import SwiftUI
import Combine

enum FriendshipStatus {
    case currentUser
    case notFriends
    case friends
    case requestSent
    case requestReceived
    case blocked
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
    /// The server's authoritative relationship state. Everything the UI needs to
    /// decide which action to offer is derived from this, never inferred locally.
    @Published var relationship: RelationshipState?
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
            // One call answers the relationship question. The previous version
            // fetched the friends list plus both request lists and cross-referenced
            // them here, which meant three payloads that grow with the graph to
            // render a single button — and a stale-cache window in between.
            async let relationshipData = NetworkService.shared.getRelationship(username: username)

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

            let state = try await relationshipData
            applyRelationship(state)

            // Cache the result
            Self.profileCache[username] = CachedProfile(
                profile: userProfile,
                statistics: userStats,
                friendshipStatus: friendshipStatus,
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

    /// Maps the server's relationship status onto the view's presentation state.
    ///
    /// The streak sub-state comes from the same payload, so a 0-day streak is no
    /// longer rendered as an active one and "at risk" is known up front.
    func applyRelationship(_ state: RelationshipState) {
        relationship = state

        switch state.status {
        case "self":
            friendshipStatus = .currentUser
        case "friends":
            friendshipStatus = .friends
        case "pending_outgoing":
            friendshipStatus = .requestSent
        case "pending_incoming":
            friendshipStatus = .requestReceived
        case "blocked":
            friendshipStatus = .blocked
        default:
            friendshipStatus = .notFriends
        }

        guard let streak = state.streak else {
            friendStreakStatus = .none
            friendStreak = nil
            return
        }

        friendStreakStatus = streak.currentStreak > 0 ? .active : .canStart
    }

    /// Re-reads the relationship from the server. Used after any action that could
    /// change it, so the UI reflects the server's truth rather than a guess.
    func refreshRelationship() async {
        do {
            let state = try await NetworkService.shared.getRelationship(username: username)
            applyRelationship(state)
        } catch {
            // Leave the previous state in place; the action itself already
            // reported its own outcome.
            print("Failed to refresh relationship: \(error)")
        }
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
            // The server may have sent a request, returned an idempotent
            // "already requested", or auto-accepted because they had already
            // asked us. Rather than guess which, re-read the authoritative state.
            await refreshRelationship()
            HapticManager.shared.success()
        } catch {
            // No error-string matching. The previous implementation did
            // `errorMsg.lowercased().contains("already friends")` to recover state
            // the server had never told it; the relationship endpoint now simply
            // reports it.
            errorMessage = error.localizedDescription
            await refreshRelationship()
            HapticManager.shared.error()
        }
    }

    func removeFriend() async {
        do {
            try await NetworkService.shared.removeFriend(username: username)
            friendStreak = nil
            await refreshRelationship()
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    func blockUser() async {
        do {
            try await NetworkService.shared.blockUser(username: username)
            friendStreak = nil
            await refreshRelationship()
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    func unblockUser() async {
        do {
            try await NetworkService.shared.unblockUser(username: username)
            await refreshRelationship()
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    func toggleFavorite() async {
        guard let state = relationship, state.isFriends else { return }
        let next = !(state.friendship?.favorite ?? false)
        do {
            try await NetworkService.shared.setFriendFavorite(username: username, favorite: next)
            await refreshRelationship()
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

