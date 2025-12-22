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
    @State private var showingSearch = false
    @State private var showingRequests = false
    
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
        }
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.friends) { friend in
                    NavigationLink(value: friend.username) {
                        FriendCard(friend: friend)
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
            .padding()
        }
        .navigationDestination(for: String.self) { username in
            UserProfileView(username: username)
        }
    }
}

struct FriendCard: View {
    let friend: Friend
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(.blue.gradient)
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
                    color: .orange
                )
                
                Divider()
                    .frame(height: 60)
                
                FriendStatItem(
                    title: "Total XP",
                    value: "\(friend.totalXp)",
                    icon: "star.fill",
                    color: .yellow
                )
            }
            .padding()
        }
        .background(.ultraThinMaterial)
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
