import SwiftUI

struct HomeTab: View {
    var body: some View {
        HomeView()
    }
}

struct FriendsTab: View {
    @State private var showingSearch = false
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            FriendsView(showingSearchFromTab: $showingSearch)
            
            // Floating Liquid Glass Search Button above tab bar
            VStack {
                Spacer()
                
                Button(action: {
                    showingSearch = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                        Text("Search Friends")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .glassEffect(in: Capsule())
                .padding(.bottom, 60) // Position above tab bar
            }
        }
        .sheet(isPresented: $showingSearch) {
            UserSearchView()
        }
    }
}

#Preview("Home") {
    HomeTab()
}

#Preview("Friends") {
    FriendsTab()
}
