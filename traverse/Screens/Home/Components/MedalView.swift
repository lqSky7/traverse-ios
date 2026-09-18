import SwiftUI
import UIKit

/// An Apple Fitness style award badge.
///
/// The badge leans in 3D while the user holds and drags on it. This is deliberately
/// **not** CoreMotion driven: the real Fitness app tilts its medals with device motion,
/// but here the tilt is a press-and-drag so it is discoverable, works with the phone
/// flat on a table, and never fights the surrounding scroll view.
struct MedalView: View {
    let medal: String
    var unlocked: Bool = true
    var size: CGFloat = 120
    /// Off by default: a badge only tilts where the user has explicitly asked for it
    /// (currently only the badge detail sheet).
    ///
    /// The default is deliberate rather than lazy. A `DragGesture` on a badge inside a
    /// pushed screen does two bad things at once: every badge on screen becomes
    /// draggable, and the eager gesture starves the navigation controller's
    /// screen-edge pan, which kills swipe-to-go-back for the entire screen. Opting in
    /// per call site keeps both failures from coming back.
    var interactive: Bool = false
    var showsShadow: Bool = true

    /// Degrees of lean at full drag. Apple's medals lean further than you'd expect — a
    /// shallow tilt reads as a wobble rather than a physical object.
    private let maxTilt: Double = 32

    @GestureState private var drag: CGSize = .zero
    @State private var hapticsArmed = true

    private var tiltX: Double { Double(-drag.height / max(size, 1)) * maxTilt }
    private var tiltY: Double { Double(drag.width / max(size, 1)) * maxTilt }

    /// Parallax: the badge pushes a hair toward the viewer while it is being handled.
    private var lift: CGFloat {
        let magnitude = min(1, hypot(drag.width, drag.height) / max(size, 1))
        return 1 + magnitude * 0.05
    }

    private var isTilting: Bool { drag != .zero }

    var body: some View {
        badge
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(showsShadow ? (unlocked ? 0.45 : 0.25) : 0),
                radius: isTilting ? 18 : 10,
                x: -drag.width * 0.06,
                y: isTilting ? 12 : 6
            )
            .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(lift)
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: isTilting)
            .contentShape(Rectangle())
            .modifier(TiltGestureModifier(gesture: tiltGesture, enabled: interactive))
            .onChange(of: drag) { previous, current in
                guard interactive else { return }
                if previous == .zero, current != .zero, hapticsArmed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                    hapticsArmed = false
                } else if current == .zero {
                    hapticsArmed = true
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(medalAccessibilityLabel))
    }

    // MARK: - Rendering

    private var baseImage: some View {
        Image(medal)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }

    private var badge: some View {
        ZStack {
            if unlocked {
                baseImage
                // The renders already carry their own baked specular, so the moving highlight
                // is only worth drawing where the user can actually tilt the badge.
                if interactive {
                    specularSheen
                }
            } else {
                // Unearned badges read as a drained, dark relief — same silhouette, no colour.
                baseImage
                    .grayscale(1)
                    .brightness(-0.30)
                    .colorMultiply(Color(white: 0.72))
                    .opacity(0.9)
            }
        }
        // Clip the sheen to the badge's own alpha so the highlight never spills onto the card.
        .mask { baseImage }
    }

    /// A fixed light source: as the badge leans, the highlight sweeps across its face.
    private var specularSheen: some View {
        let reach = max(size, 1) * 0.9
        let offsetX = -drag.width * 0.85
        let offsetY = -drag.height * 0.85

        return RadialGradient(
            colors: [
                .white.opacity(isTilting ? 0.55 : 0.18),
                .white.opacity(isTilting ? 0.10 : 0.03),
                .clear,
            ],
            center: .center,
            startRadius: 0,
            endRadius: reach * 0.62
        )
        .blendMode(.plusLighter)
        .offset(x: offsetX, y: offsetY)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: drag)
    }

    private var tiltGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($drag) { value, state, _ in
                state = value.translation
            }
    }

    private var medalAccessibilityLabel: String {
        unlocked ? "Earned award badge" : "Locked award badge"
    }
}

/// Attaches the tilt drag only where the badge is actually interactive. A badge inside a
/// `NavigationLink` leaves it off so the link keeps the tap.
private struct TiltGestureModifier<G: Gesture>: ViewModifier {
    let gesture: G
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(gesture)
        } else {
            content
        }
    }
}

// MARK: - Progress bar/// The thin capsule Apple draws under an in-progress badge.
struct MedalProgressBar: View {
    let fraction: Double
    var width: CGFloat = 96
    var tint: Color = .white

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.16))
            Capsule()
                .fill(tint)
                .frame(width: max(2, width * min(max(fraction, 0), 1)))
        }
        .frame(width: width, height: 4)
    }
}

// MARK: - Formatting helpers

enum AwardFormat {
    private static let iso = ISO8601DateFormatter()

    private static let dayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        return f
    }()

    private static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    static func date(_ isoString: String?) -> Date? {
        guard let isoString else { return nil }
        return iso.date(from: isoString)
    }

    /// "8/23/26" — the short stamp under a badge.
    static func shortDate(_ isoString: String?) -> String? {
        guard let date = date(isoString) else { return nil }
        return dayMonthYear.string(from: date)
    }

    /// "August 2026" — the stamp under a monthly challenge badge.
    static func monthYear(_ isoString: String?) -> String? {
        guard let date = date(isoString) else { return nil }
        return monthYear.string(from: date)
    }

    /// "3d ago" / "2h ago" — used where a badge has no numeric progress to show.
    static func relative(_ isoString: String?) -> String? {
        guard let date = date(isoString) else { return nil }
        let parts = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: Date())
        if let days = parts.day, days > 0 { return "\(days)d ago" }
        if let hours = parts.hour, hours > 0 { return "\(hours)h ago" }
        if let minutes = parts.minute, minutes > 0 { return "\(minutes)m ago" }
        return "just now"
    }

    /// "2026" — the stamp under a monthly challenge badge, matching the Fitness app.
    static func year(_ isoString: String?) -> String? {
        guard let date = date(isoString) else { return nil }
        return yearFormatter.string(from: date)
    }

    /// The line under a badge in a grid cell: progress while it's in flight, otherwise the
    /// unlock stamp, otherwise the goal description.
    static func caption(for award: AchievementDetail) -> String {
        if !award.unlocked, let progress = award.progress {
            return progress.caption
        }

        if award.unlocked {
            // Monthly challenges are stamped with their year, the way Apple does it.
            if award.key.hasPrefix("monthly_challenge_"), let stamp = year(award.unlockedAt) {
                return stamp
            }
            if let stamp = shortDate(award.unlockedAt) {
                return stamp
            }
        }

        if let progress = award.progress {
            return progress.caption
        }
        return award.description
    }
}
