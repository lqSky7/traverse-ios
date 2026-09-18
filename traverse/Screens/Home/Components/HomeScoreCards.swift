import SwiftUI

/// The streak hero at the top of the feed.
///
/// It has been through three layouts. Originally a half-width tile sharing its
/// row with the revision score card, laid out to suit that: a small number
/// bottom-left, a "BEST" figure top-right, everything else empty. Then full
/// width with the type scaled up and centred — which fixed the size but left a
/// band of dead space down each side, because a centred column in a 361pt card
/// only occupies about 120pt of it.
///
/// This version uses that space instead of centring into it: the streak block
/// moves left and the right side carries the activity rings. The rings are the
/// point — a streak says how long you have been consistent, but it says nothing
/// about today, and today is the only day the user can still act on. Two rings,
/// both open, is a more useful thing to see at 9pm than a number that cannot
/// change until tomorrow.
///
/// The whole card is the tap target for the goal sheet. A small "edit" affordance
/// would be more discoverable, but the card is already the thing the goals
/// describe, and tapping what you want to change is the shorter path.
///
/// `monospacedDigit()` keeps the number from jittering horizontally as it
/// changes, which is visible at this size.
struct StreakCard: View {
    let streak: Int
    var maxStreak: Int? = nil
    var rings: RingProgress? = nil

    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    @State private var showingGoalSheet = false

    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }

    /// The stored best can lag behind a live streak that has already passed it,
    /// so show whichever is larger rather than telling the user their best is
    /// lower than the number directly above it.
    private var maxStreakDisplay: Int {
        max(streak, maxStreak ?? 0)
    }

    /// Outer ring = new solves, inner ring = revisions. These are palette slots,
    /// not semantic colours: the palette is user-selectable, so a fixed red/green
    /// pair would either ignore the choice or clash with it.
    private var solveColor: Color { paletteManager.color(at: 0) }
    private var revisionColor: Color { paletteManager.color(at: 1) }

    private var ringProgress: RingProgress { rings ?? .empty() }

    var body: some View {
        Button {
            showingGoalSheet = true
        } label: {
            cardBody
        }
        .buttonStyle(RingCardButtonStyle())
        .sheet(isPresented: $showingGoalSheet) {
            RingGoalsSheet()
        }
    }

    private var cardBody: some View {
        HStack(alignment: .center, spacing: 12) {
            streakBlock

            Spacer(minLength: 4)

            ringLegend

            ActivityRingsView(
                solveFraction: ringProgress.solveFraction,
                revisionFraction: ringProgress.revisionFraction,
                solveColor: solveColor,
                revisionColor: revisionColor,
                diameter: 76,
                strokeWidth: 8
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            LightingSunBackground(streak: streak)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens ring goal settings")
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(streak)")
                .font(.system(size: 54, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

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

    /// The counts, with a dot in each ring's colour. Without this the rings say
    /// "not yet" but not "one more", and the difference between 0/1 and 4/5 is
    /// exactly what the user needs at the end of a day.
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

/// Gives the card a press state.
///
/// The card carries a live shader background, so it cannot use the default
/// button styles — they tint the label, which would wash out the whole card.
/// Scaling slightly is the cheapest way to confirm the tap registered without
/// touching the colours.
private struct RingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Lighting Sun Background (Lighting Simulation Shader from Settings > Demo)

struct LightingSunBackground: View {
    let streak: Int
    @State private var animatedProgress: Double = 0.0
    
    private var targetProgress: Double {
        Double(min(max(Float(streak), 0), 15.0) / 15.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            AnimatableLightingSun(
                progress: animatedProgress,
                cardHeight: geometry.size.height
            )
        }
        .onAppear {
            animatedProgress = 0.0
            withAnimation(.spring(response: 1.1, dampingFraction: 0.72, blendDuration: 0)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: streak) { _, newStreak in
            let newTarget = Double(min(max(Float(newStreak), 0), 15.0) / 15.0)
            withAnimation(.spring(response: 1.1, dampingFraction: 0.72, blendDuration: 0)) {
                animatedProgress = newTarget
            }
        }
    }
}

private struct AnimatableLightingSun: View, Animatable {
    var progress: Double
    var cardHeight: CGFloat
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        let p = Float(progress)
        let intensity = 0.3 + p * 2.2
        let disperse = 0.15 + p * 0.60
        let radius = 10.0 + p * 40.0
        let height = Float(cardHeight > 0 ? cardHeight : 90.0)
        let targetY = height / 1.2
        
        Color.black
            .layerEffect(
                ShaderLibrary.lightingSimulation(
                    .float2(5.0, targetY),
                    .float(intensity),
                    .float(disperse),
                    .float(-Float.pi / 2.0),
                    .float(radius)
                ),
                maxSampleOffset: .zero
            )
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
