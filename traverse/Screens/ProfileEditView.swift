import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var visibility: String = "public"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Picker("Profile Visibility", selection: $visibility) {
                        Text("Public").tag("public")
                        Text("Private").tag("private")
                        Text("Friends").tag("friends")
                    }
                }
                
                Section {
                    // Error/Success Messages
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
                            await saveProfile()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .font(.headline)
                                .foregroundStyle(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.primary)
                    .cornerRadius(.infinity)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserData()
            }
        }
    }
    
    private func loadUserData() {
        if let user = authViewModel.currentUser {
            email = user.email
            visibility = user.visibility
        }
    }
    
    private func saveProfile() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await authViewModel.updateProfile(
                email: email,
                timezone: TimeZone.current.identifier,
                visibility: visibility
            )
            successMessage = "Profile updated successfully"
            
            // Dismiss after a short delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(AuthViewModel())
}
