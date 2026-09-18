import SwiftUI

/// The streak hero at the top of the feed.
///
/// This used to be a half-width tile sharing its row with the revision score
/// card, and its contents were laid out to suit that: a small number pinned to
/// the bottom-left, a "BEST" figure pinned to the top-right, everything else
/// empty. It is full width now, so the layout is centred and the type scaled up
/// to fill the space — the number is the point of the card and it was set at
/// 40pt in a 393pt-wide tile.
///
/// `monospacedDigit()` keeps the number from jittering horizontally as it
/// changes, which is visible at this size.
struct StreakCard: View {
    let streak: Int
    var maxStreak: Int? = nil

    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }

    /// The stored best can lag behind a live streak that has already passed it,
    /// so show whichever is larger rather than telling the user their best is
    /// lower than the number directly above it.
    private var maxStreakDisplay: Int {
        max(streak, maxStreak ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: streak == 0 ? "flame" : "flame.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            Text("\(streak)")
                .font(.system(size: 68, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(daysText)
                .font(.system(size: 15, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.85))

            if maxStreakDisplay > 0 {
                Text("BEST \(maxStreakDisplay) \(maxStreakDisplay == 1 ? "DAY" : "DAYS")")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LightingSunBackground(streak: streak)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
