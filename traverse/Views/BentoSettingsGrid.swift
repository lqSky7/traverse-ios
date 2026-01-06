//
//  BentoSettingsGrid.swift
//  traverse
//

import SwiftUI

// MARK: - Bento Settings Grid
struct BentoSettingsGrid: View {
    @ObservedObject var paletteManager: ColorPaletteManager
    
    // Sheet bindings
    @Binding var showingEditProfile: Bool
    @Binding var showingChangePassword: Bool
    @Binding var showingDeleteAccount: Bool
    @Binding var showingLogoutConfirmation: Bool
    @Binding var showingImportPalette: Bool
    @Binding var showingDreamPicker: Bool
    
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
            
            // Row 3: Security | Logout
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
                
                // Logout Tile
                Button {
                    mediumFeedback.impactOccurred()
                    showingLogoutConfirmation = true
                } label: {
                    BentoCell(alignment: .bottomLeading) {
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.red)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logout")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Sign out")
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
            
            // Row 4: Delete Account (full width)
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
            showingDreamPicker: .constant(false)
        )
        .padding(.vertical)
    }
    .background(Color(.systemBackground))
}
