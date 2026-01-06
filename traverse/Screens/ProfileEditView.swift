import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
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
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Save Changes")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .tint(paletteManager.selectedPalette.primary)
                    .buttonStyle(.borderedProminent)
                    .modifier(LiquidGlassCapsuleButton())
                    .disabled(isLoading)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
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
