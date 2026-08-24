import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paletteManager = ColorPaletteManager.shared

    @State private var username: String = ""
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var isRequesting = false
    @State private var isConfirming = false
    @State private var requestMessage: String?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resetStatus: ResetStatus = .idle

    private enum ResetStatus {
        case idle
        case emailSent
        case noEmail
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    if let requestMessage {
                        Text(requestMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task { await requestResetCode() }
                    } label: {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("Send Reset Code")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .tint(paletteManager.color(at: 2))
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if resetStatus == .emailSent {
                    Section("Reset Code") {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                    }

                    Section("New Password") {
                        SecureField("New Password", text: $newPassword)
                        SecureField("Confirm Password", text: $confirmPassword)
                    }

                    Section {
                        Button {
                            Task { await confirmReset() }
                        } label: {
                            if isConfirming {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                Text("Reset Password")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .tint(paletteManager.color(at: 1))
                        .buttonStyle(.borderedProminent)
                        .disabled(isConfirming || !isConfirmFormValid)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var isConfirmFormValid: Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedCode.isEmpty &&
            trimmedCode.count == 6 &&
            !newPassword.isEmpty &&
            newPassword == confirmPassword &&
            newPassword.count >= 8
    }

    private func requestResetCode() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }

        isRequesting = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await NetworkService.shared.requestPasswordReset(username: trimmedUsername)
            requestMessage = response.message
            if response.status == "EMAIL_SENT" {
                resetStatus = .emailSent
            } else {
                resetStatus = .noEmail
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isRequesting = false
    }

    private func confirmReset() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else { return }

        isConfirming = true
        errorMessage = nil
        successMessage = nil

        do {
            try await NetworkService.shared.confirmPasswordReset(
                username: trimmedUsername,
                code: trimmedCode,
                newPassword: newPassword
            )
            successMessage = "Password reset successfully. You can sign in now."
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isConfirming = false
    }
}

#Preview {
    PasswordResetView()
}
