import SwiftUI

struct HomeTab: View {
    var body: some View {
        HomeView()
    }
}

struct FriendsTab: View {
    @State private var showingSearch = false
    @State private var showingQRSheet = false
    @State private var showingQRScanner = false
    @State private var showQRMenu = false
    @State private var deepLinkUsername: String?
    @State private var showDeepLinkProfile = false
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            FriendsView(showingSearchFromTab: $showingSearch)
            
            // Floating action buttons above tab bar
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    // QR Code Button (circular)
                    Menu {
                        Button(action: { showingQRSheet = true }) {
                            Label("Show My QR Code", systemImage: "qrcode")
                        }
                        
                        Button(action: { showingQRScanner = true }) {
                            Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(in: Circle())
                    
                    // Search Friends Button (pill)
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
                }
                .padding(.bottom, 60) // Position above tab bar
            }
        }
        .sheet(isPresented: $showingSearch) {
            UserSearchView()
        }
        .sheet(isPresented: $showingQRSheet) {
            QRCodeSheetView()
        }
        .fullScreenCover(isPresented: $showingQRScanner) {
            QRScannerView()
        }
        .sheet(isPresented: $showDeepLinkProfile) {
            if let username = deepLinkUsername {
                UserProfileView(username: username)
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
