import SwiftUI
import Glur

struct UserProfileView: View {
    let username: String
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingGiftConfirmation = false
    @State private var isGifting = false
    @State private var giftSuccessMessage: String?
    
    init(username: String) {
        self.username = username
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(username: username))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadProfile()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let profile = viewModel.profile {
                    ProfileHeaderView(profile: profile, statistics: viewModel.statistics)
                    
                    // Friend streak section (only for friends) - shown above remove button
                    if viewModel.friendshipStatus == .friends {
                        streakActionSection
                    }
                    
                    friendActionButton
                    
                    if let statistics = viewModel.statistics {
                        StatisticsView(statistics: statistics)
                    }
                    
                    Picker("View", selection: $viewModel.selectedTab) {
                        Text("Solves").tag(0)
                        Text("Achievements").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewModel.selectedTab == 0 {
                        SolvesListView(
                            solves: viewModel.solves,
                            canLoadMore: viewModel.canLoadMoreSolves,
                            onLoadMore: { viewModel.loadMoreSolves() }
                        )
                    } else {
                        AchievementsListView(achievements: viewModel.achievements)
                    }
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarScrollMinimization()
        .task {
            // Load profile first, then load streak status in parallel with other data
            await viewModel.loadProfile()
            async let solvesTask: () = viewModel.loadSolves()
            async let achievementsTask: () = viewModel.loadAchievements()
            async let streakTask: () = viewModel.loadFriendStreakStatus()
            _ = await (solvesTask, achievementsTask, streakTask)
        }
        .refreshable {
            // Use Task to prevent early cancellation from pull-to-refresh gesture
            await Task {
                await viewModel.loadProfile(force: true)
                async let solvesTask: () = viewModel.loadSolves(force: true)
                async let achievementsTask: () = viewModel.loadAchievements(force: true)
                async let streakTask: () = viewModel.loadFriendStreakStatus(force: true)
                _ = await (solvesTask, achievementsTask, streakTask)
            }.value
        }
        .onChange(of: viewModel.selectedTab) { _, newValue in
            if newValue == 0 && viewModel.solves.isEmpty {
                Task {
                    await viewModel.loadSolves()
                }
            } else if newValue == 1 && viewModel.achievements.isEmpty {
                Task {
                    await viewModel.loadAchievements()
                }
            }
        }
        .onAppear {
            viewModel.currentUsername = authViewModel.currentUser?.username
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Freeze Gifted!", isPresented: .constant(giftSuccessMessage != nil)) {
            Button("OK") {
                giftSuccessMessage = nil
            }
        } message: {
            if let message = giftSuccessMessage {
                Text(message)
            }
        }
    }
    
    @ViewBuilder
    private var friendActionButton: some View {
        switch viewModel.friendshipStatus {
        case .currentUser:
            EmptyView()
            
        case .notFriends:
            Group {
                Button {
                    Task {
                        await viewModel.sendFriendRequest()
                    }
                } label: {
                    Text("Send Friend Request")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .tint(paletteManager.selectedPalette.primary)
            }
            .applyGlassButtonStyle(.glassProminent)
            .padding(.horizontal)
            
        case .friends:
            VStack(spacing: 12) {
                // Gift Freeze Button
                Group {
                    Button {
                        showingGiftConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "snowflake")
                            Text(isGifting ? "Sending..." : "Gift Freeze (70 XP)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGifting)
                    .tint(.cyan)
                }
                .applyGlassButtonStyle(.glassProminent)
                .padding(.horizontal)
                .confirmationDialog(
                    "Gift a Streak Freeze?",
                    isPresented: $showingGiftConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Gift for 70 XP") {
                        Task {
                            isGifting = true
                            let success = await viewModel.giftFreeze()
                            if success {
                                giftSuccessMessage = "Freeze gifted to \(username)!"
                                AchievementToastManager.shared.showToast(name: "Freeze gifted to \(username)!", category: "gift_freeze", icon: "snowflake")
                            }
                            isGifting = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will cost 70 XP from your balance. \(username) can use it to protect their streak!")
                }
                
                // Remove Friend Button
                Group {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.removeFriend()
                        }
                    } label: {
                        Text("Remove Friend")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
                .applyGlassButtonStyle(.glassProminent)
                .padding(.horizontal)

            }
            
        case .requestSent:
            HStack {
                Image(systemName: "clock")
                Text("Friend Request Sent")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
        case .requestReceived:
            HStack {
                Image(systemName: "envelope.badge")
                Text("Friend Request Received")
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var streakActionSection: some View {
        VStack(spacing: 8) {
            switch viewModel.friendStreakStatus {
            case .none:
                EmptyView()
                
            case .active:
                // Show active streak info with liquid glass and glow
                if let streak = viewModel.friendStreak {
                    ActiveStreakCard(streak: streak, paletteManager: paletteManager, onDelete: {
                        Task {
                            await viewModel.deleteStreak()
                        }
                    })
                    .padding(.horizontal)
                }
                
            case .canStart:
                // Show "Start Streak" button
                Group {
                    Button {
                        Task {
                            await viewModel.sendStreakRequest()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame")
                            Text("Start Streak")
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                    }
                    .tint(paletteManager.color(at: 0))
                }
                .applyGlassButtonStyle(.glassProminent)
                .padding(.horizontal)
                
            case .requestSent:
                HStack {
                    Image(systemName: "flame.badge.checkmark")
                    Text("Streak Request Sent")
                }
                .font(.subheadline)
                .foregroundStyle(paletteManager.color(at: 0))
                .padding()
                .frame(maxWidth: .infinity)
                .background(paletteManager.color(at: 0).opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
            case .requestReceived:
                HStack {
                    Image(systemName: "flame.badge.checkmark")
                    Text("Streak Request Received")
                    Spacer()
                    Text("Check requests")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .foregroundStyle(paletteManager.color(at: 0))
                .padding()
                .frame(maxWidth: .infinity)
                .background(paletteManager.color(at: 0).opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}

