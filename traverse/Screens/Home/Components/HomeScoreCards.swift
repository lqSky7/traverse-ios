import SwiftUI

struct StreakCard: View {
    let streak: Int
    var maxStreak: Int? = nil
    
    private var displayNumber: String {
        streak == 0 ? "0" : "\(streak)"
    }
    
    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }
    
    private var maxStreakDisplay: Int {
        max(streak, maxStreak ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: streak == 0 ? "flame" : "flame.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if maxStreakDisplay > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("BEST")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                        Text("\(maxStreakDisplay)D")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayNumber)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                Text(daysText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            LightingSunBackground(streak: streak)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Thinking Orb Score Effect (Settings > Shaders & Demos > Thinking Orb)
struct ThinkingOrbScoreView: View {
    let score: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    
    // Normalized score factor [0.0, 1.0]
    private var normalizedScore: CGFloat {
        CGFloat(min(max(score, 0), 100)) / 100.0
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let speed = 0.6 + Double(normalizedScore) * 0.8
            let phase = now * speed
            let progress = sin(phase)
            
            let primaryColor = paletteManager.color(at: 0)
            let secondaryColor = paletteManager.color(at: 1)
            
            // Dynamic scale and opacity driven by revision score
            let orbScale = 0.55 + 0.35 * normalizedScore
            let orbOpacity = 0.40 + 0.55 * normalizedScore
            
            ZStack {
                // Primary ambient glow body
                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .blur(radius: 24)
                    .rotationEffect(Angle(radians: progress * 0.7))
                
                // Secondary core layer
                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .foregroundStyle(secondaryColor.mix(with: .white, by: 0.35))
                    .frame(width: 70, height: 42)
                    .blur(radius: 18)
                    .rotationEffect(Angle(radians: -progress * 0.7))
                
                // Bright white filament highlight
                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 80, height: 40)
                    .offset(y: -14)
                    .blur(radius: 24)
                    .rotationEffect(Angle(radians: progress * 0.35))
            }
            .scaleEffect(orbScale)
            .opacity(orbOpacity)
            .blendMode(.screen)
        }
    }
}

// MARK: - Revision Score Card (Pure black, Thinking Orb in top right, central number, NO grid, NO glass)
struct RevisionScoreCard: View {
    let score: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var showExplanationSheet = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            showExplanationSheet = true
        }) {
            ZStack {
                // 1. Pure black background
                Color.black
                
                // 2. Thinking Orb pushed to very top-right corner
                VStack {
                    HStack {
                        Spacer()
                        ThinkingOrbScoreView(score: score, paletteManager: paletteManager)
                            .offset(x: 24, y: -24)
                    }
                    Spacer()
                }
                
                // 3. Central score number with exact same font and color as streak card number
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showExplanationSheet) {
            RevisionScoreExplanationSheet()
        }
    }
}

// MARK: - Revision Score Explanation Sheet (Matches Revision > Analytics Info Sheet 1:1)

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



// MARK: - Main Stats Card
