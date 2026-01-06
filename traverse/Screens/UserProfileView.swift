//
//  UserProfileView.swift
//  traverse
//

import SwiftUI
import Combine
import Glur

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
}

struct UserProfileView: View {
    let username: String
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    
    init(username: String) {
        self.username = username
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(username: username))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadProfile()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let profile = viewModel.profile {
                    ProfileHeaderView(profile: profile, statistics: viewModel.statistics)
                    
                    // Friend streak section (only for friends) - shown above remove button
                    if viewModel.friendshipStatus == .friends {
                        streakActionSection
                    }
                    
                    friendActionButton
                    
                    if let statistics = viewModel.statistics {
                        StatisticsView(statistics: statistics)
                    }
                    
                    Picker("View", selection: $viewModel.selectedTab) {
                        Text("Solves").tag(0)
                        Text("Achievements").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewModel.selectedTab == 0 {
                        SolvesListView(
                            solves: viewModel.solves,
                            canLoadMore: viewModel.canLoadMoreSolves,
                            onLoadMore: { viewModel.loadMoreSolves() }
                        )
                    } else {
                        AchievementsListView(achievements: viewModel.achievements)
                    }
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load profile first, then load streak status in parallel with other data
            await viewModel.loadProfile()
            async let solvesTask: () = viewModel.loadSolves()
            async let achievementsTask: () = viewModel.loadAchievements()
            async let streakTask: () = viewModel.loadFriendStreakStatus()
            _ = await (solvesTask, achievementsTask, streakTask)
        }
        .refreshable {
            // Force refresh all data on pull-to-refresh
            await viewModel.loadProfile(force: true)
            async let solvesTask: () = viewModel.loadSolves(force: true)
            async let achievementsTask: () = viewModel.loadAchievements(force: true)
            async let streakTask: () = viewModel.loadFriendStreakStatus(force: true)
            _ = await (solvesTask, achievementsTask, streakTask)
        }
        .onChange(of: viewModel.selectedTab) { _, newValue in
            if newValue == 0 && viewModel.solves.isEmpty {
                Task {
                    await viewModel.loadSolves()
                }
            } else if newValue == 1 && viewModel.achievements.isEmpty {
                Task {
                    await viewModel.loadAchievements()
                }
            }
        }
        .onAppear {
            viewModel.currentUsername = authViewModel.currentUser?.username
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private var friendActionButton: some View {
        switch viewModel.friendshipStatus {
        case .currentUser:
            EmptyView()
            
        case .notFriends:
            Group {
                Button {
                    Task {
                        await viewModel.sendFriendRequest()
                    }
                } label: {
                    Text("Send Friend Request")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .tint(paletteManager.selectedPalette.primary)
            }
            .applyGlassButtonStyle(.glassProminent)
            .padding(.horizontal)
            
        case .friends:
            Group {
                Button(role: .destructive) {
                    Task {
                        await viewModel.removeFriend()
                    }
                } label: {
                    Text("Remove Friend")
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
            }
            .applyGlassButtonStyle(.glassProminent)
            .padding(.horizontal)
            
        case .requestSent:
            HStack {
                Image(systemName: "clock")
                Text("Friend Request Sent")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .requestReceived:
            HStack {
                Image(systemName: "envelope.badge")
                Text("Friend Request Received")
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var streakActionSection: some View {
        VStack(spacing: 8) {
            switch viewModel.friendStreakStatus {
            case .none:
                EmptyView()
                
            case .active:
                // Show active streak info with liquid glass and glow
                if let streak = viewModel.friendStreak {
                    ActiveStreakCard(streak: streak, paletteManager: paletteManager, onDelete: {
                        Task {
                            await viewModel.deleteStreak()
                        }
                    })
                    .padding(.horizontal)
                }
                
            case .canStart:
                // Show "Start Streak" button
                Group {
                    Button {
                        Task {
                            await viewModel.sendStreakRequest()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame")
                            Text("Start Streak")
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                    }
                    .tint(paletteManager.color(at: 0))
                }
                .applyGlassButtonStyle(.glassProminent)
                .padding(.horizontal)
                
            case .requestSent:
                HStack {
                    Image(systemName: "flame.badge.checkmark")
                    Text("Streak Request Sent")
                }
                .font(.subheadline)
                .foregroundStyle(paletteManager.color(at: 0))
                .padding()
                .frame(maxWidth: .infinity)
                .background(paletteManager.color(at: 0).opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .requestReceived:
                HStack {
                    Image(systemName: "flame.badge.checkmark")
                    Text("Streak Request Received")
                    Spacer()
                    Text("Check requests")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .foregroundStyle(paletteManager.color(at: 0))
                .padding()
                .frame(maxWidth: .infinity)
                .background(paletteManager.color(at: 0).opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}

struct ProfileHeaderView: View {
    let profile: UserProfile
    let statistics: UserStatistics?
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ZStack {
            // Blurred profile photo background
            GeometryReader { geometry in
                Image("def_user")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: 180)
                    .clipped()
            }
            .frame(height: 180)
            .glur(radius: 12.0, offset: 0.2, interpolation: 0.5, direction: .down)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Dark overlay for legibility
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
            
            // Content
            VStack(spacing: 0) {
                // User Info - Left + Top aligned
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.username)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .opacity(0.8)

                        HStack(spacing: 8) {
                            Label(profile.visibility.capitalized, systemImage: profile.visibility == "public" ? "globe" : profile.visibility == "private" ? "lock" : "person.2")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .opacity(0.75)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 12)

                Spacer()

                // Stats Row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(profile.currentStreak)")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 0))
                        Label("My Streak", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                        .background(Color.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("\(profile.totalXp)")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 1))
                        Label("XP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    if let stats = statistics {
                        Divider()
                            .frame(height: 30)
                            .background(Color.white.opacity(0.3))
                        
                        VStack(spacing: 4) {
                            Text("\(stats.totalSolves)")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Solves")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

struct StatisticsView: View {
    let statistics: UserStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                StatRow(label: "Total Submissions", value: "\(statistics.totalSubmissions)")
                StatRow(label: "Total Streak Days", value: "\(statistics.totalStreakDays)")
                
                Divider()
                
                Text("Problems by Difficulty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    DifficultyBadge(difficulty: "Easy", count: statistics.problemsByDifficulty.easy, color: .green)
                    DifficultyBadge(difficulty: "Medium", count: statistics.problemsByDifficulty.medium, color: .orange)
                    DifficultyBadge(difficulty: "Hard", count: statistics.problemsByDifficulty.hard, color: .red)
                }
            }
            .padding()
            .applyProfileCardBackground()
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: String
    let count: Int
    let color: Color
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var badgeColor: Color {
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 1)
        case "medium": return paletteManager.color(at: 2)
        case "hard": return paletteManager.color(at: 0)
        default: return color
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .bold()
                .foregroundStyle(badgeColor)
            Text(difficulty)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SolvesListView: View {
    let solves: [UserSolve]
    let canLoadMore: Bool
    let onLoadMore: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if solves.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No solves to display")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(solves.enumerated()), id: \.element.id) { index, solve in
                        ProfileSolveRow(solve: solve)
                        if index < solves.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                if canLoadMore {
                    Button {
                        onLoadMore()
                    } label: {
                        Text("Load More")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
        }
        .padding(.vertical)
    }
}

struct SolveCard: View {
    let solve: UserSolve
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(solve.problem.title)
                    .font(.headline)
                
                Spacer()
                
                DifficultyTag(difficulty: solve.problem.difficulty)
            }
            
            HStack(spacing: 12) {
                Label(solve.problem.platform.capitalized, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(solve.xpAwarded) XP", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(paletteManager.selectedPalette.secondary)
                
                if let submission = solve.submission {
                    Label(submission.language, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            
            Text(formatSolveDate(solve.solvedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .applyProfileCardBackground()
        .cornerRadius(12)
    }
    
    private func formatSolveDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return "Solved on \(displayFormatter.string(from: date))"
    }
}

struct DifficultyTag: View {
    let difficulty: String
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var color: Color {
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 1)
        case "medium": return paletteManager.color(at: 2)
        case "hard": return paletteManager.color(at: 0)
        default: return .gray
        }
    }
    
    var body: some View {
        Text(difficulty.capitalized)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(6)
    }
}

// MARK: - Row Components for List Style
struct ProfileSolveRow: View {
    let solve: UserSolve
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(solve.problem.title)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                DifficultyTag(difficulty: solve.problem.difficulty)
            }
            
            HStack(spacing: 12) {
                Label(solve.problem.platform.capitalized, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(solve.xpAwarded) XP", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(paletteManager.selectedPalette.secondary)
                
                Spacer()
                
                Text(formatSolveDate(solve.solvedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func formatSolveDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct ProfileAchievementRow: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve": return "checkmark.circle.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 24))
                .foregroundStyle(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.body)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct AchievementsListView: View {
    let achievements: [Achievement]
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if achievements.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(paletteManager.color(at: 1).opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "trophy")
                            .font(.system(size: 36))
                            .foregroundStyle(paletteManager.color(at: 1))
                    }
                    Text("No achievements unlocked yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Complete challenges to earn achievements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 2-column grid of achievement cards
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(achievements) { achievement in
                        AchievementBadgeCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
                
                // Summary text
                Text("\(achievements.count) achievement\(achievements.count == 1 ? "" : "s") unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Achievement Badge Card (Card Style for Vertical Grid)
struct AchievementBadgeCard: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var glowPhase: CGFloat = 0
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var glowOpacity: Double {
        0.3 + 0.2 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Circular Badge with Glow
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(categoryColor.opacity(glowOpacity), lineWidth: 3)
                    .frame(width: 76, height: 76)
                    .blur(radius: 4)
                
                // Background ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 72, height: 72)
                
                // Inner circle with icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 35
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(categoryColor)
                    .shadow(color: categoryColor.opacity(0.5), radius: 4)
            }
            
            // Achievement Name
            Text(achievement.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Description
            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Unlocked date
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(formatDate(achievement.unlockedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.1), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve": return "checkmark.circle.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 32))
                .foregroundStyle(categoryColor)
                .frame(width: 50, height: 50)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Unlocked \(formatDate(achievement.unlockedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .applyProfileCardBackground()
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - View Extension for Glass Button Styles
extension View {
    @ViewBuilder
    func applyGlassButtonStyle(_ style: ProfileGlassButtonStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .glass:
                self.buttonStyle(.glass)
            case .glassProminent:
                self.buttonStyle(.glassProminent)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    func applyProfileCardBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            self.background(Color(UIColor.systemGray6))
        }
    }
}

// MARK: - Active Streak Card
struct ActiveStreakCard: View {
    let streak: FriendStreak
    @ObservedObject var paletteManager: ColorPaletteManager
    let onDelete: () -> Void
    @State private var glowPhase: CGFloat = 0
    @State private var showDeleteConfirmation = false
    
    private var streakColor: Color {
        paletteManager.color(at: 2) // Use different color from personal streak
    }
    
    private var glowFillOpacity: Double {
        0.15 + 0.1 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Friend Streak column
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(streakColor)
                    Text("\(streak.currentStreak)")
                        .font(.title2)
                        .bold()
                }
                Text("With \(streak.friend.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            // Best streak column
            VStack(spacing: 4) {
                Text("\(streak.longestStreak)")
                    .font(.title2)
                    .bold()
                Text("Best")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.clear, .clear, streakColor.opacity(glowFillOpacity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("End Streak", systemImage: "flame.slash")
            }
        }
        .confirmationDialog(
            "End Streak with \(streak.friend.username)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Streak", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your streak of \(streak.currentStreak) days. This cannot be undone.")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
}

enum ProfileGlassButtonStyle {
    case glass
    case glassProminent
}

#Preview {
    NavigationStack {
        UserProfileView(username: "johndoe")
    }
}
