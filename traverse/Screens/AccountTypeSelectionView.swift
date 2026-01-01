//
//  AccountTypeSelectionView.swift
//  traverse
//

import SwiftUI

struct AccountTypeSelectionView: View {
    let onSelect: (AccountType) -> Void
    @State private var buttonTapped = 0
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Gradient background using palette colors
            ZStack {
                RadialGradient(
                    colors: [paletteManager.color(at: 0).opacity(0.6), .clear],
                    center: .topLeading,
                    startRadius: 100,
                    endRadius: 400
                )
                
                RadialGradient(
                    colors: [paletteManager.color(at: 1).opacity(0.5), .clear],
                    center: .bottomTrailing,
                    startRadius: 150,
                    endRadius: 450
                )
                
                RadialGradient(
                    colors: [paletteManager.color(at: 2).opacity(0.4), .clear],
                    center: .bottom,
                    startRadius: 50,
                    endRadius: 350
                )
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 20) {
                    Image("logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 80)
                        .foregroundStyle(.primary)
                    
                    Text("Welcome to\nTraverse")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("The Complete Learning Ecosystem")
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Account type buttons with liquid glass
                VStack(spacing: 16) {
                    Button(action: {
                        buttonTapped += 1
                        onSelect(.newAccount)
                    }) {
                        Text("Create New Account")
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    }
                    .sensoryFeedback(.pathComplete, trigger: buttonTapped)
                    .applyWelcomeGlassButton()
                    
                    Button(action: {
                        buttonTapped += 1
                        onSelect(.existingAccount)
                    }) {
                        Text("Already Have an Account?")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    }
                    .sensoryFeedback(.pathComplete, trigger: buttonTapped)
                    .applyWelcomeGlassButton()
                }
                .padding(.horizontal, 42)
                .padding(.bottom, 60)
            }
        }
        .background(Color.black)
        .ignoresSafeArea(.container)
    }
}

// MARK: - View Extension for Welcome Glass Button
extension View {
    @ViewBuilder
    func applyWelcomeGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: .capsule)
        } else {
            self
                .background(.white.opacity(0.15))
                .cornerRadius(.infinity)
        }
    }
}

