import SwiftUI
import Charts
import Combine
import WidgetKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @ObservedObject private var ringsManager = RingsManager.shared
    @ObservedObject private var inbox = NotificationInboxManager.shared
    @State private var showingNotifications = false

    /// Once-per-visit latch for the feed's chroma sweeps.
    ///
    /// Lives here rather than on the card because the card is inside a `LazyVStack` and is
    /// disposed when it scrolls out of the keep-alive window — a latch on the card would reset on
    /// scroll and the sweep would replay every time the user scrolled back to the top.
    ///
    /// `NavigationStack` keeps this view mounted underneath whatever gets pushed, so `onAppear`
    /// here does *not* reliably fire on the way back. The reset is therefore hung off the pushed
    /// destinations' `onDisappear` — see the `NavigationLink`s in the feed below. That is
    /// deterministic: leaving a detail view clears the gate, so the feed sweeps again when it is
    /// uncovered, and nothing else does.
    @StateObject private var sweepGate = ChromaSweepGate()
    
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
                            message: "Traverse reads your practice from the browser and reports it back here. There is nothing to show until then.",
                            // This sits inside the feed's `LazyVStack`, so without the gate the
                            // headline would re-sweep every time the row is recycled by a scroll.
                            sweepGate: sweepGate
                        )
                    } else {
                        // Streak — full width, with the day's rings on the right.
                        // It used to share a row with the revision score card;
                        // that card is a full-width training-load tile now, so the
                        // streak takes the whole row.
                        //
                        // `longestStreak` is the real "best" figure. The fallback
                        // is only for caches written before the backend started
                        // sending it — `totalStreakDays` is a running total, so it
                        // is wrong here, just not wrong-by-a-lot.
                        //
                        // The rings come from `RingsManager` rather than from the
                        // stats payload because they answer a different question:
                        // the stats say how long you have been consistent, the
                        // rings say what you still owe today. Separate endpoints
                        // also mean a ring fetch failure cannot blank the streak.
                        if let userStats = viewModel.userStats {
                            StreakCard(
                                streak: userStats.stats.currentStreak,
                                maxStreak: userStats.stats.longestStreak ?? userStats.stats.totalStreakDays,
                                rings: ringsManager.progress,
                                // The week strip reads solve history and freeze days. Both are
                                // already on the view model for the heatmap, so this is plumbing
                                // rather than a new fetch.
                                solves: viewModel.recentSolves ?? [],
                                frozenDates: viewModel.frozenDates,
                                sweepGate: sweepGate
                            )
                        }

                        // Revision Load — full-width tile, taps through to the
                        // trend screen.
                        //
                        // Every destination below carries `.onDisappear { sweepGate.reset() }`.
                        // That is what makes the feed's sweep replay when you come back from a
                        // detail view, and what keeps it from replaying while you stay put.
                        NavigationLink(destination: RevisionLoadDetailView(
                            breakdown: viewModel.revisionLoad ?? .empty,
                            revisionScore: viewModel.revisionScore?.score,
                            paletteManager: paletteManager
                        ).onDisappear { sweepGate.reset() }) {
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
                                    NavigationLink(destination: AllAchievementsView().onDisappear { sweepGate.reset() }) {
                                        AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    ProductivityInsightsCard(solves: solves, completedRevisions: viewModel.completedRevisions, paletteManager: paletteManager)
                                }
                            } else if let achievementStats = viewModel.achievementStats {
                                NavigationLink(destination: AllAchievementsView().onDisappear { sweepGate.reset() }) {
                                    AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                // Activity heatmap, full width now that the
                                // difficulty card that shared its row is gone.
                                NavigationLink(destination: ActivityDetailView(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager).onDisappear { sweepGate.reset() }) {
                                    SolveHeatmapCard(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                BestSolvingHoursCard(solves: solves, paletteManager: paletteManager)
                                
                                // Time and attempts, as Step Count style tiles.
                                HStack(alignment: .top, spacing: 12) {
                                    NavigationLink(destination: MetricDetailView(kind: .time, solves: solves, paletteManager: paletteManager).onDisappear { sweepGate.reset() }) {
                                        TimeAnalysisCard(solves: solves, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink(destination: MetricDetailView(kind: .attempts, solves: solves, paletteManager: paletteManager).onDisappear { sweepGate.reset() }) {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    notificationBell
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
            }
            .refreshable {
                if authViewModel.currentUser == nil {
                    try? await authViewModel.fetchCurrentUser()
                }
                if let username = authViewModel.currentUser?.username {
                    // Use Task to prevent early cancellation from pull-to-refresh gesture
                    await Task {
                        await viewModel.loadData(username: username, forceRefresh: true)
                    }.value
                    await ringsManager.refresh()
                }
                await inbox.refreshUnreadCount()
            }
        }
        .onAppear {
            print("[HomeView] onAppear username=\(authViewModel.currentUser?.username ?? "nil")")
            if let username = authViewModel.currentUser?.username {
                // Set the username in shared widget data.
                WidgetDataUpdater.shared.currentUsername = username
                Task {
                    await viewModel.loadData(username: username)
                }
            }
            // Rings are refreshed even when the username is nil, so a session
            // restored from the keychain still draws today's rings.
            Task { await ringsManager.refresh() }
            // Only the badge, not the whole inbox: the list is fetched when the
            // sheet opens, and pulling 30 rows on every tab switch to draw a
            // number would be wasteful.
            Task { await inbox.refreshUnreadCount() }
        }
        .onChange(of: authViewModel.currentUser?.username) { oldUsername, newUsername in
            print("[HomeView] onChange username \(oldUsername ?? "nil") -> \(newUsername ?? "nil")")
            if let username = newUsername {
                // Update the username in shared widget data.
                WidgetDataUpdater.shared.currentUsername = username
                Task {
                    await viewModel.loadData(username: username)
                }
                Task { await ringsManager.refresh() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .revisionCompleted)) { _ in
            print("[HomeView] received .revisionCompleted notification, forcing refresh")
            if let username = authViewModel.currentUser?.username {
                Task {
                    await viewModel.loadData(username: username, forceRefresh: true)
                }
            }
            // A completed revision is one of the two things that can close a
            // ring, so the rings are re-read on the same event.
            Task { await ringsManager.refreshAfterActivity() }
        }
        .preferredColorScheme(.dark)
    }
    
    /// The inbox entry point, with the unread count as a badge.
    ///
    /// A badge rather than a plain bell, because the whole point of an inbox is
    /// that something is waiting in it. The count is capped at "9+" — an exact
    /// number past a point stops being information and starts being a warning.
    private var notificationBell: some View {
        Button {
            showingNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .medium))

                if inbox.unreadCount > 0 {
                    Text(inbox.unreadCount > 9 ? "9+" : "\(inbox.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(paletteManager.color(at: 0)))
                        .offset(x: 8, y: -6)
                }
            }
        }
        .accessibilityLabel(
            inbox.unreadCount > 0
                ? "Notifications, \(inbox.unreadCount) unread"
                : "Notifications"
        )
    }

    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {        guard let solves = recentSolves else { return false }
        
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
