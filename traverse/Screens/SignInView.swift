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
                        await MainActor.run {
                            authViewModel.username = answer
                        }
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
                        await MainActor.run {
                            authViewModel.password = answer
                        }
                    },
                    forgotPasswordAction: {
                        let username = authViewModel.username
                        Task {
                            do {
                                _ = try await NetworkService.shared.requestPasswordReset(username: username)
                            } catch {
                                print("Forgot password API request failed: \(error)")
                            }
                        }
                        
                        return [
                            FormStep(
                                icon: "envelope.badge.shield.half.filled",
                                title: "Reset Code",
                                description: "We have sent a verification code to your email associated with this username.",
                                type: .inputField(placeholder: "6-digit code", keyboardType: .numberPad),
                                lightGradient: (.orange, .orange, .orange),
                                darkGradient: (.orange, .orange, .orange),
                                onSubmit: { otp in
                                    await MainActor.run {
                                        authViewModel.otpCode = otp
                                    }
                                }
                            ),
                            FormStep(
                                icon: "key.fill",
                                title: "New Password",
                                description: "Enter your new password (minimum 8 characters).",
                                type: .inputField(placeholder: "New Password", keyboardType: .default),
                                lightGradient: (.green, .green, .green),
                                darkGradient: (.green, .green, .green),
                                onSubmit: { newPassword in
                                    guard newPassword.count >= 8 else {
                                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Password must be at least 8 characters"])
                                    }
                                    try await NetworkService.shared.confirmPasswordReset(
                                        username: username,
                                        code: authViewModel.otpCode,
                                        newPassword: newPassword
                                    )
                                    await MainActor.run {
                                        authViewModel.password = newPassword
                                    }
                                }
                            )
                        ]
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
