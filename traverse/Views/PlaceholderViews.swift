import SwiftUI

struct HomeTab: View {
    var body: some View {
        HomeView()
    }
}

struct FriendsTab: View {
    var body: some View {
        FriendsView()
    }
}

#Preview("Home") {
    HomeTab()
}

#Preview("Friends") {
    FriendsTab()
}
