import SwiftUI

/// The in-app inbox.
///
/// Grouped by recency rather than shown as one flat list. An inbox where a
/// friend request from Tuesday sits between two award rows is hard to scan, and
/// the grouping costs nothing because the rows already arrive newest-first —
/// the sections are just where the day boundaries fall.
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inbox = NotificationInboxManager.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    /// Bucket order is fixed rather than derived from the data, so an empty
    /// "Today" does not push "Yesterday" to the top of the list.
    private let bucketOrder = ["Today", "Yesterday", "This week", "Earlier"]

    /// The inbox without the request types.
    ///
    /// `FRIEND_REQUEST` and `STREAK_REQUEST` no longer belong here. A request now arrives as a
    /// full-screen prompt with Accept and Reject, which is the right surface for the one thing in
    /// this list that actually needs an answer — and leaving a copy in the inbox meant the same
    /// request appeared twice, with the inbox copy unable to do anything about it.
    ///
    /// `FRIEND_ACCEPTED` deliberately stays. It is the outcome of a request *you* sent, so it has
    /// no prompt and no other surface; dropping it would leave you no way to learn it happened.
    ///
    /// Filtering on `knownType` rather than the raw string means an unknown future type still
    /// renders instead of being silently dropped.
    private var visibleNotifications: [AppNotification] {
        inbox.notifications.filter {
            $0.knownType != .friendRequest && $0.knownType != .streakRequest
        }
    }

    private var grouped: [(String, [AppNotification])] {
        let byBucket = Dictionary(grouping: visibleNotifications, by: \.timeBucket)
        return bucketOrder.compactMap { bucket in
            guard let items = byBucket[bucket], !items.isEmpty else { return nil }
            return (bucket, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                // Every branch tests `visibleNotifications`, not the raw inbox. An inbox holding
                // nothing but request rows would otherwise fall through to `list` and render an
                // empty screen instead of the empty state.
                if inbox.isLoading && visibleNotifications.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = inbox.errorMessage, visibleNotifications.isEmpty {
                    errorState(error)
                } else if visibleNotifications.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.black)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if inbox.unreadCount > 0 {
                        Button("Mark all read") {
                            Task { await inbox.markAllRead() }
                        }
                        .font(.footnote)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await inbox.refresh() }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(grouped, id: \.0) { bucket, items in
                    Text(bucket.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(items) { notification in
                            row(notification)

                            if notification.id != items.last?.id {
                                Rectangle()
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }

                if inbox.hasMore {
                    loadMoreTrigger
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await inbox.refresh() }
    }

    /// Loads the next page when it scrolls into view, rather than on a "Load
    /// more" button. The row is deliberately invisible and zero-height-ish: it
    /// is a scroll sentinel, not a piece of UI.
    private var loadMoreTrigger: some View {
        HStack {
            Spacer()
            if inbox.isLoadingMore {
                ProgressView().controlSize(.small)
            } else {
                Color.clear.frame(height: 1)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .onAppear {
            Task { await inbox.loadMore() }
        }
    }

    // MARK: - Row

    private func row(_ notification: AppNotification) -> some View {
        Button {
            Task { await open(notification) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon(for: notification))
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor(for: notification))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(iconColor(for: notification).opacity(0.14))
                        )

                    if !notification.isRead {
                        Circle()
                            .fill(paletteManager.color(at: 0))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notification.title)
                            .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                            .foregroundStyle(notification.isRead ? .white.opacity(0.75) : .white)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 8)

                        Text(notification.relativeTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(notification.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Only shown when the row is a merge. A single event already
                    // reads correctly on its own, so the badge would be noise.
                    if let count = notification.coalescedCount, count > 1 {
                        Text("\(count) in total")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(paletteManager.color(at: 1))
                            .padding(.top, 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func icon(for notification: AppNotification) -> String {
        notification.knownType?.icon ?? "bell"
    }

    /// Unread rows get the accent colour; read rows are muted so the eye lands on
    /// what is new. Awards get a distinct tint because they are the only type
    /// that is purely a reward.
    private func iconColor(for notification: AppNotification) -> Color {
        switch notification.knownType {
        case .awardUnlocked:
            return Color(hex: "FFD93D")
        case .none:
            return .secondary
        default:
            return notification.isRead ? .secondary : paletteManager.color(at: 0)
        }
    }

    // MARK: - Actions

    private func open(_ notification: AppNotification) async {
        await inbox.markRead(notification)

        if let destination = NotificationRouter.destination(for: notification) {
            // Dismiss first so the tab switch is visible rather than hidden
            // behind a sheet that is still animating away.
            dismiss()
            // A short delay lets the sheet finish dismissing before the tab
            // changes; doing both in the same frame makes the transition stutter.
            try? await Task.sleep(nanoseconds: 220_000_000)
            NotificationRouter.route(notification)
            _ = destination
        }
    }

    // MARK: - Empty and error

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Nothing yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Awards, closed rings and announcements will show up here. Friend and streak requests arrive as a full-screen prompt instead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try again") {
                Task { await inbox.refresh() }
            }
            .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NotificationsView()
}
