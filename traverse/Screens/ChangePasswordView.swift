import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Change Password") {
                    SecureField("Current Password", text: $currentPassword)
                    
                    SecureField("New Password", text: $newPassword)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                    
                    // Password Strength Indicator
                    if !newPassword.isEmpty {
                        HStack {
                            Text("Password Strength")
                                .font(.caption)
                            
                            Spacer()
                            
                            ForEach(0..<4) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index < passwordStrength ? strengthColor : Color.gray.opacity(0.3))
                                    .frame(width: 20, height: 4)
                            }
                            
                            Text(strengthText)
                                .font(.caption)
                                .foregroundStyle(strengthColor)
                        }
                    }
                }
                
                Section {
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .foregroundStyle(.green)
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await changePassword()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Change Password")
                                .font(.headline)
                                .foregroundStyle(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.primary)
                    .cornerRadius(.infinity)
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    private var passwordStrength: Int {
        var strength = 0
        if newPassword.count >= 8 { strength += 1 }
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil { strength += 1 }
        if newPassword.rangeOfCharacter(from: .decimalDigits) != nil { strength += 1 }
        if newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { strength += 1 }
        return strength
    }
    
    private var strengthColor: Color {
        switch passwordStrength {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }
    
    private var strengthText: String {
        switch passwordStrength {
        case 0...1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        default: return ""
        }
    }
    
    private func changePassword() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            isLoading = false
            return
        }
        
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            isLoading = false
            return
        }
        
        do {
            try await authViewModel.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            successMessage = "Password changed successfully"
            
            // Clear fields and dismiss
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(AuthViewModel())
}
