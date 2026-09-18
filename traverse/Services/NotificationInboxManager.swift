import Foundation
import Combine
import UIKit
import UserNotifications

/// The in-app inbox and the unread badge.
///
/// Distinct from `NotificationManager`, which owns the *local* revision
/// reminders. This one owns everything that arrives from the server. They are
/// separate because they have different failure modes and different lifetimes:
/// local reminders are scheduled by the app and survive offline, server
/// notifications require a session and are meaningless when signed out.
@MainActor
final class NotificationInboxManager: ObservableObject {
    static let shared = NotificationInboxManager()

    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private var nextCursor: Int?
    private var hasLoadedOnce = false
    private var isRefreshing = false

    private init() {}

    var hasMore: Bool { nextCursor != nil }

    // MARK: - Loading

    /// Loads the first page. A no-op when a refresh is already in flight, so
    /// switching tabs quickly cannot stack requests.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if !hasLoadedOnce { isLoading = true }
        defer { isLoading = false }

        do {
            let page = try await NetworkService.shared.getNotifications(limit: 30)
            notifications = page.notifications
            nextCursor = page.nextCursor
            unreadCount = page.unreadCount
            errorMessage = nil
            hasLoadedOnce = true
            await syncBadge()
        } catch {
            // Only surfaced on the first load. A background refresh that fails
            // should leave the list on screen rather than replace it with an
            // error for something the user did not ask for.
            if !hasLoadedOnce {
                errorMessage = error.localizedDescription
            }
            print("[Inbox] refresh failed: \(error.localizedDescription)")
        }
    }

    /// Appends the next page. Keyset paginated, so a notification arriving
    /// mid-scroll cannot shift the boundary and duplicate or skip a row.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await NetworkService.shared.getNotifications(limit: 30, cursor: cursor)
            // Deduplicated on id as a belt-and-braces measure: the cursor should
            // make this impossible, but a duplicate row in a list keyed by id
            // would crash SwiftUI's ForEach rather than merely look wrong.
            let existing = Set(notifications.map(\.id))
            notifications.append(contentsOf: page.notifications.filter { !existing.contains($0.id) })
            nextCursor = page.nextCursor
            unreadCount = page.unreadCount
        } catch {
            print("[Inbox] loadMore failed: \(error.localizedDescription)")
        }
    }

    /// Refreshes just the badge, for the launch and foreground paths where the
    /// full list is not needed.
    func refreshUnreadCount() async {
        do {
            unreadCount = try await NetworkService.shared.getUnreadNotificationCount()
            await syncBadge()
        } catch {
            print("[Inbox] unread count failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Mutating

    /// Marks one read, optimistically.
    ///
    /// The row is updated locally first so the list does not flicker, and the
    /// badge follows immediately. A failure restores both, because a row that
    /// looks read but is still unread would silently reappear on next launch.
    func markRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        let previous = notifications
        let previousUnread = unreadCount

        let stamp = ISO8601DateFormatter().string(from: Date())
        notifications = notifications.map {
            $0.id == notification.id
                ? AppNotification(
                    id: $0.id, type: $0.type, title: $0.title, body: $0.body,
                    link: $0.link, data: $0.data, readAt: stamp,
                    createdAt: $0.createdAt, coalescedCount: $0.coalescedCount
                  )
                : $0
        }
        unreadCount = max(0, unreadCount - 1)
        await syncBadge()

        do {
            try await NetworkService.shared.markNotificationRead(id: notification.id)
        } catch {
            notifications = previous
            unreadCount = previousUnread
            await syncBadge()
            print("[Inbox] markRead failed: \(error.localizedDescription)")
        }
    }

    func markAllRead() async {
        guard unreadCount > 0 else { return }

        let previous = notifications
        let previousUnread = unreadCount

        let stamp = ISO8601DateFormatter().string(from: Date())
        notifications = notifications.map {
            AppNotification(
                id: $0.id, type: $0.type, title: $0.title, body: $0.body,
                link: $0.link, data: $0.data, readAt: $0.readAt ?? stamp,
                createdAt: $0.createdAt, coalescedCount: $0.coalescedCount
            )
        }
        unreadCount = 0
        await syncBadge()

        do {
            try await NetworkService.shared.markAllNotificationsRead()
        } catch {
            notifications = previous
            unreadCount = previousUnread
            await syncBadge()
            print("[Inbox] markAllRead failed: \(error.localizedDescription)")
        }
    }

    /// Drops everything held in memory. Called on sign-out so the next account
    /// does not see the previous user's inbox, and so the badge is cleared.
    func clear() {
        notifications = []
        unreadCount = 0
        nextCursor = nil
        hasLoadedOnce = false
        errorMessage = nil
        Task { await syncBadge() }
    }

    // MARK: - Badge

    /// Mirrors the server's unread count onto the app icon.
    ///
    /// `setBadgeCount` rather than `applicationIconBadgeNumber`: the latter is
    /// deprecated from iOS 17 and, more importantly, requires permission the
    /// user may have declined. `setBadgeCount` fails silently in that case, which
    /// is the correct outcome — a badge is decoration, and a permission error
    /// here should never surface.
    private func syncBadge() async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(unreadCount)
        } catch {
            print("[Inbox] badge update skipped: \(error.localizedDescription)")
        }
    }
}
