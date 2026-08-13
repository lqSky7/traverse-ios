import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    @State private var paletteInput = ""
    @State private var customColor = Color.blue
    @State private var email = ""
    @State private var timezone = TimeZone.current.identifier
    @State private var visibility = "public"
    @State private var maxDailyReviews = 20
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var deletePassword = ""
    @State private var freezeCount = 1
    @State private var giftUsername = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileHeader
                paletteSettings
                accountSettings
                freezeShop
                dangerZone
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .onAppear {
            email = appState.user?.email ?? ""
            timezone = appState.user?.timezone ?? TimeZone.current.identifier
            visibility = appState.user?.visibility ?? "public"
            maxDailyReviews = appState.user?.maxDailyReviews ?? 20
        }
    }

    private var profileHeader: some View {
        ThemedCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: paletteManager.streakGradientColors(for: appState.user?.currentStreak ?? 0), startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(String(appState.user?.username.prefix(1).uppercased() ?? "T"))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.user?.username ?? "Traverse")
                        .font(.largeTitle.weight(.bold))
                    Text(appState.user?.email ?? "No email")
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("\(appState.user?.currentStreak ?? 0) day streak")
                        Text("•")
                        Text("\(appState.user?.totalXp ?? 0) XP")
                    }
                    .font(.headline)
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                }
                Spacer()
                Button("Logout") {
                    Task { await appState.logout() }
                }
            }
        }
    }

    private var paletteSettings: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Appearance")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Toggle("Dark Mode", isOn: $paletteManager.isDarkMode)
                        .toggleStyle(.switch)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                    ForEach(paletteManager.allAvailablePalettes) { palette in
                        Button {
                            paletteManager.selectPalette(palette)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(palette.name)
                                        .font(.headline)
                                    PaletteStrip(palette: palette)
                                }
                                Spacer()
                                if palette == paletteManager.selectedPalette {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Palette")
                            .font(.headline)
                        TextEditor(text: $paletteInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.2)))
                        Button("Import Coolors / SCSS / Hex List") {
                            if !paletteManager.importPalette(from: paletteInput) {
                                appState.errorMessage = "Invalid palette format. Paste a coolors.co URL, SCSS variables, or a comma-separated hex list."
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick Your Hue")
                            .font(.headline)
                        ColorPicker("Base color", selection: $customColor, supportsOpacity: false)
                        Button("Generate Custom Palette") {
                            paletteManager.createPalette(from: customColor)
                        }
                    }
                    .frame(width: 240, alignment: .topLeading)
                }
            }
        }
    }

    private var accountSettings: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
            ThemedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile")
                        .font(.title3.weight(.bold))
                    TextField("Email", text: $email)
                    TextField("Timezone", text: $timezone)
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag("public")
                        Text("Friends").tag("friends")
                        Text("Private").tag("private")
                    }
                    Stepper("Max daily reviews: \(maxDailyReviews)", value: $maxDailyReviews, in: 1...100)
                    Button("Save Profile") {
                        Task {
                            await appState.updateProfile(email: email, timezone: timezone, visibility: visibility, maxDailyReviews: maxDailyReviews)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            ThemedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Password")
                        .font(.title3.weight(.bold))
                    SecureField("Current password", text: $currentPassword)
                    SecureField("New password", text: $newPassword)
                    Button("Change Password") {
                        Task { await appState.changePassword(current: currentPassword, new: newPassword) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var freezeShop: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Freeze Shop")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(appState.freezeInfo?.availableFreezes ?? 0) available")
                        .foregroundStyle(Color(red: 0.31, green: 0.76, blue: 0.97))
                        .font(.headline)
                }
                HStack(spacing: 20) {
                    Stepper("Count: \(freezeCount)", value: $freezeCount, in: 1...10)
                    Text("Purchase cost \(appState.freezeInfo?.costs.purchase ?? 0) XP each")
                        .foregroundStyle(.secondary)
                    Button("Purchase") {
                        Task { await appState.purchaseFreezes(count: freezeCount) }
                    }
                }
                HStack {
                    TextField("Gift to username", text: $giftUsername)
                        .textFieldStyle(.roundedBorder)
                    Text("Gift cost \(appState.freezeInfo?.costs.gift ?? 0) XP each")
                        .foregroundStyle(.secondary)
                    Button("Gift Freeze") {
                        Task { await appState.giftFreeze(to: giftUsername, count: freezeCount) }
                    }
                }
            }
        }
    }

    private var dangerZone: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Danger Zone")
                    .font(.title3.weight(.bold))
                SecureField("Password required to delete account", text: $deletePassword)
                    .textFieldStyle(.roundedBorder)
                Button("Delete Account", role: .destructive) {
                    Task { await appState.deleteAccount(password: deletePassword) }
                }
            }
        }
    }
}
