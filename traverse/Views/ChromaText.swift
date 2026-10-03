//
//  ChromaText.swift
//  traverse
//
//  The app's copy of the website's brand text reveal.
//
//  Source of truth is LeetFeedback: `src/components/ui/textRenderAppear.tsx`
//  (`ChromaText`) plus the `chroma-sweep` / `chroma-sweep-beyond` keyframes in
//  `src/index.css`. "textrenderappear" and "chromasweep" are the same feature.
//
//  NOTE ON THE SITE'S HEADER COMMENT. `textRenderAppear.tsx` opens with a
//  "CRITICAL: DO NOT BREAK THIS ANIMATION" block — no inline animation styles, one
//  <style> tag at the parent level, no dynamically injected styles, no CSS variables
//  for timing. Every one of those rules is a Tailwind source-scanning or CSS-injection
//  constraint. None of them exist in SwiftUI, and none of them should be recreated
//  here. What is worth porting is the *mechanic*, below.
//

import SwiftUI
// Needed for `ObservableObject` on `ChromaSweepGate` below. SwiftUI re-exports the protocol but not
// Combine's extension that supplies the default `objectWillChange`, so without this the class fails
// to conform even though it has nothing to publish.
import Combine

// MARK: - Where the band lives now

/// The sweep's colours come from the **active palette**, not from a hardcoded band.
///
/// This used to be an enum holding the five website hexes. That made the sweep the one thing in the
/// app that ignored the user's palette choice — defensible only while nobody could tell, because the
/// default palette *is* the band. Now that Traverse (the chroma band, renamed) is the default and the
/// other palettes are one tap away, a hardcoded sweep meant picking Monochrome gave you grey
/// everywhere except the one animation that is supposed to carry the brand.
///
/// So the band is no longer a constant here. It is the Traverse palette's five colours, documented
/// at its definition in `ColorPalette.allPalettes`, and the sweep reads whichever palette is
/// selected. The same five hexes by default, and a coherent look on any other.

// MARK: - The sweep latch

/// Tracks which chroma sweeps have already played during the current visit to a screen.
///
/// **The rule is once per visit to a screen.** A sweep plays when the screen is first shown, does
/// *not* play again while the user stays on it — including when a list recycles the row and
/// `onAppear` fires a second time — and plays again when they come back from another screen.
///
/// Two things this is deliberately not:
///
/// - **Not once per session.** The website latches each sweep forever, which is right for a
///   scrolling marketing page you read once. In an app the home feed is somewhere you return to
///   many times a day; a sweep that never plays again stops being a brand moment and becomes
///   decoration.
/// - **Not on every value change.** The streak number used to re-sweep whenever the streak
///   changed, which fires while the user is still looking at the card. That is the opposite of an
///   entrance.
///
/// **Ownership matters.** The *screen* owns the gate. The card must not, because a card inside a
/// `LazyVStack` is disposed once it scrolls out of the keep-alive window — a `@State` on the card
/// would reset on scroll and the sweep would replay every time the user scrolled back up.
///
/// Reset it when the screen is re-entered. On iOS that means the pushed destinations, since
/// `NavigationStack` keeps the root mounted underneath them; see `HomeView`.
final class ChromaSweepGate: ObservableObject {
    private var played: Set<String> = []

    /// Returns `true` the first time this key is asked for during the current visit, `false`
    /// every time after. Inserts as a side effect, so it must be called exactly once per
    /// appearance.
    func claim(_ key: String) -> Bool {
        played.insert(key).inserted
    }

    /// Call when the owning screen is re-entered, so its sweeps play again.
    func reset() {
        played.removeAll()
    }
}

// MARK: - The sweep

/// Text that materialises out of the chroma band and settles into a solid colour.
///
/// **The mechanic.** The gradient is three times the width of the text, and the visible
/// window is the middle third of it. At `progress 0` the window sits on the gradient's
/// *right* third — which is transparent, so the text is invisible. As progress runs to 1
/// the window slides left, passing through the band, and lands on the left third, which is
/// the resting colour. Continuous, so no discrete swap is needed at the end.
///
/// **The trap.** The site declares `-webkit-text-fill-color: transparent` at *both* 0% and
/// 95% of its keyframe specifically so the fill change is confined to the last 5%. Declare
/// it only at the end and the browser interpolates it across the whole duration, leaving the
/// text faintly visible the entire sweep and muddying the reveal. The native equivalent:
/// never animate the text colour and the gradient at the same time. Here the resting colour
/// lives inside the gradient's left third, so there is nothing to interpolate.
///
/// **The blur.** `filter: blur(1px)` → `blur(0)` across the same window is what sells the
/// materialising rather than just the colouring-in. It is cosmetic — on Compose it needs
/// API 31+, and the sweep still reads without it.
struct ChromaText: View {
    let text: String
    var font: Font = .system(size: 40, weight: .bold)
    /// Where the sweep lands. Also the gradient's left third, so the handoff is seamless.
    var restingColor: Color = .white
    var delay: Double = 0.1
    var duration: Double = 1.2

    /// Once-per-visit latch. When supplied, the sweep only plays if the gate has not already seen
    /// `sweepKey` during this visit. Without a gate it plays on every appearance, which is right
    /// for a screen that is built and torn down rather than one the user returns to.
    var gate: ChromaSweepGate? = nil
    var sweepKey: String = "default"

    /// These three default to the numeral case — one line, shrinking rather than wrapping, tabular
    /// figures so a changing number does not jitter. An empty-state headline or a card title needs
    /// the opposite, so they are open here rather than baked into `SweptText`.
    var lineLimit: Int? = 1
    var minimumScaleFactor: CGFloat = 0.5
    var alignment: TextAlignment = .leading
    /// Tabular figures are meaningless on prose and slightly wrong on it, so this is opt-out.
    var monospacedDigits: Bool = true

    /// The colours the sweep travels through, read live from the palette rather than baked in.
    /// The default palette (Traverse) *is* the chroma band, so the out-of-the-box look is
    /// unchanged — but picking another palette now recolours the sweep instead of leaving it as the
    /// one part of the app that ignores the choice.
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    @State private var progress: Double = 0

    var body: some View {
        SweptText(
            text: text,
            font: font,
            restingColor: restingColor,
            colors: paletteManager.selectedPalette.swiftUIColors,
            lineLimit: lineLimit,
            minimumScaleFactor: minimumScaleFactor,
            alignment: alignment,
            monospacedDigits: monospacedDigits,
            progress: progress
        )
        .onAppear {
            // Already played on this visit — render the end state and skip the animation.
            guard gate?.claim(sweepKey) ?? true else {
                progress = 1
                return
            }
            withAnimation(.easeInOut(duration: duration).delay(delay)) {
                progress = 1
            }
        }
    }
}

/// The actual painting, split out so the gradient can interpolate.
///
/// A plain `@State Double` read inside a computed gradient does not reliably re-evaluate
/// per frame — SwiftUI interpolates the *animatable data* of views, not arbitrary derived
/// values. Conforming to `Animatable` is what guarantees `body` is called each frame with
/// an interpolated `progress`. Without it, a gradient built from a plain `@State Double`
/// can sit at its end state for the whole animation instead of sweeping.
private struct SweptText: View, Animatable {
    let text: String
    let font: Font
    let restingColor: Color
    /// The palette colours to sweep through, in palette order.
    let colors: [Color]
    let lineLimit: Int?
    let minimumScaleFactor: CGFloat
    let alignment: TextAlignment
    let monospacedDigits: Bool
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        (monospacedDigits ? Text(text).monospacedDigit() : Text(text))
            .font(font)
            .lineLimit(lineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .multilineTextAlignment(alignment)
            .foregroundStyle(fill)
            .blur(radius: (1 - progress) * 1)
    }

    private var fill: AnyShapeStyle {
        guard progress < 0.999 else { return AnyShapeStyle(restingColor) }

        // The gradient spans three text-widths. Left third = resting colour, middle fifth =
        // the palette, right third = clear. Sliding x0 from -2 to 0 walks the visible window
        // (which is always 0...1) from the right third to the left third.
        let x0 = -2 + 2 * progress

        var stops: [Gradient.Stop] = [
            .init(color: restingColor, location: 0),
            .init(color: restingColor, location: 0.3333),
        ]
        // The window is a fixed 0.20 wide and the step is derived from the colour count, so a
        // five-colour palette lands on exactly the original 0.40 / 0.45 / 0.50 / 0.55 / 0.60 —
        // while a custom palette with three or eight colours still fills the window instead of
        // crowding one end of it.
        let span = 0.20
        let step = colors.count > 1 ? span / Double(colors.count - 1) : 0
        for (index, color) in colors.enumerated() {
            stops.append(.init(color: color, location: 0.40 + Double(index) * step))
        }
        stops.append(.init(color: .clear, location: 0.6667))
        stops.append(.init(color: .clear, location: 1))

        return AnyShapeStyle(
            LinearGradient(
                stops: stops,
                startPoint: .init(x: x0, y: 0.5),
                endPoint: .init(x: x0 + 3, y: 0.5)
            )
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        ChromaText(text: "12", font: .system(size: 40, weight: .bold))
        ChromaText(text: "Never forget a problem", font: .system(size: 24, weight: .bold))
        ChromaText(
            text: "Your feed fills in from your first solve.",
            font: .system(size: 14, weight: .regular),
            restingColor: .white.opacity(0.6),
            delay: 0.3
        )
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
