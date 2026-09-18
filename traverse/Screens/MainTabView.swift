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

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                LazyTabContent(tag: 0, selectedTab: $selectedTab) { HomeTab() }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
                
                LazyTabContent(tag: 1, selectedTab: $selectedTab) { RevisionsView() }
                    .tabItem {
                        Label("Revisions", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                LazyTabContent(tag: 2, selectedTab: $selectedTab) { FriendsTab() }
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }
                    .tag(2)
                
                LazyTabContent(tag: 3, selectedTab: $selectedTab) { SettingsView() }
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
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
                selectedTab = 1 // Navigate to Revisions tab
            }
        } else {
            TabView(selection: $selectedTab) {
                LazyTabContent(tag: 0, selectedTab: $selectedTab) { HomeTab() }
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)
                
                LazyTabContent(tag: 1, selectedTab: $selectedTab) { RevisionsView() }
                    .tabItem {
                        Label("Revisions", systemImage: selectedTab == 1 ? "clock.arrow.circlepath" : "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                LazyTabContent(tag: 2, selectedTab: $selectedTab) { FriendsTab() }
                    .tabItem {
                        Label("Friends", systemImage: selectedTab == 2 ? "person.2.fill" : "person.2")
                    }
                    .tag(2)
                
                LazyTabContent(tag: 3, selectedTab: $selectedTab) { SettingsView() }
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                    }
                    .tag(3)
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
                selectedTab = 1 // Navigate to Revisions tab
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
