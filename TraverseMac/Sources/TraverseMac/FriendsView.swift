import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    @State private var query = ""
    @State private var searchResults: [UserBasic] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchCard
                HStack(alignment: .top, spacing: 14) {
                    requestsCard
                    streakRequestsCard
                }
                friendsCard
                streaksCard
            }
            .padding(24)
        }
        .navigationTitle("Friends")
        .task {
            if appState.friends.isEmpty {
                await appState.refreshFriends()
            }
        }
    }

    private var header: some View {
        ThemedCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Friends")
                        .font(.largeTitle.weight(.bold))
                    Text("Search users, manage requests, open profiles, and keep shared streaks moving.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await appState.refreshFriends() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var searchCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search Users").font(.headline)
                HStack {
                    TextField("Username", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(search)
                    Button("Search", action: search)
                }
                if searchResults.isEmpty {
                    Text("Search by username to add friends or start streaks.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(searchResults) { user in
                        HStack {
                            NavigationLink {
                                UserProfileDetailView(username: user.username)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(user.username).font(.headline)
                                    Text("\(user.currentStreak) streak • \(user.totalXp) XP")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("Add") {
                                Task { await appState.sendFriendRequest(user.username) }
                            }
                            Button("Streak") {
                                Task { await appState.sendFriendStreakRequest(user.username) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var requestsCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Friend Requests")
                    .font(.title3.weight(.bold))
                RequestSection(title: "Received", requests: appState.receivedRequests, user: { $0.requester }, incoming: true)
                Divider()
                RequestSection(title: "Sent", requests: appState.sentRequests, user: { $0.addressee }, incoming: false)
            }
        }
    }

    private var streakRequestsCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Streak Requests")
                    .font(.title3.weight(.bold))
                FriendStreakRequestSection(title: "Received", requests: appState.receivedStreakRequests, incoming: true)
                Divider()
                FriendStreakRequestSection(title: "Sent", requests: appState.sentStreakRequests, incoming: false)
            }
        }
    }

    private var friendsCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Friend Leaderboard").font(.title3.weight(.bold))
                if appState.friends.isEmpty {
                    PanelFeedback(status: appState.panelStatus(.friends), isEmpty: true, emptyTitle: "No friends yet", emptySystemImage: "person.2", emptyDescription: "Search for a username to send a friend request.")
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            Text("Rank").foregroundStyle(.secondary)
                            Text("Friend").foregroundStyle(.secondary)
                            Text("Streak").foregroundStyle(.secondary)
                            Text("XP").foregroundStyle(.secondary)
                            Text("")
                        }
                        Divider()
                        ForEach(Array(appState.friends.sorted { $0.totalXp > $1.totalXp }.enumerated()), id: \.element.id) { index, friend in
                            GridRow {
                                Text("#\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(rankColor(index + 1))
                                NavigationLink(friend.username) {
                                    UserProfileDetailView(username: friend.username)
                                }
                                .buttonStyle(.plain)
                                Text("\(friend.currentStreak)")
                                    .monospacedDigit()
                                Text("\(friend.totalXp)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(paletteManager.selectedPalette.primary)
                                Button(role: .destructive) {
                                    Task { await appState.removeFriend(friend) }
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                                .labelStyle(.iconOnly)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var streaksCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Streaks").font(.title3.weight(.bold))
                if appState.friendStreaks.isEmpty {
                    PanelFeedback(status: appState.panelStatus(.friends), isEmpty: true, emptyTitle: "No active friend streaks", emptySystemImage: "flame", emptyDescription: "Start a streak from search results.")
                } else {
                    ForEach(appState.friendStreaks) { streak in
                        HStack {
                            NavigationLink(streak.friend.username) {
                                UserProfileDetailView(username: streak.friend.username)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text("Longest \(streak.longestStreak)")
                                .foregroundStyle(.secondary)
                            Text("\(streak.currentStreak)")
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: .yellow
        case 2: .gray
        case 3: .orange
        default: .secondary
        }
    }

    private func search() {
        Task {
            do {
                searchResults = try await APIClient.shared.searchUsers(query).users
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }
}

struct RequestSection: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    let requests: [FriendRequest]
    let user: (FriendRequest) -> UserBasic?
    let incoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if requests.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requests) { request in
                    HStack {
                        if let username = user(request)?.username {
                            NavigationLink(username) {
                                UserProfileDetailView(username: username)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Unknown")
                        }
                        Spacer()
                        if incoming {
                            Button("Accept") { Task { await appState.acceptFriendRequest(request) } }
                            Button("Reject") { Task { await appState.rejectFriendRequest(request) } }
                        } else {
                            Text(request.status.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct FriendStreakRequestSection: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    let requests: [FriendStreakRequest]
    let incoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if requests.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requests) { request in
                    HStack {
                        let username = (incoming ? request.requester : request.requested)?.username ?? "Unknown"
                        NavigationLink(username) {
                            UserProfileDetailView(username: username)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if incoming {
                            Button("Accept") { Task { await appState.acceptFriendStreakRequest(request) } }
                            Button("Reject") { Task { await appState.rejectFriendStreakRequest(request) } }
                        } else {
                            Text(request.status.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
