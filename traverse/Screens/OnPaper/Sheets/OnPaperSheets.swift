import SwiftUI

struct OnPaperInfoSheet: View {
    let title: String
    let explanation: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Cognito Account Sheet
struct OnPaperAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = OnPaperAPIService.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    
    @State private var isSignUp = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isProcessing = false
    @State private var authError: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if apiService.authToken != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.green)
                            
                            Text("Signed In to OnPaper")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            if let name = apiService.currentUsername {
                                Text("Authenticated User: \(name)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button(action: {
                                HapticManager.shared.selection()
                                apiService.signOut()
                                dismiss()
                            }) {
                                Text("Sign Out")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color(white: 0.15), in: Capsule())
                            }
                            .padding(.top, 12)
                        }
                        .padding(30)
                    } else {
                        VStack(spacing: 16) {
                            Text(isSignUp ? "Create OnPaper Account" : "Sign In to OnPaper")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    TextField("Username", text: $username)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                if isSignUp {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        TextField("Email Address", text: $email)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .keyboardType(.emailAddress)
                                            .foregroundStyle(.white)
                                    }
                                    .padding(12)
                                    .background(Color(UIColor.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    SecureField("Password", text: $password)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            
                            if let error = authError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if let success = successMessage {
                                Text(success)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            
                            Button(action: handleAuth) {
                                if isProcessing {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .font(.headline)
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(paletteManager.selectedPalette.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .disabled(username.isEmpty || password.isEmpty || isProcessing)
                            .padding(.top, 4)
                            
                            Button(action: {
                                withAnimation {
                                    isSignUp.toggle()
                                    authError = nil
                                    successMessage = nil
                                }
                            }) {
                                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.footnote)
                                    .foregroundStyle(paletteManager.selectedPalette.primary)
                            }
                            .padding(.top, 6)
                        }
                        .padding(20)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func handleAuth() {
        HapticManager.shared.selection()
        isProcessing = true
        authError = nil
        successMessage = nil
        
        Task {
            do {
                if isSignUp {
                    try await apiService.registerWithCognito(username: username, email: email, password: password)
                    await MainActor.run {
                        self.isProcessing = false
                        HapticManager.shared.success()
                        dismiss()
                    }
                } else {
                    try await apiService.loginWithCognito(username: username, password: password)
                    await MainActor.run {
                        self.isProcessing = false
                        HapticManager.shared.success()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isProcessing = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - FSRS Flashcard Review Sheet
struct OnPaperFSRSReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = OnPaperAPIService.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    
    var currentCard: OnPaperFSRSCard? {
        if currentIndex < apiService.dueCards.count {
            return apiService.dueCards[currentIndex]
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let card = currentCard {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(paletteManager.selectedPalette.primary)
                                        .frame(
                                            width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(apiService.dueCards.count, 1)),
                                            height: 4
                                        )
                                }
                            }
                            .frame(height: 4)
                            
                            // Header metadata
                            HStack {
                                Text("Card \(currentIndex + 1) of \(apiService.dueCards.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Stability: \(String(format: "%.1f", card.stability))d")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Question Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("RECALL PROMPT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(paletteManager.color(at: 0))
                                    Spacer()
                                    Text("\(card.reps) reps")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(card.prompt ?? card.conceptId ?? card.mistakeId ?? "Assessed Architectural Concept")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                
                                if let concept = card.conceptId {
                                    Text("Focus: \(concept)")
                                        .font(.caption)
                                        .foregroundStyle(paletteManager.color(at: 1))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                            
                            // User's own previous answer
                            if let userAns = card.userAnswer, !userAns.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "quote.opening")
                                            .font(.caption2)
                                            .foregroundStyle(paletteManager.color(at: 2))
                                        Text("YOUR PREVIOUS ANSWER (In your words)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(paletteManager.color(at: 2))
                                    }
                                    
                                    Text(userAns)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .italic()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(white: 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(paletteManager.color(at: 2).opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            
                            if isAnswerRevealed {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("DETAILED EXPLANATION & MENTAL MODEL")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.green)
                                    
                                    Text(card.explanation ?? "Recall core invariant guarantees, boundary edge conditions, state transitions, and memory lifecycle tradeoffs.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .lineSpacing(4)
                                    
                                    if let takeaway = card.keyTakeaway, !takeaway.isEmpty {
                                        Divider()
                                            .background(Color.green.opacity(0.3))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("KEY TAKEAWAY")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                            Text(takeaway)
                                                .font(.footnote.weight(.medium))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(Color.green.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                
                                // Rating Controls (Again, Hard, Good, Easy)
                                VStack(spacing: 8) {
                                    Text("Rate recall precision:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack(spacing: 8) {
                                        Button("Again") { submitRating("Again") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .red))
                                        Button("Hard") { submitRating("Hard") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .orange))
                                        Button("Good") { submitRating("Good") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .blue))
                                        Button("Easy") { submitRating("Easy") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .green))
                                    }
                                }
                                .padding(.top, 8)
                            } else {
                                Button(action: {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isAnswerRevealed = true
                                    }
                                }) {
                                    Text("Reveal Explanation & Mental Model")
                                        .font(.headline)
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(paletteManager.selectedPalette.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .padding(.top, 12)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("Session Complete")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("All due flashcards for today have been reviewed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.white, in: Capsule())
                            .padding(.top, 8)
                    }
                    .padding(40)
                }
            }
            .navigationTitle("Revision Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func submitRating(_ rating: String) {
        guard let card = currentCard else { return }
        HapticManager.shared.selection()
        Task {
            _ = try? await apiService.submitFSRSReview(cardId: card.cardId, rating: rating)
            await MainActor.run {
                withAnimation {
                    isAnswerRevealed = false
                    currentIndex += 1
                }
            }
        }
    }
}

// MARK: - FSRS Rating Button Style
struct FSRSRatingButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

