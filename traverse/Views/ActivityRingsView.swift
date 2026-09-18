import SwiftUI

/// Apple-Fitness-style concentric activity rings.
///
/// Two rings, outer = new solves, inner = completed revisions. Both are drawn
/// against a fixed full-circle track so an untouched day still reads as two
/// rings rather than nothing.
///
/// The track is `.ultraThinMaterial` rather than a flat grey. On the streak card
/// the rings sit on top of `LightingSunBackground`, which is a shader whose
/// brightness changes with the streak — a hard-coded grey track would look right
/// at one streak length and wrong at every other. A material samples what is
/// behind it, so the track stays legible across the whole range.
///
/// Progress is animated rather than snapped. The rings are the reward for the
/// action that just happened, and a ring that jumps from 0.0 to 1.0 in one frame
/// is easy to miss entirely when the user is looking at the submit button.
struct ActivityRingsView: View {
    /// Fraction filled, 0...1. Values above 1 are clamped by the caller.
    let solveFraction: Double
    let revisionFraction: Double

    /// Colours for the outer and inner ring. Passed in rather than read from the
    /// palette manager here so this view stays usable outside the app (widgets,
    /// previews) and so the caller decides which palette slots a pair uses.
    let solveColor: Color
    let revisionColor: Color

    var diameter: CGFloat = 84
    var strokeWidth: CGFloat = 9

    /// Space between the two rings. Below about 2pt the rings visually merge at
    /// small sizes.
    var ringGap: CGFloat = 3

    /// Adds a soft bloom behind the rings when both are closed, so the completed
    /// state is visible without adding a badge or any text.
    var celebratesWhenComplete: Bool = true

    private var outerRadius: CGFloat { diameter / 2 - strokeWidth / 2 }
    private var innerRadius: CGFloat { outerRadius - strokeWidth - ringGap }

    private var allClosed: Bool {
        solveFraction >= 1 && revisionFraction >= 1
    }

    var body: some View {
        ZStack {
            if celebratesWhenComplete && allClosed {
                Circle()
                    .fill(solveColor)
                    .frame(width: diameter, height: diameter)
                    .blur(radius: 16)
                    .opacity(0.28)
                    .transition(.opacity)
            }

            ring(fraction: solveFraction, color: solveColor, radius: outerRadius)
            ring(fraction: revisionFraction, color: revisionColor, radius: innerRadius)
        }
        .frame(width: diameter, height: diameter)
        .animation(.spring(response: 0.75, dampingFraction: 0.78), value: solveFraction)
        .animation(.spring(response: 0.75, dampingFraction: 0.78), value: revisionFraction)
        .animation(.easeInOut(duration: 0.35), value: allClosed)
    }

    private func ring(fraction: Double, color: Color, radius: CGFloat) -> some View {
        ZStack {
            // Track. Drawn as a full circle, always, so the ring's shape is
            // legible before any progress exists.
            Circle()
                .strokeBorder(.ultraThinMaterial, lineWidth: strokeWidth)
                .frame(width: radius * 2, height: radius * 2)

            // Fill. Rotation of -90° starts the sweep at 12 o'clock; SwiftUI's
            // zero angle is 3 o'clock.
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }
}

/// A single ring, for places that only need one (the inbox's "friend closed
/// their rings" rows, the history strip).
struct SingleRingView: View {
    let fraction: Double
    let color: Color
    var diameter: CGFloat = 44
    var strokeWidth: CGFloat = 5

    private var radius: CGFloat { diameter / 2 - strokeWidth / 2 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.ultraThinMaterial, lineWidth: strokeWidth)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    VStack(spacing: 32) {
        ActivityRingsView(
            solveFraction: 1,
            revisionFraction: 1,
            solveColor: Color(hex: "0077B6"),
            revisionColor: Color(hex: "00B4D8")
        )

        ActivityRingsView(
            solveFraction: 0.6,
            revisionFraction: 0.2,
            solveColor: Color(hex: "FF6B6B"),
            revisionColor: Color(hex: "FFD93D")
        )

        ActivityRingsView(
            solveFraction: 0,
            revisionFraction: 0,
            solveColor: Color(hex: "2D6A4F"),
            revisionColor: Color(hex: "52B788")
        )

        HStack(spacing: 20) {
            SingleRingView(fraction: 1, color: .green)
            SingleRingView(fraction: 0.5, color: .orange)
        }
    }
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
