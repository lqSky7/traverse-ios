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

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var statistics: UserStatistics?
    @Published var solves: [UserSolve] = []
    @Published var achievements: [Achievement] = []
    @Published var friendshipStatus: FriendshipStatus = .notFriends
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab = 0
    @Published var displayedSolvesCount = 5
    
    private var allSolves: [UserSolve] = []
    private var hasLoadedSolves = false
    private var hasLoadedAchievements = false
    
    let username: String
    var currentUsername: String?
    
    init(username: String) {
        self.username = username
    }
    
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        // Check if viewing own profile
        if username == currentUsername {
            friendshipStatus = .currentUser
            isLoading = false
            return
        }
        
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
            statistics = UserStatistics(
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
            
            let friends = try await friendsData
            let received = try await receivedRequests
            let sent = try await sentRequests
            
            // Determine friendship status
            if friends.contains(where: { $0.username == username }) {
                friendshipStatus = .friends
            } else if received.contains(where: { $0.requester?.username == username }) {
                friendshipStatus = .requestReceived
            } else if sent.contains(where: { $0.addressee?.username == username }) {
                friendshipStatus = .requestSent
            } else {
                friendshipStatus = .notFriends
            }
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
            await viewModel.loadProfile()
            await viewModel.loadSolves()
            await viewModel.loadAchievements()
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
}

struct ProfileHeaderView: View {
    let profile: UserProfile
    let statistics: UserStatistics?
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ZStack {
            // Blurred profile photo background
            Image("def_user")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 280)
                .clipped()
                .glur(radius: 12.0, offset: 0.2, interpolation: 0.5, direction: .down)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Dark overlay for legibility
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
            
            // Content
            VStack(spacing: 16) {
                Circle()
                    .fill(paletteManager.selectedPalette.primary.gradient)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text(profile.username.prefix(1).uppercased())
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                
                Text(profile.username)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(profile.currentStreak)")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)
                        Label("Streak", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 40)
                        .background(Color.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("\(profile.totalXp)")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)
                        Label("XP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(paletteManager.selectedPalette.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if let stats = statistics {
                        Divider()
                            .frame(height: 40)
                            .background(Color.white.opacity(0.3))
                        
                        VStack(spacing: 4) {
                            Text("\(stats.totalSolves)")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Solves")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                HStack(spacing: 12) {
                    Label(profile.visibility.capitalized, systemImage: profile.visibility == "public" ? "globe" : profile.visibility == "private" ? "lock" : "person.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("Joined \(formatDate(profile.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
        }
        .cornerRadius(16)
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
        VStack(alignment: .leading, spacing: 12) {
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
                ForEach(solves) { solve in
                    SolveCard(solve: solve)
                }
                
                if canLoadMore {
                    Group {
                        Button {
                            onLoadMore()
                        } label: {
                            Text("Load More")
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .tint(paletteManager.selectedPalette.primary)
                    }
                    .applyGlassButtonStyle(.glassProminent)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
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

struct AchievementsListView: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack(spacing: 12) {
            if achievements.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No achievements unlocked")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement)
                }
            }
        }
        .padding()
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

enum ProfileGlassButtonStyle {
    case glass
    case glassProminent
}

#Preview {
    NavigationStack {
        UserProfileView(username: "johndoe")
    }
}
