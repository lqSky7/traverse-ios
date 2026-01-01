import SwiftUI
import Glur

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingLogoutConfirmation = false
    @State private var showingImportPalette = false
    @State private var paletteInput = ""
    @State private var importError: String?
    @State private var isLoading = false
    @State private var showingDreamPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Profile Section with Blurred Background
                    if let user = authViewModel.currentUser {
                        ZStack {
                            // Blurred profile photo background
                            Group {
                                if let imageUrl = user.profileImageURL, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Image("def_user")
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
                                } else {
                                    Image("def_user")
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 260)
                            .clipped()
                            .glur(radius: 12.0, offset: 0.2, interpolation: 0.5, direction: .down)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            
                            // Dark overlay for legibility
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.4))
                            
                            // Content
                            VStack(spacing: 16) {
                                // Profile Image
                                Group {
                                    if let imageUrl = user.profileImageURL, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            default:
                                                Image("def_user")
                                                    .resizable()
                                                    .scaledToFill()
                                            }
                                        }
                                    } else {
                                        Image("def_user")
                                            .resizable()
                                            .scaledToFill()
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                                
                                // User Info
                                VStack(spacing: 4) {
                                    Text(user.username)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)

                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                // Stats Row
                                HStack(spacing: 32) {
                                    VStack(spacing: 4) {
                                        Text("\(user.currentStreak)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(paletteManager.color(at: 0))
                                        Text("Day Streak")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    
                                    Divider()
                                        .frame(height: 30)
                                        .background(Color.white.opacity(0.3))
                                    
                                    VStack(spacing: 4) {
                                        Text("\(user.totalXp)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(paletteManager.color(at: 1))
                                        Text("Total XP")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .padding(.vertical, 24)
                            .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    
                    // Bento Settings Grid
                    BentoSettingsGrid(
                        paletteManager: paletteManager,
                        showingEditProfile: $showingEditProfile,
                        showingChangePassword: $showingChangePassword,
                        showingDeleteAccount: $showingDeleteAccount,
                        showingLogoutConfirmation: $showingLogoutConfirmation,
                        showingImportPalette: $showingImportPalette,
                        showingDreamPicker: $showingDreamPicker
                    )
                }
                .padding(.vertical)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingImportPalette) {
                ImportPaletteView(paletteInput: $paletteInput, importError: $importError, onImport: {
                    if paletteManager.importPalette(from: paletteInput) {
                        showingImportPalette = false
                        paletteInput = ""
                        importError = nil
                    } else {
                        importError = "Invalid palette format. Please provide a coolors.co URL or SCSS colors."
                    }
                })
            }
            .sheet(isPresented: $showingDreamPicker) {
                HuePicker()
                    .presentationDetents([.medium])
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        await handleLogout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .disabled(isLoading)
        }
    }


    private func handleLogout() async {
        isLoading = true
        do {
            try await authViewModel.logout()
        } catch {
            // Error handled in view model
        }
        isLoading = false
    }
}

// MARK: - Import Palette View
struct ImportPaletteView: View {
    @Binding var paletteInput: String
    @Binding var importError: String?
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Import a custom color palette from coolors.co or paste SCSS color variables.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Palette Input") {
                    TextEditor(text: $paletteInput)
                        .frame(minHeight: 150)
                        .font(.system(.body, design: .monospaced))

                    if let error = importError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coolors.co URL:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("https://coolors.co/ff6ad5-c774e8-ad8cff-8795e8-94d0ff")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Divider()
                            .padding(.vertical, 4)

                        Text("SCSS Format:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("""
                        $color1: #ff6ad5ff;
                        $color2: #c774e8ff;
                        $color3: #ad8cffff;
                        $color4: #8795e8ff;
                        $color5: #94d0ffff;
                        """)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Import Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                    }
                    .disabled(paletteInput.isEmpty)
                }
            }
        }
    }
}
