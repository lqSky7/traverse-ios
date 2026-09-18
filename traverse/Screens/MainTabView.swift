import SwiftUI

// MARK: - Lazy Tab Loading
//
// SwiftUI's `TabView` builds the view hierarchy (and every `@StateObject` /
// `@State` inside it) for *every* tab up front, not just the one currently
// selected. With 5 tabs, each owning its own view model that kicks off
// network calls and heavy synchronous computation in `onAppear`, that meant
// logging in triggered all 5 tabs to construct and fetch simultaneously while
// the login->MainTabView crossfade animation was actively running on the main
// thread — a big contributor to the freeze right after sign-in. `LazyTabContent`
// defers building a tab's real content until the user actually selects it at
// least once, then keeps it alive (so switching back doesn't reset state).
private struct LazyTabContent<Content: View>: View {
    let tag: Int
    @Binding var selectedTab: Int
    @ViewBuilder let content: () -> Content
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            if hasAppeared {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if !hasAppeared {
                print("[MainTabView] lazily building tab \(tag)")
                hasAppeared = true
            }
        }
    }
}

// Tab indices, named so the deep-link handler below can't silently drift out of
// sync with the order of the TabView.
private enum MainTab: Int {
    case home = 0
    case problems = 1
    case revisions = 2
    case friends = 3
    case settings = 4
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var selectedTab = MainTab.home.rawValue
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                LazyTabContent(tag: MainTab.home.rawValue, selectedTab: $selectedTab) { HomeTab() }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(MainTab.home.rawValue)
                
                LazyTabContent(tag: MainTab.problems.rawValue, selectedTab: $selectedTab) { ProblemsTab() }
                    .tabItem {
                        Label("Problems", systemImage: "list.bullet.rectangle")
                    }
                    .tag(MainTab.problems.rawValue)
                
                LazyTabContent(tag: MainTab.revisions.rawValue, selectedTab: $selectedTab) { RevisionsView() }
                    .tabItem {
                        Label("Revisions", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(MainTab.revisions.rawValue)
                
                LazyTabContent(tag: MainTab.friends.rawValue, selectedTab: $selectedTab) { FriendsTab() }
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }
                    .tag(MainTab.friends.rawValue)
                
                LazyTabContent(tag: MainTab.settings.rawValue, selectedTab: $selectedTab) { SettingsView() }
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(MainTab.settings.rawValue)
            }
            // .tabBarMinimizeBehavior(.onScrollDown) — TEMPORARILY DISABLED for
            // diagnosis. Stacked with per-screen `.toolbarScrollMinimization()`,
            // this beta "Liquid Glass" API was a suspect in the navigation-push
            // freezes. See ViewModifiers.swift for details. Re-enable once confirmed
            // safe (or once running on a non-beta OS).
            .tint(paletteManager.selectedPalette.primary)
            .overlay(AchievementToastOverlayContainer(), alignment: .top)
            .onAppear {
                print("[MainTabView] onAppear selectedTab=\(selectedTab)")
                Task {
                    await AchievementToastManager.shared.syncAppOpenUpdates()
                }
            }
            .onChange(of: selectedTab) { old, new in
                print("[MainTabView] tab changed \(old) -> \(new)")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRevisionsTab"))) { _ in
                selectedTab = MainTab.revisions.rawValue
            }
            .onReceive(NotificationCenter.default.publisher(for: .notificationDeepLink)) { note in
                guard let tab = note.userInfo?["tab"] as? Int else { return }
                selectedTab = tab
            }
        } else {
            TabView(selection: $selectedTab) {
                LazyTabContent(tag: MainTab.home.rawValue, selectedTab: $selectedTab) { HomeTab() }
                    .tabItem {
                        Label("Home", systemImage: selectedTab == MainTab.home.rawValue ? "house.fill" : "house")
                    }
                    .tag(MainTab.home.rawValue)
                
                LazyTabContent(tag: MainTab.problems.rawValue, selectedTab: $selectedTab) { ProblemsTab() }
                    .tabItem {
                        Label("Problems", systemImage: "list.bullet.rectangle")
                    }
                    .tag(MainTab.problems.rawValue)
                
                LazyTabContent(tag: MainTab.revisions.rawValue, selectedTab: $selectedTab) { RevisionsView() }
                    .tabItem {
                        Label("Revisions", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(MainTab.revisions.rawValue)
                
                LazyTabContent(tag: MainTab.friends.rawValue, selectedTab: $selectedTab) { FriendsTab() }
                    .tabItem {
                        Label("Friends", systemImage: selectedTab == MainTab.friends.rawValue ? "person.2.fill" : "person.2")
                    }
                    .tag(MainTab.friends.rawValue)
                
                LazyTabContent(tag: MainTab.settings.rawValue, selectedTab: $selectedTab) { SettingsView() }
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == MainTab.settings.rawValue ? "gearshape.fill" : "gearshape")
                    }
                    .tag(MainTab.settings.rawValue)
            }
            .tint(paletteManager.selectedPalette.primary)
            .overlay(AchievementToastOverlayContainer(), alignment: .top)
            .onAppear {
                print("[MainTabView] onAppear selectedTab=\(selectedTab)")
                Task {
                    await AchievementToastManager.shared.syncAppOpenUpdates()
                }
            }
            .onChange(of: selectedTab) { old, new in
                print("[MainTabView] tab changed \(old) -> \(new)")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRevisionsTab"))) { _ in
                selectedTab = MainTab.revisions.rawValue
            }
            .onReceive(NotificationCenter.default.publisher(for: .notificationDeepLink)) { note in
                guard let tab = note.userInfo?["tab"] as? Int else { return }
                selectedTab = tab
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
