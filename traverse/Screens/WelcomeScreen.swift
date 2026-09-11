//
//  WelcomeScreen.swift
//  traverse
//

import SwiftUI

struct WelcomeScreen: View {
    let title: String
    let description: String
    let logo: String
    
    let carousel: [Carousel]
    let onBack: () -> Void
    
    let action: () -> Void
    
    /// WorkOS social providers to surface under the primary CTA. Empty hides the row.
    var socialProviders: [SocialProvider] = []
    var isSocialLoading: Bool = false
    var onSocialLogin: ((SocialProvider) -> Void)? = nil
    
    @State private var backTapped = 0
    @State private var continueTapped = 0
    @State private var socialTapped = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Back button
            VStack {
                HStack {
                    Button(action: {
                        backTapped += 1
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(12)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: backTapped)
                    .glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                Spacer()
            }
            
            VStack {
                TextCarousel(
                    items: carousel
                )
                .frame(height: 240)
                .onAppear {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
            .padding(.top, 120)
            .padding(.horizontal, 48)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            
            VStack(alignment: .leading, spacing: 20) {
                
                Text(title)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.8))
                    
                
                Text(description)
                    .foregroundStyle(.white.opacity(0.6))
                    .foregroundStyle(.ultraThinMaterial)
                
                Button(action: {
                    continueTapped += 1
                    HapticManager.shared.playSoftRisingFeedback()
                    action()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .applyWelcomeGlassButton()
                
                if !socialProviders.isEmpty, let onSocialLogin {
                    SocialLoginButtons(
                        providers: socialProviders,
                        isLoading: isSocialLoading,
                        onSelect: { provider in
                            socialTapped += 1
                            onSocialLogin(provider)
                        }
                    )
                    .sensoryFeedback(.impact(weight: .light), trigger: socialTapped)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(42)
        }
    }
}

// MARK: - WorkOS Social Sign-In Row

/// Row of circular glass buttons for Google / GitHub / Apple sign-in via WorkOS.
struct SocialLoginButtons: View {
    let providers: [SocialProvider]
    var isLoading: Bool = false
    let onSelect: (SocialProvider) -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                
                Text("or continue with")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize()
                
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 14) {
                    ForEach(providers) { provider in
                        Button {
                            onSelect(provider)
                        } label: {
                            Image(systemName: provider.systemImage)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                        }
                        .disabled(isLoading)
                        .applySocialGlassCircle()
                        .accessibilityLabel("Continue with \(provider.displayName)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - View Extension for Social Glass Circle
extension View {
    @ViewBuilder
    func applySocialGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: .circle)
        } else {
            self
                .background(Color.white.opacity(0.15), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
    }
}

