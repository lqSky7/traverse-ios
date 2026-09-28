//
//  BentoSettingsGrid.swift
//  traverse
//

import SwiftUI

// MARK: - Bento Settings Grid
struct BentoSettingsGrid: View {
    @ObservedObject var paletteManager: ColorPaletteManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Sheet bindings
    @Binding var showingEditProfile: Bool
    @Binding var showingChangePassword: Bool
    @Binding var showingDeleteAccount: Bool
    @Binding var showingLogoutConfirmation: Bool
    @Binding var showingImportPalette: Bool
    @Binding var showingDreamPicker: Bool
    @Binding var showingFreezeShop: Bool
    @Binding var showingShaderDemos: Bool
    @Binding var showingNotificationSettings: Bool
    @Binding var showingActiveSessions: Bool
    
    // Haptic generators
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Palette | Hue Picker
            HStack(spacing: 0) {
                // Palette Tile with Selection Menu
                Menu {
                    ForEach(paletteManager.allAvailablePalettes) { palette in
                        Button {
                            lightFeedback.impactOccurred()
                            paletteManager.selectPalette(palette)
                        } label: {
                            HStack {
                                Text(palette.name)
                                if palette.id == paletteManager.selectedPalette.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        // Color circles preview
                        HStack(spacing: 6) {
                            ForEach(paletteManager.selectedPalette.swiftUIColors.prefix(4), id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Palette")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(paletteManager.selectedPalette.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
                
                // Vertical Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1)
                
                // Hue Picker Tile
                Button {
                    mediumFeedback.impactOccurred()
                    showingDreamPicker = true
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(paletteManager.color(at: 1))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hue Picker")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Pick a vibe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
            }
            .frame(height: 140)
            
            // Horizontal Divider
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
            
            // Row 2: Import | Profile
            HStack(spacing: 0) {
                // Import Tile
                Button {
                    mediumFeedback.impactOccurred()
                    showingImportPalette = true
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(paletteManager.color(at: 2))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Custom palette")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
                
                // Vertical Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1)
                
                // Profile Tile
                Button {
                    mediumFeedback.impactOccurred()
                    showingEditProfile = true
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(paletteManager.color(at: 3))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Profile")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Edit details")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
            }
            .frame(height: 140)
            
            // Horizontal Divider
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
            
            // Row 3: Security | Active sessions
            HStack(spacing: 0) {
                // Security Tile
                Button {
                    mediumFeedback.impactOccurred()
                    showingChangePassword = true
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(paletteManager.color(at: 4))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Security")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Change password")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
                
                // Vertical Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1)
                
                settingsTile(
                    title: "Sessions",
                    subtitle: "Manage signed-in devices",
                    systemImage: "laptopcomputer.and.iphone",
                    tint: paletteManager.color(at: 1)
                ) { showingActiveSessions = true }
            }
            .frame(height: 140)

            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)

            // Two-column action rows preserve the existing bento tiles while
            // making the settings section shorter and easier to scan.
            HStack(spacing: 0) {
                settingsTile(
                    title: "Logout",
                    subtitle: "Sign out of this device",
                    systemImage: "rectangle.portrait.and.arrow.right.fill",
                    tint: .red
                ) { showingLogoutConfirmation = true }

                Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

                NavigationLink {
                    BillingView()
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(paletteManager.color(at: 2))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Billing").font(.headline).fontWeight(.semibold)
                            Text("Plan and payments")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
                .buttonStyle(BentoCellButtonStyle())
            }
            .frame(height: 140)

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)

            HStack(spacing: 0) {
                settingsTile(
                    title: "Notifications",
                    subtitle: "Alerts and quiet hours",
                    systemImage: "bell.badge",
                    tint: paletteManager.color(at: 1)
                ) { showingNotificationSettings = true }

                Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

                settingsTile(
                    title: "Freeze Shop",
                    subtitle: "Protect your streak",
                    systemImage: "snowflake",
                    tint: paletteManager.color(at: 0)
                ) { showingFreezeShop = true }
            }
            .frame(height: 140)

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)

            HStack(spacing: 0) {
                settingsTile(
                    title: "Calendar",
                    subtitle: "Sync revisions",
                    systemImage: "calendar.badge.plus",
                    tint: paletteManager.color(at: 1),
                    action: subscribeToCalendar
                )

                Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

                settingsTile(
                    title: "Shader demos",
                    subtitle: "Metal and glass studies",
                    systemImage: "sparkles.tv.fill",
                    tint: paletteManager.color(at: 2)
                ) { showingShaderDemos = true }
            }
            .frame(height: 140)

            // Keep account deletion visually separate from everyday settings.
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
            
            // Row 5: Delete Account (full width)

            Button {
                mediumFeedback.impactOccurred()
                showingDeleteAccount = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.red)
                    
                    Text("Delete Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(BentoCellButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        .padding(.horizontal)
        .onAppear {
            lightFeedback.prepare()
            mediumFeedback.prepare()
        }
    }

    private func settingsTile(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            mediumFeedback.impactOccurred()
            action()
        } label: {
            BentoCell(alignment: .bottomLeading) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(tint)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(BentoCellButtonStyle())
    }
    
    private func subscribeToCalendar() {
        guard let user = authViewModel.currentUser else { return }
        let username = user.username
        let token = user.calendarToken ?? ""
        guard let url = NetworkService.shared.calendarFeedURL(username: username, token: token) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - Bento Cell Component
struct BentoCell<IconContent: View, LabelContent: View>: View {
    let alignment: Alignment
    @ViewBuilder let icon: () -> IconContent
    @ViewBuilder let label: () -> LabelContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            icon()
            Spacer()
            label()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .contentShape(Rectangle())
    }
}

// MARK: - Bento Cell Button Style
struct BentoCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.white.opacity(0.05) : Color.clear
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        BentoSettingsGrid(
            paletteManager: ColorPaletteManager.shared,
            showingEditProfile: .constant(false),
            showingChangePassword: .constant(false),
            showingDeleteAccount: .constant(false),
            showingLogoutConfirmation: .constant(false),
            showingImportPalette: .constant(false),
            showingDreamPicker: .constant(false),
            showingFreezeShop: .constant(false),
            showingShaderDemos: .constant(false),
            showingNotificationSettings: .constant(false),
            showingActiveSessions: .constant(false)
        )
        .padding(.vertical)
    }
    .background(Color(.systemBackground))
    .environmentObject(AuthViewModel())
}
