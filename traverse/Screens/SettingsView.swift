import SwiftUI

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
            Form {
                // User Profile Section
                if let user = authViewModel.currentUser {
                    Section {
                        VStack {
                            if let imageUrl = user.profileImageURL {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 120, height: 120)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundStyle(.blue)
                                    @unknown default:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundStyle(.blue)
                            }

                            VStack(spacing: 4) {
                                Text(user.username)
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)

                        HStack {
                            Text("Streak")
                            Spacer()
                            Text("\(user.currentStreak) days")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Total XP")
                            Spacer()
                            Text("\(user.totalXp)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    Picker("Color Palette", selection: $paletteManager.selectedPalette) {
                        ForEach(paletteManager.allAvailablePalettes, id: \.self) { palette in
                            HStack {
                                HStack(spacing: 3) {
                                    ForEach(palette.colors.prefix(4), id: \.self) { colorHex in
                                        Circle()
                                            .fill(Color(hex: colorHex))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                Text(palette.name)
                            }
                            .tag(palette)
                        }
                    }

                    Button {
                        showingImportPalette = true
                        paletteInput = ""
                        importError = nil
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Import Custom Palette")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showingDreamPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.purple)
                            Text("Pick a Hue, Any Hue")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                // Account Settings
                Section("Account") {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Edit Profile")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button {
                        showingChangePassword = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.blue)
                            Text("Change Password")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                // Danger Zone
                Section("Danger Zone") {
                    Button {
                        showingDeleteAccount = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                            Text("Delete Account")
                        }
                        .foregroundStyle(.red)
                    }

                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                .foregroundStyle(.red)
                            Text("Logout")
                        }
                        .foregroundStyle(.red)
                    }
                }
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
                HuePickerSheet()
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

