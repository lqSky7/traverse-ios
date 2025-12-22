//
//  SignInView.swift
//  traverse
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onBack: () -> Void
    
    var body: some View {
        OnboardingFlow(
            title: "Welcome Back",
            description: "Sign in to continue your journey",
            logo: "logo",
            startGradient: (.purple, .blue, .cyan),
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
                    description: "Enter your username to sign in.",
                    type: .inputField(placeholder: "Enter username", keyboardType: .default),
                    lightGradient: (.purple, .purple, .purple),
                    darkGradient: (.pink, .pink, .pink),
                    onSubmit: { answer in
                        authViewModel.username = answer
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                ),
                FormStep(
                    icon: "lock.fill",
                    title: "Password",
                    description: "Enter your password.",
                    type: .inputField(placeholder: "Enter password", keyboardType: .default),
                    lightGradient: (.blue, .blue, .blue),
                    darkGradient: (.indigo, .indigo, .indigo),
                    onSubmit: { answer in
                        authViewModel.password = answer
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                )
            ],
            completion: CompletionStep(
                title: "Signing you in",
                description: "Hold tight, we're getting everything ready",
                loadingTitle: "Fetching your data",
                loadingDescription: "Almost there, loading your profile...",
                completionTitle: "Welcome back!",
                completionDescription: "Let's continue your journey!",
                onSubmit: {
                    try await authViewModel.login(username: authViewModel.username, password: authViewModel.password)
                },
                onFetchData: {
                    // Fetch current user first
                    try await authViewModel.fetchCurrentUser()
                    
                    // Fetch and store all required data using DataManager
                    if let username = authViewModel.currentUser?.username {
                        try await DataManager.shared.fetchAllData(username: username)
                    }
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
