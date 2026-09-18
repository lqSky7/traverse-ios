import SwiftUI
import Charts
import Combine
import WidgetKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, M"
        return formatter.string(from: Date())
    }

    
    var body: some View {
        NavigationStack {
            ScrollView {
                // NOTE: These were plain `VStack`s. A plain VStack makes every card
                // (including multiple Charts-framework charts, the activity heatmap
                // grid, and the achievement/insight cards) a permanently-live node in
                // SwiftUI's AttributeGraph the instant HomeView appears, whether it's
                // on screen or not. Since NavigationLink keeps HomeView mounted
                // *underneath* whatever gets pushed, any environment change during a
                // push transition (e.g. safe-area insets shifting as the nav/tab bar
                // chrome animates) forces a full re-validation of that entire giant
                // tree at once — which is what was producing the multi-second
                // "Severe Hang" + 100% CPU right after tapping into a card.
                // `LazyVStack` only keeps children near the visible scroll region as
                // live graph nodes, so a re-validation pass has far less to walk.
                LazyVStack(spacing: 20) {
                    if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "", forceRefresh: true)
                            }
                        })
                    } else if let userStats = viewModel.userStats, userStats.stats.totalSolves == 0 {
                        // A brand-new account. Every card below is built from
                        // solve history, so without this branch the feed is a
                        // blank black screen with a date on it — which reads as
                        // a broken app rather than an empty one.
                        GettingStartedEmptyState(
                            title: "Your feed fills in from your first solve",
                            message: "Traverse reads your practice from the browser and reports it back here. There is nothing to show until then."
                        )
                    } else {
                        // Streak — full width. It used to share a row with the
                        // revision score card; that card is a full-width
                        // training-load tile now, so the streak takes the whole
                        // row instead of being squeezed into half of it.
                        //
                        // `longestStreak` is the real "best" figure. The
                        // fallback is only for caches written before the backend
                        // started sending it — `totalStreakDays` is a running
                        // total, so it is wrong here, just not wrong-by-a-lot.
                        if let userStats = viewModel.userStats {
                            StreakCard(
                                streak: userStats.stats.currentStreak,
                                maxStreak: userStats.stats.longestStreak ?? userStats.stats.totalStreakDays
                            )
                        }

                        // Revision Load — full-width tile, taps through to the
                        // trend screen.
                        NavigationLink(destination: RevisionLoadDetailView(
                            breakdown: viewModel.revisionLoad ?? .empty,
                            revisionScore: viewModel.revisionScore?.score,
                            paletteManager: paletteManager
                        )) {
                            RevisionLoadCard(
                                breakdown: viewModel.revisionLoad,
                                revisionScore: viewModel.revisionScore?.score,
                                paletteManager: paletteManager
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Main Stats Cards
                        if let solveStats = viewModel.solveStats {
                            MainStatsCard(stats: solveStats.stats, paletteManager: paletteManager)
                        }
                        
                        // Charts Section
                        LazyVStack(spacing: 16) {
                            // Achievements and Insights side by side
                            if let achievementStats = viewModel.achievementStats,
                               let solves = viewModel.recentSolves, !solves.isEmpty {
                                HStack(alignment: .top, spacing: 16) {
                                    NavigationLink(destination: AllAchievementsView()) {
                                        AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    ProductivityInsightsCard(solves: solves, completedRevisions: viewModel.completedRevisions, paletteManager: paletteManager)
                                }
                            } else if let achievementStats = viewModel.achievementStats {
                                NavigationLink(destination: AllAchievementsView()) {
                                    AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                // Activity heatmap, full width now that the
                                // difficulty card that shared its row is gone.
                                NavigationLink(destination: ActivityDetailView(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)) {
                                    SolveHeatmapCard(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)
                                        .id(viewModel.frozenDates.count)  // Force re-render when frozenDates changes
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                BestSolvingHoursCard(solves: solves, paletteManager: paletteManager)
                                
                                // Time and attempts, as Step Count style tiles.
                                HStack(alignment: .top, spacing: 12) {
                                    NavigationLink(destination: MetricDetailView(kind: .time, solves: solves, paletteManager: paletteManager)) {
                                        TimeAnalysisCard(solves: solves, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink(destination: MetricDetailView(kind: .attempts, solves: solves, paletteManager: paletteManager)) {
                                        AttemptsAnalysisCard(solves: solves, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.large)
            .toolbarScrollMinimization()
            .refreshable {
                if let username = authViewModel.currentUser?.username {
                    // Use Task to prevent early cancellation from pull-to-refresh gesture
                    await Task {
                        await viewModel.loadData(username: username, forceRefresh: true)
                    }.value
                }
            }
        }
        .onAppear {
            print("[HomeView] onAppear username=\(authViewModel.currentUser?.username ?? "nil")")
            if let username = authViewModel.currentUser?.username {
                // Set username for Watch sync
                WidgetDataUpdater.shared.currentUsername = username
                Task {
                    await viewModel.loadData(username: username)
                }
            }
        }
        .onChange(of: authViewModel.currentUser?.username) { oldUsername, newUsername in
            print("[HomeView] onChange username \(oldUsername ?? "nil") -> \(newUsername ?? "nil")")
            if let username = newUsername {
                // Update username for Watch sync
                WidgetDataUpdater.shared.currentUsername = username
                if viewModel.solveStats == nil {
                    Task {
                        await viewModel.loadData(username: username)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .revisionCompleted)) { _ in
            print("[HomeView] received .revisionCompleted notification, forcing refresh")
            if let username = authViewModel.currentUser?.username {
                Task {
                    await viewModel.loadData(username: username, forceRefresh: true)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {
        guard let solves = recentSolves else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Create ISO8601 formatter that handles optional fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return solves.contains { solve in
            // Try with fractional seconds first, then without
            var date = formatter.date(from: solve.solvedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: solve.solvedAt)
            }
            
            if let solveDate = date {
                return calendar.isDate(solveDate, inSameDayAs: now)
            }
            return false
        }
    }
    

}

// MARK: - Streak Card (Half Width)
