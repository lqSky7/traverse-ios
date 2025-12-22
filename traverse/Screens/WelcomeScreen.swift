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
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: backTapped)
                    .glassEffect(.regular.interactive(), in: .circle)
                    Spacer()
                }
                .padding(.horizontal, 24)
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
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .frame(width: 50)
                
                Text(title)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                
                Text(description)
                    .foregroundStyle(.white.opacity(0.7))
                
                Button(action: {
                    action()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.black)
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

