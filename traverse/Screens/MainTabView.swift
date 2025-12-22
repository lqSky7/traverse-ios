import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                ExploreTab()
                    .tabItem {
                        Label("Explore", systemImage: "safari.fill")
                    }
                    .tag(1)
                
                ActivityTab()
                    .tabItem {
                        Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            TabView(selection: $selectedTab) {
                HomeTab()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                ExploreTab()
                    .tabItem {
                        Label("Explore", systemImage: "safari.fill")
                    }
                    .tag(1)
                
                ActivityTab()
                    .tabItem {
                        Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
