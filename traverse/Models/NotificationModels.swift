import Foundation

/// One row in the in-app inbox.
///
/// This mirrors the server's `Notification` table. `type` is a stable machine
/// string (`FRIEND_REQUEST`, `AWARD_UNLOCKED`, ...) and drives both the icon and
/// the deep link; `link` is the server's suggested destination, which the client
/// may override for types it understands better than the server does.
struct AppNotification: Codable, Identifiable, Equatable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let link: String?
    let data: [String: String]?
    let readAt: String?
    let createdAt: String

    /// How many events were folded into this row.
    ///
    /// The server coalesces a burst — one accepted submission can trip several
    /// award thresholds at once — into a single row. Without this the row reads
    /// as if only the newest event happened, which understates what was earned.
    let coalescedCount: Int?

    var isRead: Bool { readAt != nil }

    /// The type as an enum, when it is one this build knows about. Unknown types
    /// still render — they just fall back to a generic icon — so a server that
    /// adds a type does not produce blank rows on older clients.
    var knownType: NotificationType? { NotificationType(rawValue: type) }

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, link, data, readAt, createdAt, coalescedCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "UNKNOWN"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link)
        readAt = try c.decodeIfPresent(String.self, forKey: .readAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        coalescedCount = try c.decodeIfPresent(Int.self, forKey: .coalescedCount)

        // `data` is free-form on the server: it carries scalars like
        // `broadcastId` *and* a nested `items` array from the coalescer. A plain
        // [String: String] decode would throw on the array and lose the whole
        // payload, so non-scalars are absorbed rather than allowed to fail.
        if let raw = try? c.decode([String: JSONScalar].self, forKey: .data) {
            data = raw.mapValues { $0.stringValue }
        } else {
            data = nil
        }
    }

    init(
        id: Int,
        type: String,
        title: String,
        body: String,
        link: String?,
        data: [String: String]?,
        readAt: String?,
        createdAt: String,
        coalescedCount: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.link = link
        self.data = data
        self.readAt = readAt
        self.createdAt = createdAt
        self.coalescedCount = coalescedCount
    }
}

/// A JSON scalar, or `null` for anything that is not one (arrays, nested
/// objects). Used only to flatten `Notification.data`.
enum JSONScalar: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) {
            self = .string(v)
        } else if let v = try? c.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? c.decode(Int.self) {
            self = .int(v)
        } else if let v = try? c.decode(Double.self) {
            self = .double(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let v): return v
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .bool(let v): return v ? "true" : "false"
        case .null: return ""
        }
    }
}

// MARK: - Preferences

/// The user's notification preferences, exactly as the server serialises them.
///
/// The server owns the per-type copy (`label`, `description`) and the
/// `userConfigurable` flag. Duplicating that list on the client would mean two
/// places to update when a type is added, and would let the settings screen
/// offer a switch the API refuses to honour. The client contributes only the
/// icon, which is a presentation detail the server has no business knowing.
struct NotificationPreferences: Codable, Equatable {
    var types: [NotificationTypePreference]
    var quietHours: QuietHours

    static let empty = NotificationPreferences(types: [], quietHours: .disabled)

    func preference(for type: String) -> NotificationTypePreference? {
        types.first { $0.type == type }
    }

    func isPushEnabled(for type: String) -> Bool {
        preference(for: type)?.push ?? true
    }

    func isInAppEnabled(for type: String) -> Bool {
        preference(for: type)?.inApp ?? true
    }

    /// The types the user is allowed to change. The server flags these; the
    /// settings screen renders the rest as fixed rows rather than hiding them,
    /// so it is clear the type exists and is simply not optional.
    var configurableTypes: [NotificationTypePreference] {
        types.filter { $0.userConfigurable }
    }
}

struct NotificationTypePreference: Codable, Equatable, Identifiable {
    let type: String
    let label: String
    let description: String
    let userConfigurable: Bool
    var push: Bool
    var inApp: Bool

    var id: String { type }

    var knownType: NotificationType? { NotificationType(rawValue: type) }

    var icon: String { knownType?.icon ?? "bell" }

    enum CodingKeys: String, CodingKey {
        case type, label, description, userConfigurable, push, inApp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? type
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        userConfigurable = try c.decodeIfPresent(Bool.self, forKey: .userConfigurable) ?? true
        push = try c.decodeIfPresent(Bool.self, forKey: .push) ?? true
        inApp = try c.decodeIfPresent(Bool.self, forKey: .inApp) ?? true
    }
}

/// Quiet hours are a *deferral*, not a mute: a notification raised inside the
/// window is held and delivered when the window ends. That is what makes it safe
/// to leave on, and it is why the UI must not describe it as "silence".
struct QuietHours: Codable, Equatable {
    var enabled: Bool
    /// Local hour, 0-23, in the user's own timezone. The server resolves the
    /// user's zone; these are wall-clock hours, not offsets.
    var start: Int
    var end: Int

    static let disabled = QuietHours(enabled: false, start: 22, end: 7)

    enum CodingKeys: String, CodingKey {
        case enabled, start, end
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        start = try c.decodeIfPresent(Int.self, forKey: .start) ?? 22
        end = try c.decodeIfPresent(Int.self, forKey: .end) ?? 7
    }

    init(enabled: Bool, start: Int, end: Int) {
        self.enabled = enabled
        self.start = start
        self.end = end
    }

    /// A window that wraps midnight (22 → 7) is the normal case, so this cannot
    /// assume `start < end`.
    func contains(hour: Int) -> Bool {
        guard enabled, start != end else { return false }
        return start < end
            ? (hour >= start && hour < end)
            : (hour >= start || hour < end)
    }

    /// "10 PM – 7 AM", for the settings row.
    var displayRange: String {
        "\(Self.hourLabel(start)) – \(Self.hourLabel(end))"
    }

    static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 0: return "12 AM"
        case 12: return "12 PM"
        case 13...23: return "\(h - 12) PM"
        default: return "\(h) AM"
        }
    }
}

// MARK: - Type enum (icons only)

/// The notification types this build knows about.
///
/// Deliberately *not* the source of truth for which types exist or what they are
/// called — the server sends that. This exists so the client can pick an icon and
/// a deep-link destination, and so an unknown type degrades to a generic bell
/// instead of an empty row.
enum NotificationType: String, CaseIterable, Identifiable {
    case friendRequest = "FRIEND_REQUEST"
    case friendAccepted = "FRIEND_ACCEPTED"
    case streakRequest = "STREAK_REQUEST"
    case awardUnlocked = "AWARD_UNLOCKED"
    case streakFreezeReceived = "STREAK_FREEZE_RECEIVED"
    case ringsClosed = "RINGS_CLOSED"
    case friendRingsClosed = "FRIEND_RINGS_CLOSED"
    case announcement = "ANNOUNCEMENT"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "person.badge.checkmark"
        case .streakRequest: return "flame"
        case .awardUnlocked: return "medal"
        case .streakFreezeReceived: return "snowflake"
        case .ringsClosed: return "circle.circle"
        case .friendRingsClosed: return "person.2.circle"
        case .announcement: return "megaphone"
        }
    }
}
