//
//  AccountTypeSelectionView.swift
//  traverse
//

import SwiftUI

struct AccountTypeSelectionView: View {
    let onSelect: (AccountType) -> Void
    @State private var buttonTapped = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    private var lightGradient: (Color, Color, Color) {
        (Color.blue, Color.cyan, Color.purple)
    }
    
    private var darkGradient: (Color, Color, Color) {
        (Color(red: 0.3, green: 0, blue: 0.6), Color(red: 0.5, green: 0, blue: 0.8), Color(red: 0.2, green: 0, blue: 0.4))
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            ZStack {
                RadialGradient(
                    colors: [colorScheme == .dark ? darkGradient.0 : lightGradient.0, .clear],
                    center: .bottom,
                    startRadius: 300,
                    endRadius: 500
                )
                
                RadialGradient(
                    colors: [colorScheme == .dark ? darkGradient.1 : lightGradient.1, .clear],
                    center: .bottom,
                    startRadius: 200,
                    endRadius: 450
                )
                
                RadialGradient(
                    colors: [colorScheme == .dark ? darkGradient.2 : lightGradient.2, .clear],
                    center: .init(x: 0.5, y: 1.2),
                    startRadius: 80,
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
                        .foregroundStyle(.white.opacity(0.8))
                        .foregroundStyle(.ultraThinMaterial)
                        .multilineTextAlignment(.center)
                    
                    Text("The Complete Learning Ecosystem")
                        .foregroundColor(.white.opacity(0.6))
                        .foregroundStyle(.ultraThinMaterial)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Account type buttons
                VStack(spacing: 16) {
                    Button(action: {
                        buttonTapped += 1
                        onSelect(.newAccount)
                    }) {
                        Text("Create New Account")
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.black.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(.white)
                            .cornerRadius(.infinity)
                    }
                    .sensoryFeedback(.pathComplete, trigger: buttonTapped)
                    
                    Button(action: {
                        buttonTapped += 1
                        onSelect(.existingAccount)
                    }) {
                        Text("Already Have an Account?")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(.white.opacity(0.2))
                            .cornerRadius(.infinity)
                    }
                    .sensoryFeedback(.pathComplete, trigger: buttonTapped)
                }
                .padding(.horizontal, 42)
                .padding(.bottom, 60)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.container)
    }
}

