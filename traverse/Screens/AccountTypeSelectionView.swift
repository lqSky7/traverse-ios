//
//  AccountTypeSelectionView.swift
//  traverse
//

import SwiftUI

struct AccountTypeSelectionView: View {
    let onSelect: (AccountType) -> Void
    @State private var buttonTapped = 0
    
    var body: some View {
        ZStack {
            // Gradient background
            ZStack {
                RadialGradient(
                    colors: [Color.blue, .clear],
                    center: .bottom,
                    startRadius: 300,
                    endRadius: 500
                )
                
                RadialGradient(
                    colors: [Color.cyan, .clear],
                    center: .bottom,
                    startRadius: 200,
                    endRadius: 450
                )
                
                RadialGradient(
                    colors: [Color.purple, .clear],
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
                        .foregroundStyle(.black.opacity(0.8))
                        .foregroundStyle(.ultraThinMaterial)
                        .multilineTextAlignment(.center)
                    
                    Text("The Complete Learning Ecosystem")
                        .foregroundColor(.black.opacity(0.4))
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
        .background(.white)
        .ignoresSafeArea(.container)
    }
}

