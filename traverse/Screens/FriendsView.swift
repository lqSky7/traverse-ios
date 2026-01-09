//
//  FriendsView.swift
//  traverse
//

import SwiftUI
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var receivedRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var friendStreaks: [FriendStreak] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasLoadedFriends = false
    private var hasLoadedRequests = false
    private var hasLoadedStreaks = false
    
    /// Get the friend streak for a specific friend by username
    func getStreakForFriend(_ username: String) -> FriendStreak? {
        friendStreaks.first { $0.friend.username == username }
    }
    
    func loadFriends(force: Bool = false) async {
        // Use cached data from DataManager if available and not forcing refresh
        if !force && DataManager.shared.hasData {
            friends = DataManager.shared.friends
            hasLoadedFriends = true
            return
        }
        
        guard !hasLoadedFriends || force else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            friends = try await NetworkService.shared.getFriends()
            DataManager.shared.friends = friends
            hasLoadedFriends = true
        } catch is CancellationError {
            // Ignore - user released pull-to-refresh
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore - request was cancelled
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadRequests(force: Bool = false) async {
        // Use cached data from DataManager if available and not forcing refresh
        if !force && DataManager.shared.hasData {
            receivedRequests = DataManager.shared.receivedRequests
            sentRequests = DataManager.shared.sentRequests
            hasLoadedRequests = true
            return
        }
        
        guard !hasLoadedRequests || force else { return }
        
        do {
            async let received = NetworkService.shared.getReceivedFriendRequests()
            async let sent = NetworkService.shared.getSentFriendRequests()
            
            receivedRequests = try await received
            sentRequests = try await sent
            
            DataManager.shared.receivedRequests = receivedRequests
            DataManager.shared.sentRequests = sentRequests
            
            hasLoadedRequests = true
        } catch is CancellationError {
            // Ignore - user released pull-to-refresh
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore - request was cancelled
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadFriendStreaks(force: Bool = false) async {
        // Use cached data from DataManager if available and not forcing refresh
        if !force && !DataManager.shared.friendStreaks.isEmpty {
            friendStreaks = DataManager.shared.friendStreaks
            hasLoadedStreaks = true
            print("[FriendsViewModel] Loaded \(friendStreaks.count) friend streaks from cache")
            return
        }
        
        guard !hasLoadedStreaks || force else { 
            print("[FriendsViewModel] Skipping streak load - already loaded")
            return 
        }
        
        do {
            friendStreaks = try await NetworkService.shared.getFriendStreaks()
            DataManager.shared.friendStreaks = friendStreaks
            DataManager.shared.persistData()
            hasLoadedStreaks = true
            print("[FriendsViewModel] Loaded \(friendStreaks.count) friend streaks from network")
            for streak in friendStreaks {
                print("[FriendsViewModel] Streak with \(streak.friend.username): current=\(streak.currentStreak)")
            }
        } catch {
            // Silently fail for friend streaks - not critical
            print("[FriendsViewModel] Failed to load friend streaks: \(error)")
        }
    }
    
    func acceptRequest(_ request: FriendRequest) async {
        do {
            _ = try await NetworkService.shared.acceptFriendRequest(requestId: request.id)
            await loadRequests(force: true)
            await loadFriends(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func rejectRequest(_ request: FriendRequest) async {
        do {
            try await NetworkService.shared.rejectFriendRequest(requestId: request.id)
            await loadRequests(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await NetworkService.shared.cancelFriendRequest(requestId: request.id)
            await loadRequests(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func removeFriend(_ friend: Friend) async {
        do {
            try await NetworkService.shared.removeFriend(username: friend.username)
            await loadFriends(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
}

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @StateObject private var streakRequestsViewModel = FriendStreakRequestsViewModel()
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var showingSearch = false
    @State private var showingRequests = false
    @State private var showingStreakRequests = false
    
    // Leaderboard: Top 3 by weighted score (streak has more weight)
    private var leaderboard: [Friend] {
        viewModel.friends
            .sorted { friend1, friend2 in
                let score1 = friend1.currentStreak * 10 + friend1.totalXp / 100
                let score2 = friend2.currentStreak * 10 + friend2.totalXp / 100
                return score1 > score2
            }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadFriends()
                                await viewModel.loadRequests()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if viewModel.friends.isEmpty {
                    EmptyFriendsView()
                } else {
                    friendsList
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingStreakRequests = true
                        } label: {
                            ZStack {
                                Image(systemName: "flame.circle")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(paletteManager.color(at: 0))
                                if !streakRequestsViewModel.receivedRequests.isEmpty {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        Button {
                            showingRequests = true
                        } label: {
                            ZStack {
                                Image(systemName: "person.crop.circle.badge.clock")
                                    .frame(width: 24, height: 24)
                                if !viewModel.receivedRequests.isEmpty {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
            .refreshable {
                // Use Task to prevent early cancellation from pull-to-refresh gesture
                await Task {
                    await viewModel.loadFriends(force: true)
                    await viewModel.loadRequests(force: true)
                    await viewModel.loadFriendStreaks(force: true)
                }.value
            }
            .sheet(isPresented: $showingSearch) {
                UserSearchView()
            }
            .sheet(isPresented: $showingRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingStreakRequests) {
                FriendStreakRequestsView(viewModel: streakRequestsViewModel)
            }
            .task {
                // Load friends and streaks in parallel for faster display
                async let friendsTask: () = viewModel.loadFriends()
                async let streaksTask: () = viewModel.loadFriendStreaks()
                async let requestsTask: () = viewModel.loadRequests()
                async let streakRequestsTask: () = streakRequestsViewModel.loadRequests()
                _ = await (friendsTask, streaksTask, requestsTask, streakRequestsTask)
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
    }
    
    private var friendsList: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Leaderboard Section
                if !leaderboard.isEmpty {
                    LeaderboardSection(leaderboard: leaderboard, paletteManager: paletteManager)
                }
                
                // All Friends Section Header
                HStack {
                    Text("ALL FRIENDS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.friends.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(paletteManager.color(at: 3))
                }
                .padding(.horizontal, 4)
                
                // Friends List
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                        NavigationLink(value: friend.username) {
                            FriendRow(
                                friend: friend,
                                paletteManager: paletteManager,
                                friendStreak: viewModel.getStreakForFriend(friend.username)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.removeFriend(friend)
                                }
                            } label: {
                                Label("Remove Friend", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationDestination(for: String.self) { username in
            UserProfileView(username: username)
        }
    }
}

// MARK: - Leaderboard (Elegant Gradient Design)
struct LeaderboardSection: View {
    let leaderboard: [Friend]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(spacing: 0) {
            if leaderboard.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Add friends to see the leaderboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(20)
            } else {
                // Elegant gradient leaderboard card
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    paletteManager.color(at: 0).opacity(0.4),
                                    paletteManager.color(at: 1).opacity(0.3),
                                    paletteManager.color(at: 2).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Content
                    VStack(spacing: 12) {
                        // Header
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("LEADERBOARD")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                        }
                        
                        // Divider after header
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(height: 1)
                        
                        // Top 3 Names
                        VStack(spacing: 0) {
                            ForEach(Array(leaderboard.prefix(3).enumerated()), id: \.element.id) { index, friend in
                                LeaderboardNameRow(
                                    rank: index + 1,
                                    friend: friend,
                                    paletteManager: paletteManager
                                )
                                
                                // Separator between rows (not after last)
                                if index < min(leaderboard.count, 3) - 1 {
                                    Rectangle()
                                        .fill(.white.opacity(0.08))
                                        .frame(height: 1)
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - Leaderboard Name Row
struct LeaderboardNameRow: View {
    let rank: Int
    let friend: Friend
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "circle.fill"
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.8) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Rank Icon
            Image(systemName: rankIcon)
                .font(.system(size: rank == 1 ? 20 : 18))
                .foregroundStyle(rankColor)
                .frame(width: 32, height: 32)
            
            // Name (normal font, not serif)
            Text(friend.username)
                .font(.system(size: rank == 1 ? 22 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            // XP (aligned to baseline with name)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(friend.totalXp)")
                    .font(.system(size: rank == 1 ? 20 : 16, weight: .bold))
                    .foregroundStyle(rankColor)
                Text("XP")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 10)
        .opacity(rank == 1 ? 1.0 : (rank == 2 ? 0.9 : 0.8))
    }
}

// MARK: - Friend Row (Compact)
struct FriendRow: View {
    let friend: Friend
    @ObservedObject var paletteManager: ColorPaletteManager
    var friendStreak: FriendStreak?
    @State private var glowPhase: CGFloat = 0
    
    private var hasActiveStreak: Bool {
        // Show glow when friend streak exists (even if 0 days)
        return friendStreak != nil
    }
    
    private var streakColor: Color {
        paletteManager.color(at: 0)
    }
    
    private var glowFillOpacity: Double {
        guard hasActiveStreak else { return 0 }
        return 0.15 + 0.1 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    private var glowStrokeOpacity: Double {
        guard hasActiveStreak else { return 0 }
        return 0.4 + 0.2 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(paletteManager.color(at: 2).gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(friend.username.prefix(1).uppercased())
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(paletteManager.color(at: 0))
                        Text("\(friend.currentStreak)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(paletteManager.color(at: 1))
                        Text("\(friend.totalXp)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .padding(.trailing, 40) // Always have space for text on right
        .background(Color(UIColor.systemGray6))
        .overlay(alignment: .trailing) {
            // Oversized streak number or "Start Streak!" text
            if let streak = friendStreak {
                Text("\(streak.currentStreak)")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(streakColor.opacity(0.25))
                    .offset(x: 10, y: 0)
            } else {
                Text("Start!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(paletteManager.color(at: 0).opacity(0.3))
                    .offset(x: -8, y: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            Group {
                if hasActiveStreak {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .clear, streakColor.opacity(glowFillOpacity)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        )
        .onAppear {
            if hasActiveStreak {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPhase = .pi * 2
                }
            }
        }
    }
}

struct FriendCard: View {
    let friend: Friend
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(paletteManager.selectedPalette.primary.gradient)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(friend.username.prefix(1).uppercased())
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(friend.visibility.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            HStack(spacing: 0) {
                FriendStatItem(
                    title: "Streak",
                    value: "\(friend.currentStreak)",
                    icon: "flame.fill",
                    color: paletteManager.selectedPalette.secondary
                )
                
                Divider()
                    .frame(height: 60)
                
                FriendStatItem(
                    title: "Total XP",
                    value: "\(friend.totalXp)",
                    icon: "star.fill",
                    color: paletteManager.selectedPalette.primary
                )
            }
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct FriendStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.title2)
                    .bold()
                
                Text("Search for users and send friend requests to start building your network")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }
}

#Preview {
    FriendsView()
}
