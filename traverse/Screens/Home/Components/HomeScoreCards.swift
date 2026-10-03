//
//  HomeScoreCards.swift
//  traverse
//
//  The streak hero at the top of the home feed.
//

import SwiftUI

// MARK: - Week strip model

/// One day in the streak card's week strip.
enum StreakDayState {
    /// Banked — the day has activity against it.
    case solved
    /// No activity. Shown as a bare track, not as a failure.
    case missed
    /// Held by a streak freeze. Ice blue, matching the heatmap.
    case frozen
    /// Today, already banked.
    case today
    /// Today, still open. The only day the user can still act on, so it gets its own state
    /// rather than reading as a gap.
    case todayPending
}

struct StreakDay: Identifiable {
    let date: Date
    let state: StreakDayState
    var id: Date { date }
}

// MARK: - Streak card

/// The streak hero at the top of the feed.
///
/// It has been through four layouts. Originally a half-width tile sharing its row with the
/// revision score card. Then full width with the type scaled up and centred — which fixed the
/// size but left a band of dead space down each side, because a centred column in a 361pt card
/// only occupies about 120pt of it. Then full width with the streak block left and the activity
/// rings right, over a Metal light-dispersion shader.
///
/// The shader is gone. It was the only card in the feed that wasn't a `systemGray6` tile, the
/// only one whose colour ignored the user's palette, and it sprang on appear and on every streak
/// change in a tab that never unloads. Two attempts to replace it with something quieter both
/// failed on looks: a flat band gradient at low alpha over the tile reads as mud (blending a
/// saturated colour into a dark neutral gives a brownish-grey mid-tone, and the tile stops
/// looking like `systemGray6` at all), and corner-anchored glows read as a band bleeding in from
/// two corners. The base is now flat, matching every other card.
///
/// The colour moved into the week strip instead, where it has a job — see `WeekStrip`.
///
/// The rings are still the point: a streak says how long you have been consistent, but it says
/// nothing about today, and today is the only day the user can still act on.
///
/// The whole card is the tap target for the goal sheet. A small "edit" affordance would be more
/// discoverable, but the card is already the thing the goals describe, and tapping what you want
/// to change is the shorter path.
struct StreakCard: View {
    let streak: Int
    var maxStreak: Int? = nil
    var rings: RingProgress? = nil
    /// Solve history for the week strip. Defaults to empty so previews and the widget can build
    /// the card without it; the strip then renders as seven open days.
    var solves: [Solve] = []
    /// "YYYY-MM-DD" keys, matching `HomeViewModel.frozenDates`.
    var frozenDates: Set<String> = []
    /// Once-per-visit latch for the number's sweep. Supplied by the screen rather than owned
    /// here, because this card sits in a `LazyVStack` and is disposed once it scrolls out of the
    /// keep-alive window — a `@State` latch would reset on scroll and the sweep would replay every
    /// time the user scrolled back up.
    var sweepGate: ChromaSweepGate? = nil

    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    @State private var showingGoalSheet = false

    private var ringProgress: RingProgress { rings ?? .empty() }

    private var daysText: String { streak == 1 ? "DAY" : "DAYS" }

    /// The stored best can lag behind a live streak that has already passed it, so show whichever
    /// is larger rather than telling the user their best is lower than the number directly above
    /// it.
    private var maxStreakDisplay: Int { max(streak, maxStreak ?? 0) }

    /// Outer ring = new solves, inner ring = revisions. These are palette slots, not semantic
    /// colours: the palette is user-selectable, so a fixed red/green pair would either ignore the
    /// choice or clash with it.
    private var solveColor: Color { paletteManager.color(at: 0) }
    private var revisionColor: Color { paletteManager.color(at: 1) }

    private static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// The last seven days, oldest first, with today rightmost.
    ///
    /// Reads the same `ActivityMetrics.daily(solves:days:)` helper the metric cards use, so the
    /// strip and the charts can never disagree about which day a solve belongs to. No new
    /// endpoint: `daily` already zero-fills gaps, so the strip keeps an even rhythm on a rest day
    /// instead of collapsing.
    private var weekDays: [StreakDay] {
        let buckets = ActivityMetrics.daily(solves: solves, days: 7) { _ in 1 }
        let lastIndex = buckets.count - 1
        return buckets.enumerated().map { index, bucket in
            let state: StreakDayState
            if index == lastIndex {
                // Today is the only day the user can still act on, so it never reads as a gap —
                // it reads as open.
                state = bucket.value > 0 ? .today : .todayPending
            } else if frozenDates.contains(Self.dayKey.string(from: bucket.date)) {
                state = .frozen
            } else {
                state = bucket.value > 0 ? .solved : .missed
            }
            return StreakDay(date: bucket.date, state: state)
        }
    }

    var body: some View {
        Button {
            showingGoalSheet = true
        } label: {
            cardBody
        }
        .buttonStyle(StreakCardButtonStyle())
        .sheet(isPresented: $showingGoalSheet) {
            RingGoalsSheet()
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Streak")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                // The same chevron-in-circle every other tappable card on the feed carries. This
                // card was already a tap target and had no affordance saying so.
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }

            HStack(alignment: .center, spacing: 14) {
                ActivityRingsView(
                    solveFraction: ringProgress.solveFraction,
                    revisionFraction: ringProgress.revisionFraction,
                    solveColor: solveColor,
                    revisionColor: revisionColor,
                    diameter: 84,
                    strokeWidth: 9
                )

                streakBlock

                Spacer(minLength: 0)

                ringLegend
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            WeekStrip(days: weekDays)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flat `systemGray6`, the same surface as every other card in the feed. Nothing is laid
        // over it — see the note on the type.
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens ring goal settings")
    }

    /// Number, then the two labels underneath, at the sizes this card has always used: a
    /// tracked-out `DAYS` and a dimmer `BEST`. Kept as a two-line stack rather than a single
    /// `DAYS · BEST 21` line — the single line had to drop both to 11.5pt to fit, which lost the
    /// hierarchy between "how long" and "how long ever".
    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Sweeps out of the band and lands on white.
            //
            // White rather than a palette slot: the sweep has to resolve to *something*, and under
            // the Traverse palette slot 2 is amber, which reads as yellow sitting next to the strip.
            // White is also what this number was before it was palette-tinted, and it is the
            // highest-contrast thing on a `systemGray6` tile.
            //
            // No `.id()` on a changing value. Re-keying it on the streak is what made the number
            // re-sweep while the user was still looking at the card; the gate in `HomeView` is what
            // decides when it plays instead.
            ChromaText(
                text: "\(streak)",
                font: .system(size: 40, weight: .bold),
                restingColor: .white,
                delay: 0.15,
                duration: 1.25,
                gate: sweepGate,
                sweepKey: "streak-number"
            )

            Text(daysText)
                .font(.system(size: 13, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.85))

            if maxStreakDisplay > 0 {
                Text("BEST \(maxStreakDisplay)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 6)
            }
        }
    }

    /// The counts, with a dot in each ring's colour. Without this the rings say "not yet" but not
    /// "one more", and the difference between 0/1 and 4/5 is exactly what the user needs at the
    /// end of a day.
    private var ringLegend: some View {
        VStack(alignment: .trailing, spacing: 7) {
            legendRow(
                color: solveColor,
                value: "\(ringProgress.solves)/\(ringProgress.solveGoal)",
                label: "solved"
            )
            legendRow(
                color: revisionColor,
                value: "\(ringProgress.revisions)/\(ringProgress.revisionGoal)",
                label: "reviewed"
            )
        }
    }

    private func legendRow(color: Color, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityLabel("\(value) \(label)")
    }

    private var accessibilityDescription: String {
        var parts = ["\(streak) day streak"]
        if maxStreakDisplay > 0 {
            parts.append("best \(maxStreakDisplay)")
        }
        parts.append("\(ringProgress.solves) of \(ringProgress.solveGoal) solved")
        parts.append("\(ringProgress.revisions) of \(ringProgress.revisionGoal) reviewed")
        if ringProgress.allClosed {
            parts.append("both rings closed")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Week strip

/// Seven day dots under the streak card's divider.
///
/// **This is the card's only chroma.** Each day takes the band colour at its position, so the
/// strip walks pink → crimson → amber → ice → cobalt from left to right and a longer streak
/// lights more of it. That is the "more streak, more colour" idea the shader used to carry,
/// moved somewhere it does not fight the surface.
///
/// Deliberately **palette-driven**, matching the text sweep. Both used to be pinned to a hardcoded
/// band, which meant the app's two most brand-forward elements were also its two most palette-blind
/// ones — a Monochrome user got grey everywhere except here and the streak number. The default
/// palette (Traverse) is the chroma band, so the out-of-the-box look is unchanged. Small elements
/// carry full saturation happily — 17pt dots read as colour, a 360pt tile does not.
struct WeekStrip: View {
    let days: [StreakDay]

    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"   // single letter
        return formatter
    }()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let tint = paletteManager.selectedPalette.color(at: index, of: max(days.count, 1))

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.11))
                            .frame(width: 17, height: 17)

                        switch day.state {
                        case .solved, .today:
                            Circle().fill(tint).frame(width: 17, height: 17)

                        case .frozen:
                            Circle()
                                .stroke(Color(hex: "4FC3F7"), lineWidth: 2)
                                .frame(width: 17, height: 17)

                        case .todayPending:
                            Circle()
                                .stroke(tint.opacity(0.55), lineWidth: 2)
                                .frame(width: 17, height: 17)

                        case .missed:
                            EmptyView()
                        }
                    }
                    .overlay {
                        // Today always carries a ring, so the strip has a fixed "you are here"
                        // even on a day with nothing banked yet.
                        if day.state == .today || day.state == .todayPending {
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
                                .frame(width: 17, height: 17)
                        }
                    }

                    Text(Self.weekday.string(from: day.date))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let described = days.map { day -> String in
            let label = Self.weekday.string(from: day.date)
            switch day.state {
            case .solved:       return "\(label) solved"
            case .missed:       return "\(label) no activity"
            case .frozen:       return "\(label) frozen"
            case .today:        return "\(label) today, solved"
            case .todayPending: return "\(label) today, still open"
            }
        }
        return "Last seven days: " + described.joined(separator: ", ")
    }
}

// MARK: - Button style

/// Gives the card a press state.
///
/// The card used to carry a live shader background, so it could not use the default button
/// styles — they tint the label, which washed out the whole card. The shader is gone, but a
/// scale still reads better here than a tint over a whole tile of content, and it is the
/// cheapest way to confirm the tap landed.
private struct StreakCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakCard(streak: 12, maxStreak: 21)

        StreakCard(
            streak: 12,
            maxStreak: 21,
            rings: RingProgress(
                date: "2026-09-18",
                solves: 3,
                revisions: 1,
                solveGoal: 5,
                revisionGoal: 3,
                configuredSolveGoal: 5,
                configuredRevisionGoal: 3,
                solveRingClosed: false,
                revisionRingClosed: false,
                allClosed: false,
                closedAt: nil
            )
        )

        StreakCard(
            streak: 34,
            maxStreak: 34,
            rings: RingProgress(
                date: "2026-09-18",
                solves: 2,
                revisions: 2,
                solveGoal: 2,
                revisionGoal: 2,
                configuredSolveGoal: 2,
                configuredRevisionGoal: 2,
                solveRingClosed: true,
                revisionRingClosed: true,
                allClosed: true,
                closedAt: "2026-09-18T14:02:00Z"
            )
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
