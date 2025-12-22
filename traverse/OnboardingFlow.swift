//
//  OnboardingFlow.swift
//  traverse
//

import SwiftUI

struct OnboardingFlow: View {
    let title: String
    let description: String
    let logo: String
    var startGradient: (Color, Color, Color)?
    let onBack: () -> Void
    
    let carousel: [Carousel]
    let form: [FormStep]
    let completion: CompletionStep
    
    @FocusState private var keyboardShown: Bool
    @State private var showGradient = true
    @State private var continueTapped = 0
    
    @State private var phase = 0
    @State private var gradient: (Color, Color, Color) = (
        Color(red: 0.004, green: 0.373, blue: 1, opacity: 1),
        Color(red: 0, green: 0.875, blue: 1, opacity: 1),
        Color(red: 0.004, green: 0.678, blue: 1, opacity: 1)
    )
    
    var body: some View {
        ZStack {
            if showGradient {
                ZStack {
                    RadialGradient(
                        colors: [gradient.0, .clear],
                        center: phase > 0 ? .top : .bottom,
                        startRadius: phase > 0 ? 0 : 300,
                        endRadius: 500
                    )
                    .animation(.smooth.delay(0.65), value: phase > 0)
                    
                    RadialGradient(
                        colors: [gradient.1, .clear],
                        center: phase > 0 ? .top : .bottom,
                        startRadius: phase > 0 ? 50 : 200,
                        endRadius: 450
                    )
                    .animation(.smooth.delay(0.52), value: phase > 0)
                    
                    RadialGradient(
                        colors: [gradient.2, .clear],
                        center: phase > 0 ? .init(x: 0.5, y: -0.2) : .bottom,
                        startRadius: phase > 0 ? 0 : 80,
                        endRadius: 350
                    )
                    .animation(.smooth.delay(0.4), value: phase > 0)
                }
                .transition(.move(edge: .top))
            }
            
            VStack {
                if phase == 0 {
                    WelcomeScreen(
                        title: title,
                        description: description,
                        logo: logo,
                        carousel: carousel,
                        onBack: onBack,
                        action: {
                            continueTapped += 1
                            
                            withAnimation(.smooth(duration: 0.7)) {
                                phase = 1
                                
                                if let formStartGradient = form.first?.gradient {
                                    gradient = formStartGradient
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.smooth) {
                                        phase = 2
                                    }
                                }
                            }
                        }
                    )
                    .transition(
                        .opacity
                            .combined(with: .offset(y: 20))
                    )
                }
                
                if phase == 2 {
                    MultiStepForm(
                        steps: form,
                        completionStep: completion,
                        gradient: $gradient,
                        keyboardShown: $keyboardShown,
                        onBack: {
                            withAnimation(.smooth(duration: 0.5)) {
                                phase = 0
                            }
                        },
                    )
                    .transition(
                        .opacity
                            .combined(with: .offset(y: 20))
                    )
                }
            }
        }
        .background(.white)
        .ignoresSafeArea(.container)
        .onAppear {
            if let startGradient {
                gradient = startGradient
            }
        }
        .onChange(of: keyboardShown) { _, newValue in
            withAnimation(.smooth) {
                showGradient = !newValue
            }
        }
    }
}

