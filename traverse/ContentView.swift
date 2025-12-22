//
//  ContentView.swift
//  traverse
//
//  Created by ca5 on 22/12/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var accountType: AccountType?
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.combined(with: .offset(y: 20)))
            } else if let accountType = accountType {
                if accountType == .newAccount {
                    SignUpView(authViewModel: authViewModel, onBack: { 
                        withAnimation(.smooth(duration: 0.5)) {
                            self.accountType = nil 
                        }
                    })
                    .transition(.opacity.combined(with: .offset(y: 20)))
                } else {
                    SignInView(authViewModel: authViewModel, onBack: { 
                        withAnimation(.smooth(duration: 0.5)) {
                            self.accountType = nil 
                        }
                    })
                    .transition(.opacity.combined(with: .offset(y: 20)))
                }
            } else {
                AccountTypeSelectionView(onSelect: { type in
                    withAnimation(.smooth(duration: 0.5)) {
                        accountType = type
                    }
                })
                .transition(.opacity.combined(with: .offset(y: 20)))
            }
        }
        .animation(.smooth(duration: 0.8), value: authViewModel.isAuthenticated)
    }
}

enum AccountType {
    case newAccount
    case existingAccount
}

struct SignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onBack: () -> Void
    
    var body: some View {
        OnboardingFlow(
            title: "Welcome to\nTraverse",
            description: "We can't wait to have you on board",
            logo: "logo",
            startGradient: (.blue, .cyan, .purple),
            onBack: onBack,
            carousel: [
                .init(text: "Track", image: "spend"),
                .init(text: "Grow", image: "invest"),
                .init(text: "Achieve", image: "earn"),
                .init(text: "Connect", image: "pay"),
                .init(text: "Progress", image: "save"),
            ],
            form: [
                FormStep(
                    icon: "person.fill",
                    title: "Username",
                    description: "Choose a unique username for your account.",
                    type: .inputField(placeholder: "Enter username", keyboardType: .default),
                    lightGradient: (.blue, .blue, .blue),
                    darkGradient: (.purple, .purple, .purple),
                    onSubmit: { answer in
                        authViewModel.username = answer
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                ),
                FormStep(
                    icon: "envelope.fill",
                    title: "Email",
                    description: "We'll use this to keep your account secure and send you updates.",
                    type: .inputField(placeholder: "Enter your email", keyboardType: .emailAddress),
                    lightGradient: (.cyan, .cyan, .cyan),
                    darkGradient: (.indigo, .indigo, .indigo),
                    onSubmit: { answer in
                        authViewModel.email = answer
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                ),
                FormStep(
                    icon: "lock.fill",
                    title: "Password",
                    description: "Create a strong password to protect your account.",
                    type: .inputField(placeholder: "Enter password", keyboardType: .default),
                    lightGradient: (.purple, .purple, .purple),
                    darkGradient: (.pink, .pink, .pink),
                    onSubmit: { answer in
                        authViewModel.password = answer
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                )
            ],
            completion: CompletionStep(
                title: "Creating your account",
                description: "Hold tight while we set everything up",
                loadingTitle: "Setting up your profile",
                loadingDescription: "Personalizing your experience...",
                completionTitle: "You're all set!",
                completionDescription: "Welcome to Traverse. Let's start your journey!",
                onSubmit: {
                    do {
                        try await authViewModel.register()
                    } catch {
                        print("Registration error: \(error.localizedDescription)")
                    }
                },
                onFetchData: {
                    try await authViewModel.fetchCurrentUser()
                },
                onComplete: {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for smoother transition
                        authViewModel.isAuthenticated = true
                    }
                }
            )
        )
    }
}

// Placeholder for the main app view after onboarding
struct MainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Traverse!")
                    .font(.largeTitle)
                    .bold()
                
                if let user = authViewModel.currentUser {
                    VStack(spacing: 10) {
                        Text("Hello, \(user.username)!")
                            .font(.title2)
                        
                        Text("Email: \(user.email)")
                            .foregroundStyle(.secondary)
                        
                        Text("Current Streak: \(user.currentStreak) days")
                        Text("Total XP: \(user.totalXp)")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        try? await authViewModel.logout()
                    }
                }) {
                    Text("Logout")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Traverse")
        }
    }
}

#Preview {
    ContentView()
}
