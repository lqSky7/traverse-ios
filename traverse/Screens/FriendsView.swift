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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasLoadedFriends = false
    private var hasLoadedRequests = false
    
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
        } catch {
            errorMessage = error.localizedDescription
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
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var showingSearch = false
    @State private var showingRequests = false
    
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
                if viewModel.isLoading {
                    ProgressView()
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
                    HStack(spacing: 20) {
                        Button {
                            showingRequests = true
                        } label: {
                            ZStack {
                                Image(systemName: "person.badge.clock")
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
                await viewModel.loadFriends(force: true)
                await viewModel.loadRequests(force: true)
            }
            .sheet(isPresented: $showingSearch) {
                UserSearchView()
            }
            .sheet(isPresented: $showingRequests) {
                FriendRequestsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadFriends()
                await viewModel.loadRequests()
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                        NavigationLink(value: friend.username) {
                            FriendRow(friend: friend, paletteManager: paletteManager)
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
                        
                        if index < viewModel.friends.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.leading, 66)
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

// MARK: - Leaderboard Section (Clean List Style)
struct LeaderboardSection: View {
    let leaderboard: [Friend]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(paletteManager.color(at: 1))
                    .font(.caption)
                Text("LEADERBOARD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            
            // Clean list
            VStack(spacing: 0) {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, friend in
                    LeaderboardRow(
                        rank: index + 1,
                        friend: friend,
                        paletteManager: paletteManager
                    )
                    
                    if index < leaderboard.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Leaderboard Row (Simple)
struct LeaderboardRow: View {
    let rank: Int
    let friend: Friend
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var rankColor: Color {
        switch rank {
        case 1: return paletteManager.color(at: 1)
        case 2: return paletteManager.color(at: 2)
        case 3: return paletteManager.color(at: 3)
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 24)
            
            // Avatar
            Circle()
                .fill(paletteManager.color(at: rank - 1).gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(friend.username.prefix(1).uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            
            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Friend Row (Compact)
struct FriendRow: View {
    let friend: Friend
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(paletteManager.color(at: 0).gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(friend.username.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
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
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
