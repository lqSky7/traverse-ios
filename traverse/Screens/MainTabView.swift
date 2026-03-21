import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
                
                RevisionsView()
                    .tabItem {
                        Label("Revisions", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                FriendsTab()
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }
                    .tag(2)
                
                SettingsView()
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(paletteManager.selectedPalette.primary)
            .onAppear {
                setupNotificationObserver()
            }
        } else {
            TabView(selection: $selectedTab) {
                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                    .tag(0)
                
                RevisionsView()
                    .tabItem {
                        Label("Revisions", systemImage: selectedTab == 1 ? "clock.arrow.circlepath" : "clock.arrow.circlepath")
                    }
                    .tag(1)
                
                FriendsTab()
                    .tabItem {
                        Label("Friends", systemImage: selectedTab == 2 ? "person.2.fill" : "person.2")
                    }
                    .tag(2)
                
                SettingsView()
                    .tint(.blue)
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                    }
                    .tag(3)
            }
            .tint(paletteManager.selectedPalette.primary)
            .onAppear {
                setupNotificationObserver()
            }
        }
    }
}

extension MainTabView {
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenRevisionsTab"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 1 // Navigate to Revisions tab
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
