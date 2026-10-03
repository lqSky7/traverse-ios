//
//  RequestsView.swift
//  traverse
//
//  One screen for every request, in and out.
//

import SwiftUI

/// A friend request or a friend-streak request, in one list.
///
/// These used to live on two separate screens, each carrying its own Received/Sent split — four
/// lists for one idea, reachable from two near-identical toolbar icons. They share an envelope here
/// so a single Received tab can hold both, while the existing row views still do the rendering.
///
/// Kept as an enum rather than a struct with optional fields so the compiler forces every call site
/// to handle both kinds — the two carry genuinely different actions (a friend request can only be
/// accepted or declined; a streak request can also be cancelled once sent).
enum RequestItem: Identifiable {
    case friend(FriendRequest)
    case streak(FriendStreakRequest)

    var id: String {
        switch self {
        case .friend(let request): return "friend-\(request.id)"
        case .streak(let request): return "streak-\(request.id)"
        }
    }
}

struct RequestsView: View {
    @ObservedObject var friendsViewModel: FriendsViewModel
    @ObservedObject var streakViewModel: FriendStreakRequestsViewModel
    @ObservedObject var paletteManager: ColorPaletteManager
    @Environment(\.dismiss) private var dismiss

    @State private var tab = 0

    private var received: [RequestItem] {
        friendsViewModel.receivedRequests.map(RequestItem.friend)
            + streakViewModel.receivedRequests.map(RequestItem.streak)
    }

    private var sent: [RequestItem] {
        friendsViewModel.sentRequests.map(RequestItem.friend)
            + streakViewModel.sentRequests.map(RequestItem.streak)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Requests", selection: $tab) {
                    Text("Received (\(received.count))").tag(0)
                    Text("Sent (\(sent.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                if tab == 0 {
                    list(items: received, isReceived: true)
                } else {
                    list(items: sent, isReceived: false)
                }
            }
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Both sources, in parallel. Neither is a precondition for the other, and the two
                // used to be loaded by whichever screen happened to be open.
                async let friends: () = friendsViewModel.loadRequests()
                async let streaks: () = streakViewModel.loadRequests()
                _ = await (friends, streaks)
            }
        }
    }

    @ViewBuilder
    private func list(items: [RequestItem], isReceived: Bool) -> some View {
        if items.isEmpty {
            EmptyStateView(
                icon: isReceived ? "tray" : "paperplane",
                title: isReceived ? "No received requests" : "No sent requests",
                message: isReceived
                    ? "Friend requests and friend-streak invites land here. You will get a full-screen prompt when one arrives."
                    : "Requests you send show up here until they are accepted or declined."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // Grouped by kind rather than interleaved by date. The two rows look different and
                // ask for different things, and a mixed list made it hard to see at a glance
                // whether anything actually needed an answer.
                let friendItems = items.filter { if case .friend = $0 { return true } else { return false } }
                let streakItems = items.filter { if case .streak = $0 { return true } else { return false } }

                if !friendItems.isEmpty {
                    Section("Friend requests") {
                        ForEach(friendItems) { item in row(item, isReceived: isReceived) }
                    }
                }

                if !streakItems.isEmpty {
                    Section("Streak requests") {
                        ForEach(streakItems) { item in row(item, isReceived: isReceived) }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func row(_ item: RequestItem, isReceived: Bool) -> some View {
        switch item {
        case .friend(let request):
            if isReceived, let requester = request.requester {
                ReceivedRequestRow(request: request, requester: requester, viewModel: friendsViewModel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if let addressee = request.addressee {
                SentRequestRow(request: request, addressee: addressee, viewModel: friendsViewModel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

        case .streak(let request):
            if isReceived {
                ReceivedStreakRequestRow(
                    request: request,
                    onAccept: { Task { await streakViewModel.acceptRequest(request) } },
                    onReject: { Task { await streakViewModel.rejectRequest(request) } }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                SentStreakRequestRow(
                    request: request,
                    onCancel: { Task { await streakViewModel.cancelRequest(request) } }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
}

#Preview {
    RequestsView(
        friendsViewModel: FriendsViewModel(),
        streakViewModel: FriendStreakRequestsViewModel(),
        paletteManager: ColorPaletteManager.shared
    )
    .preferredColorScheme(.dark)
}
