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
