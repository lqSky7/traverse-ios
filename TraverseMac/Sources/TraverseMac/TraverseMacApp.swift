import SwiftUI

@main
struct TraverseMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var paletteManager = ColorPaletteManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(paletteManager)
                .preferredColorScheme(paletteManager.isDarkMode ? .dark : .light)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Traverse Data") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager

    var body: some View {
        ZStack {
            background
            if appState.isAuthenticated {
                MacShellView()
            } else {
                AuthView()
            }
        }
        .overlay(alignment: .top) {
            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .alert("Traverse", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .alert("Done", isPresented: Binding(
            get: { appState.statusMessage != nil },
            set: { if !$0 { appState.statusMessage = nil } }
        )) {
            Button("OK") { appState.statusMessage = nil }
        } message: {
            Text(appState.statusMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                paletteManager.color(at: 0).opacity(0.12),
                Color(nsColor: .windowBackgroundColor),
                paletteManager.color(at: 1).opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case problems = "Problems"
    case revisions = "Revisions"
    case friends = "Friends"
    case achievements = "Achievements"
    case freezes = "Freezes"
    case passwordReset = "Password Reset"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house"
        case .problems: "checklist"
        case .revisions: "clock.arrow.circlepath"
        case .friends: "person.2"
        case .achievements: "trophy"
        case .freezes: "snowflake"
        case .passwordReset: "key"
        case .settings: "gearshape"
        }
    }
}

struct MacShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.symbol)
                            .tag(section)
                    }
                }
            }
            .navigationTitle("Traverse")
            .safeAreaInset(edge: .bottom) {
                userFooter
                    .padding(12)
            }
        } detail: {
            NavigationStack {
                Group {
                    switch selection ?? .home {
                    case .home:
                        DashboardView()
                    case .problems:
                        ProblemsView()
                    case .revisions:
                        RevisionsView()
                    case .friends:
                        FriendsView()
                    case .achievements:
                        AchievementsView()
                    case .freezes:
                        FreezeHistoryView()
                    case .passwordReset:
                        PasswordResetStandaloneView()
                    case .settings:
                        SettingsView()
                    }
                }
                .toolbar {
                    ToolbarItemGroup {
                        PaletteStrip(palette: paletteManager.selectedPalette)
                        Button {
                            Task { await appState.refreshAll() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .tint(paletteManager.selectedPalette.primary)
    }

    private var userFooter: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(paletteManager.selectedPalette.primary.opacity(0.18))
                Text(String(appState.user?.username.prefix(1).uppercased() ?? "T"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(paletteManager.selectedPalette.primary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.user?.username ?? "Traverse")
                    .font(.subheadline.weight(.semibold))
                Text("\(appState.user?.currentStreak ?? 0) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
