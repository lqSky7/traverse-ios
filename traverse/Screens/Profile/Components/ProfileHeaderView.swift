import SwiftUI
import Glur

struct ProfileHeaderView: View {
    let profile: UserProfile
    let statistics: UserStatistics?
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ZStack {
            // Blurred profile photo background
            GeometryReader { geometry in
                Image("def_user")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: 180)
                    .clipped()
            }
            .frame(height: 180)
            .glur(radius: 12.0, offset: 0.2, interpolation: 0.5, direction: .down)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Dark overlay for legibility
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
            
            // Content
            VStack(spacing: 0) {
                // User Info - Left + Top aligned
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.username)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .opacity(0.8)

                        HStack(spacing: 8) {
                            Label(profile.visibility.capitalized, systemImage: profile.visibility == "public" ? "globe" : profile.visibility == "private" ? "lock" : "person.2")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .opacity(0.75)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 12)

                Spacer()

                // Stats Row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(profile.currentStreak)")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 0))
                        Label("My Streak", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 30)
                        .background(Color.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("\(profile.totalXp)")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 1))
                        Label("XP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    if let stats = statistics {
                        Divider()
                            .frame(height: 30)
                            .background(Color.white.opacity(0.3))
                        
                        VStack(spacing: 4) {
                            Text("\(stats.totalSolves)")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Solves")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}


extension View {
    @ViewBuilder
    func applyGlassButtonStyle(_ style: ProfileGlassButtonStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .glass:
                self.buttonStyle(.glass)
            case .glassProminent:
                self.buttonStyle(.glassProminent)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    func applyProfileCardBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            self.background(Color(UIColor.systemGray6))
        }
    }
}

// MARK: - Active Streak Card
struct ActiveStreakCard: View {
    let streak: FriendStreak
    @ObservedObject var paletteManager: ColorPaletteManager
    let onDelete: () -> Void
    @State private var glowPhase: CGFloat = 0
    @State private var showDeleteConfirmation = false
    
    private var streakColor: Color {
        paletteManager.color(at: 2) // Use different color from personal streak
    }
    
    private var glowFillOpacity: Double {
        0.15 + 0.1 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Friend Streak column
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(streakColor)
                    Text("\(streak.currentStreak)")
                        .font(.title2)
                        .bold()
                }
                Text("With \(streak.friend.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            // Best streak column
            VStack(spacing: 4) {
                Text("\(streak.longestStreak)")
                    .font(.title2)
                    .bold()
                Text("Best")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.clear, .clear, streakColor.opacity(glowFillOpacity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("End Streak", systemImage: "flame.slash")
            }
        }
        .confirmationDialog(
            "End Streak with \(streak.friend.username)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Streak", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your streak of \(streak.currentStreak) days. This cannot be undone.")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
}

enum ProfileGlassButtonStyle {
    case glass
    case glassProminent
}

#Preview {
    NavigationStack {
        UserProfileView(username: "johndoe")
    }
}
