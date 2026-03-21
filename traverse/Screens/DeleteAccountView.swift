import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var password: String = ""
    @State private var confirmationText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Delete Account")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    
                    Text("This action cannot be undone. Your account will be marked for deletion and you have 7 days to recover it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("What happens when you delete your account:") {
                    warningItem(icon: "lock.fill", text: "Your account will be inaccessible immediately")
                    warningItem(icon: "clock.fill", text: "You have 7 days to recover your account")
                    warningItem(icon: "trash.fill", text: "After 7 days, all data will be permanently deleted")
                }
                
                Section("Confirm Your Password") {
                    SecureField("Enter your password", text: $password)
                }
                
                Section("Type 'DELETE' to confirm") {
                    TextField("Type DELETE", text: $confirmationText)
                        .autocapitalization(.allCharacters)
                }
                
                Section {
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Delete My Account")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    .modifier(LiquidGlassCapsuleButton())
                    .disabled(isLoading || !isFormValid)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                
                Section {
                    Text("Need to recover your account?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("You can recover within 7 days by logging in again")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Final Confirmation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you absolutely sure you want to delete your account? This cannot be undone and you will lose all your data after 7 days.")
            }
        }
    }
    
    private func warningItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.red)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    private var isFormValid: Bool {
        !password.isEmpty && confirmationText.uppercased() == "DELETE"
    }
    
    private func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authViewModel.deleteAccount(password: password)
            // Account deleted successfully - the view model will handle logout
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    DeleteAccountView()
        .environmentObject(AuthViewModel())
}
