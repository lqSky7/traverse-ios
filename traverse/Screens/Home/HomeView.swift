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
                VStack(spacing: 20) {
                    if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "", forceRefresh: true)
                            }
                        })
                    } else {
                        // Top Row: Streak Card & Revision Score Card side by side
                        if let userStats = viewModel.userStats {
                            HStack(spacing: 12) {
                                StreakCard(streak: userStats.stats.currentStreak, maxStreak: userStats.stats.totalStreakDays)
                                
                                RevisionScoreCard(
                                    score: viewModel.revisionScore?.score ?? 100,
                                    paletteManager: paletteManager
                                )
                            }
                        }
                        
                        // Main Stats Cards
                        if let solveStats = viewModel.solveStats {
                            MainStatsCard(stats: solveStats.stats, paletteManager: paletteManager)
                        }
                        
                        // Charts Section
                        VStack(spacing: 16) {
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
                            
                            if let solveStats = viewModel.solveStats,
                               let solves = viewModel.recentSolves {
                                // Difficulty and Activity side by side
                                HStack(alignment: .top, spacing: 16) {
                                    DifficultyChartCard(stats: solveStats.stats, paletteManager: paletteManager)
                                    NavigationLink(destination: ActivityDetailView(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)) {
                                        SolveHeatmapCard(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)
                                            .id(viewModel.frozenDates.count)  // Force re-render when frozenDates changes
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Mistake Tags Analysis full width
                                NavigationLink(destination: MistakeTagsDetailView(solves: solves, paletteManager: paletteManager)) {
                                    MistakeTagsAnalysisCard(solves: solves, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Best Solving Hours (replaces Submission Breakdown)
                                BestSolvingHoursCard(solves: solves, paletteManager: paletteManager)
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                RecentSolvesCard(solves: solves, paletteManager: paletteManager)
                                
                                // New Performance Charts
                                PerformanceMetricsCard(solves: solves, paletteManager: paletteManager)
                                
                                TriesDistributionCard(solves: solves, paletteManager: paletteManager)
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
            if let username = authViewModel.currentUser?.username {
                // Set username for Watch sync
                WidgetDataUpdater.shared.currentUsername = username
                Task {
                    await viewModel.loadData(username: username)
                }
            }
        }
        .onChange(of: authViewModel.currentUser?.username) { oldUsername, newUsername in
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
