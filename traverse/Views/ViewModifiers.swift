//
//  ViewModifiers.swift
//  traverse
//

import SwiftUI

// MARK: - Liquid Glass Capsule Button Modifier
struct LiquidGlassCapsuleButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Liquid Glass Card Modifier
struct LiquidGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Liquid Glass Button Modifier
struct LiquidGlassButtonModifier: ViewModifier {
    let tintColor: Color?
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tintColor = tintColor {
                content
                    .tint(tintColor)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
            } else {
                content
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
            }
        } else {
            if let tintColor = tintColor {
                content
                    .background(tintColor, in: RoundedRectangle(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Toolbar Scroll Minimization
extension View {
    @ViewBuilder
    func toolbarScrollMinimization() -> some View {
        if #available(iOS 27.0, *) {
            self.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        } else {
            self
        }
    }
}

// MARK: - Safe layout maths

extension CGFloat {
    /// Width for a progress bar drawn inside a `GeometryReader`, guaranteed to be a
    /// value SwiftUI will accept.
    ///
    /// Two separate traps make the naive `max(track * fraction, minimum)` wrong:
    ///
    /// 1. A `GeometryReader` reports `.zero` on its first layout pass, so a cell size
    ///    derived by subtracting fixed insets comes out **negative**.
    /// 2. `max()` is implemented as `y >= x ? y : x`, so `max(.nan, 12)` returns
    ///    `.nan`, not `12`. A NaN therefore survives the clamp and reaches
    ///    `.frame(width:)`, which is what produces "Invalid frame dimension
    ///    (negative or non-finite)".
    ///
    /// So the guards have to come first, and the clamp last.
    ///
    /// `Swift.min` / `Swift.max` are qualified because inside a `CGFloat` extension
    /// the bare names resolve to `CGFloat.min` / `CGFloat.max`, which are the type's
    /// own bounds rather than the free functions.
    func progressBarWidth(fraction: Double, minimum: CGFloat = 0) -> CGFloat {
        guard isFinite, self > 0 else { return minimum }
        guard fraction.isFinite else { return minimum }
        let raw = self * CGFloat(fraction)
        guard raw.isFinite else { return minimum }
        return Swift.min(Swift.max(raw, minimum), self)
    }
}

extension View {
    /// Prints the laid-out size when a view ends up with a negative or non-finite one.
    ///
    /// The system's own "Invalid frame dimension" message names no view, which makes it
    /// near-impossible to locate in a screen this size. This does name it. It only
    /// observes — `background` does not feed a size back to the parent, so it cannot
    /// change the layout it is measuring.
    func traceInvalidFrame(_ label: String) -> some View {
        background(
            GeometryReader { geometry in
                let size = geometry.size
                let _ = reportInvalidFrame(size, label: label)
                Color.clear
            }
        )
    }
}

private func reportInvalidFrame(_ size: CGSize, label: String) -> Bool {
    let bad = !size.width.isFinite || !size.height.isFinite || size.width < 0 || size.height < 0
    if bad {
        print("[LayoutTrace] invalid size \(size.width) x \(size.height) in \(label)")
    }
    return bad
}
