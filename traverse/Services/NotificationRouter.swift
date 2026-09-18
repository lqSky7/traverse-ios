import Foundation
import SwiftUI

/// Where a tapped notification should take the user.
///
/// Resolution lives here rather than in the inbox view because the same mapping
/// is needed from two directions: tapping a row in the inbox, and tapping a push
/// banner when the app was not running. The push path goes through
/// `NotificationManager`'s delegate, which has no view to ask.
///
/// The server's `link` is treated as a hint, not an instruction. The server knows
/// what happened; only the client knows which tab that corresponds to in this
/// build. A `link` the client does not recognise falls through to the type-based
/// mapping, so adding a type server-side degrades to a sensible tab instead of
/// doing nothing.
enum NotificationRouter {

    /// Tab indices, mirrored from `MainTabView`'s `MainTab`. Duplicated as plain
    /// ints because `MainTab` is private to that file and making it public to
    /// serve one mapping would expose the whole tab layout.
    enum Destination: Equatable {
        case home
        case problems
        case revisions
        case friends

        var tabIndex: Int {
            switch self {
            case .home: return 0
            case .problems: return 1
            case .revisions: return 2
            case .friends: return 3
            }
        }
    }

    static func destination(for notification: AppNotification) -> Destination? {
        if let fromLink = destination(forLink: notification.link) {
            return fromLink
        }
        return destination(forType: notification.type)
    }

    static func destination(forLink link: String?) -> Destination? {
        guard let link, !link.isEmpty else { return nil }

        // Links arrive as server-relative paths (`/friends`) or as the app's own
        // scheme (`traverse://friends`). Normalising to a path keeps one switch
        // for both.
        let path: String = {
            if link.hasPrefix("traverse://"), let url = URL(string: link) {
                return "/" + (url.host ?? "")
            }
            return link
        }()

        if path.hasPrefix("/friends") || path.hasPrefix("/friend-requests") { return .friends }
        if path.hasPrefix("/revisions") { return .revisions }
        if path.hasPrefix("/problems") { return .problems }
        if path.hasPrefix("/home") || path.hasPrefix("/rings") { return .home }
        return nil
    }

    static func destination(forType type: String) -> Destination? {
        switch NotificationType(rawValue: type) {
        case .friendRequest, .friendAccepted, .streakRequest, .friendRingsClosed:
            return .friends
        case .ringsClosed:
            return .home
        case .awardUnlocked:
            // Awards live on the home feed's achievements card.
            return .home
        case .streakFreezeReceived:
            return .home
        case .announcement:
            // A broadcast has no natural home; the inbox row is the message, so
            // there is nothing to navigate to.
            return nil
        case .none:
            return nil
        }
    }

    /// Switches tab and hands over any payload the destination needs.
    ///
    /// Posted on `NotificationCenter` rather than driven through a binding
    /// because the push delegate runs outside the view tree.
    @MainActor
    static func route(_ notification: AppNotification) {
        guard let destination = destination(for: notification) else { return }

        var userInfo: [String: Any] = ["tab": destination.tabIndex]

        // A friend-related notification names the other user, so the friends tab
        // can open straight onto their profile instead of the list.
        if let username = notification.data?["username"], !username.isEmpty {
            userInfo["username"] = username
        }

        NotificationCenter.default.post(
            name: .notificationDeepLink,
            object: nil,
            userInfo: userInfo
        )
    }
}

extension Notification.Name {
    /// Carries `["tab": Int]` and optionally `["username": String]`.
    static let notificationDeepLink = Notification.Name("notificationDeepLink")
}

// MARK: - Display helpers

extension AppNotification {
    var createdDate: Date? { ActivityTimestamp.date(from: createdAt) }

    /// "3m ago", "Yesterday", "12 Sep".
    ///
    /// `RelativeDateTimeFormatter` handles the recent end well but produces
    /// "2 weeks ago" for anything older, which is less useful in an inbox than
    /// the date itself — so the older buckets are formatted explicitly.
    var relativeTime: String {
        guard let date = createdDate else { return "" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        }

        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 7 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? "d MMM"
            : "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Section bucket for the inbox list.
    var timeBucket: String {
        guard let date = createdDate else { return "Earlier" }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days < 7 ? "This week" : "Earlier"
    }
}
