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
    
    @State private var backTapped = 0
    @State private var continueTapped = 0
    private let hapticManager = HapticManager()
    
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
                            .foregroundStyle(.black)
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
                    hapticManager.playSoftRisingFeedback()
                    action()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.black.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(.white)
                        .cornerRadius(.infinity)
                        
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(42)
        }
    }
}

