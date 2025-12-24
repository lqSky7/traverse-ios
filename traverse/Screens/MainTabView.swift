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
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                FriendsTab()
                    .tabItem {
                        Label("Friends", systemImage: "person.2.fill")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(paletteManager.selectedPalette.primary)
        } else {
            TabView(selection: $selectedTab) {
                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                FriendsTab()
                    .tabItem {
                        Label("Friends", systemImage: "person.2.fill")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
            .tint(paletteManager.selectedPalette.primary)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
