import SwiftUI
import Combine

struct HomeTab: View {
    var body: some View {
        HomeView()
    }
}

/// The Friends tab.
///
/// It used to own the search and QR buttons and float them in a `ZStack` over
/// the whole tab, which is why they hovered above pushed profiles too. They now
/// live in `FriendsView` as a bottom inset on the list itself. All that is left
/// here is the deep-link sheet, which is genuinely tab-level.
struct FriendsTab: View {
    @State private var deepLinkUsername: String?
    @State private var showDeepLinkProfile = false

    var body: some View {
        FriendsView()
            .sheet(isPresented: $showDeepLinkProfile) {
                // `UserProfileView` sets a navigation title and a toolbar menu,
                // both of which need a stack around them when the profile is the
                // root of a sheet rather than a push.
                NavigationStack {
                    if let username = deepLinkUsername {
                        UserProfileView(username: username)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkAddFriend)) { notification in
                if let username = notification.userInfo?["username"] as? String {
                    deepLinkUsername = username
                    showDeepLinkProfile = true
                }
            }
    }
}

#Preview("Home") {
    HomeTab()
}

#Preview("Friends") {
    FriendsTab()
}
