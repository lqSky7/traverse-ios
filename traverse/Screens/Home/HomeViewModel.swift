import SwiftUI
import Combine
import WidgetKit

@MainActor
class HomeViewModel: ObservableObject {
    @Published var userStats: UserStats?
    @Published var submissionStats: SubmissionStats?
    @Published var solveStats: SolveStats?
    @Published var achievementStats: AchievementStats?
    @Published var recentSolves: [Solve]?
    @Published var todayRevisions: [Revision] = []
    @Published var completedRevisions: [Revision] = []  // Completed revisions for last 7 days
    @Published var revisionScore: RevisionScoreResponse?
    @Published var revisionLoad: RevisionLoadBreakdown?
    @Published var frozenDates: Set<String> = []  // YYYY-MM-DD format for reliable comparison
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Every revision the server returned, unfiltered. The load card needs a
    /// 28-day window, while the weekly-activity card only needs 7 days, so the
    /// two views filter the same list differently rather than each keeping
    /// their own copy.
    private var allRevisions: [Revision] = []

    /// How many solves the *home feed* pulls on refresh.
    ///
    /// This used to be 200, and it was the single heaviest call in the refresh:
    /// each row carries an AI analysis blob, a mistake-tag array and the full
    /// attempt history. Recent Solves and Mistake Analysis were the only cards
    /// that genuinely needed that depth, and they now live on the Problems tab,
    /// which owns its own deeper fetch. The home charts (heatmap, hours, time,
    /// attempts) only need enough history to fill their x-axes, so they ask for
    /// far less — and because every fetch merges into the shared persisted
    /// cache, opening Problems once tops the home charts up for good.
    static let homeSolveLimit = 60

    init() {
        // Load persisted data immediately if available
        if DataManager.shared.hasData {
            self.userStats = DataManager.shared.userStats
            self.submissionStats = DataManager.shared.submissionStats
            self.solveStats = DataManager.shared.solveStats
            self.achievementStats = DataManager.shared.achievementStats
            self.recentSolves = DataManager.shared.recentSolves
            self.todayRevisions = DataManager.shared.todayRevisions
            self.completedRevisions = DataManager.shared.completedRevisions
            self.revisionScore = DataManager.shared.revisionScore
        }
    }

    func loadData(username: String, forceRefresh: Bool = false) async {
        let callID = Int.random(in: 1000...9999)
        let startTime = Date()
        print("[HomeViewModel] #\(callID) loadData START username=\(username) forceRefresh=\(forceRefresh) thread=\(Thread.isMainThread ? "main" : "bg")")

        // Always fetch freeze dates first (lightweight, important for display)
        do {
            let freezeDatesResponse = try await NetworkService.shared.getUsedFreezeDates()
            await MainActor.run {
                self.frozenDates = Set(freezeDatesResponse.freezeDates)
            }
            print("[HomeViewModel] #\(callID) freezeDates OK count=\(freezeDatesResponse.freezeDates.count)")
        } catch {
            // Silent fail - freeze dates are not critical
            print("[HomeViewModel] #\(callID) freezeDates FAILED (non-critical): \(error)")
        }

        // Check if we can use cached data
        if !forceRefresh && DataManager.shared.isCacheFresh {
            print("[HomeViewModel] #\(callID) using cached data (cache is fresh)")
            await MainActor.run {
                if self.userStats == nil { self.userStats = DataManager.shared.userStats }
                if self.submissionStats == nil { self.submissionStats = DataManager.shared.submissionStats }
                if self.solveStats == nil { self.solveStats = DataManager.shared.solveStats }
                if self.achievementStats == nil { self.achievementStats = DataManager.shared.achievementStats }
                if self.recentSolves == nil { self.recentSolves = DataManager.shared.recentSolves }
                if self.todayRevisions.isEmpty { self.todayRevisions = DataManager.shared.todayRevisions }
                if self.completedRevisions.isEmpty { self.completedRevisions = DataManager.shared.completedRevisions }
                if self.revisionScore == nil { self.revisionScore = DataManager.shared.revisionScore }
                self.rebuildLoadBreakdown()
                isLoading = false
            }
            // Update widgets with cached data
            if let userStats = self.userStats?.stats {
                updateWidgets(userStats: userStats, recentSolve: self.recentSolves?.first, revisions: self.todayRevisions)
            }
            print("[HomeViewModel] #\(callID) loadData END (cached path) elapsed=\(Date().timeIntervalSince(startTime))s")
            return
        }
        print("[HomeViewModel] #\(callID) cache stale or forced - fetching from network")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // Two waves, on purpose.
        //
        // The heavy solves call is *started* here so it overlaps the latency of
        // everything else, but it is awaited only after the light data has been
        // published. That way the streak, load, progress and awards cards paint
        // as soon as their (small) responses land, instead of the whole feed
        // waiting behind a 200-row payload with AI blobs attached.
        async let userStatsTask = NetworkService.shared.getUserStats(username: username)
        async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
        async let solveStatsTask = NetworkService.shared.getSolveStats()
        async let achievementStatsTask = NetworkService.shared.getAchievementStats()
        async let revisionsTask = NetworkService.shared.getRevisions(upcoming: true, limit: 50)
        async let completedRevisionsTask = NetworkService.shared.getGroupedRevisions(includeCompleted: true)
        async let scoreTask = try? NetworkService.shared.getRevisionScore()
        async let solvesTask = NetworkService.shared.getSolves(limit: Self.homeSolveLimit)

        let networkStart = Date()
        let lightData: (UserStats, SubmissionStats, SolveStats, AchievementStats, RevisionsResponse, GroupedRevisionsResponse, RevisionScoreResponse?)
        do {
            lightData = try await (
                userStatsTask,
                submissionStatsTask,
                solveStatsTask,
                achievementStatsTask,
                revisionsTask,
                completedRevisionsTask,
                scoreTask
            )
        } catch let error where error is CancellationError {
            print("[HomeViewModel] #\(callID) loadData CANCELLED during light wave elapsed=\(Date().timeIntervalSince(startTime))s")
            await MainActor.run { isLoading = false }
            return
        } catch {
            print("[HomeViewModel] #\(callID) loadData FAILED elapsed=\(Date().timeIntervalSince(startTime))s error=\(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return
        }

        let (userStats, submissionStats, solveStats, achievementStats, revisionsResponse, completedRevisionsResponse, scoreResult) = lightData
        print("[HomeViewModel] #\(callID) light wave completed elapsed=\(Date().timeIntervalSince(networkStart))s revisions=\(revisionsResponse.revisions.count) scoreOK=\(scoreResult != nil)")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Filter for today + overdue only (upcoming includes future dates we don't want)
        let todayAndOverdue = revisionsResponse.revisions.filter { revision in
            let revisionDate = calendar.startOfDay(for: revision.scheduledDate)
            return revisionDate <= today
        }

        // Everything the server knows about, so the load card can look back 28
        // days without a second round trip.
        let everyRevision = completedRevisionsResponse.groups.flatMap { $0.revisions }

        // Completed revisions from the last 7 days, for the weekly-activity card.
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let recentCompletedRevisions = everyRevision.filter { revision in
            guard let completedDate = ActivityTimestamp.date(from: revision.completedAt) else { return false }
            return completedDate >= sevenDaysAgo
        }

        await MainActor.run {
            self.userStats = userStats
            self.submissionStats = submissionStats
            self.solveStats = solveStats
            self.achievementStats = achievementStats
            self.todayRevisions = todayAndOverdue
            self.completedRevisions = recentCompletedRevisions
            self.allRevisions = everyRevision
            if let scoreResult = scoreResult {
                self.revisionScore = scoreResult
            }
            self.rebuildLoadBreakdown()
            // Light data is on screen; the solves wave below can take its time.
            isLoading = false
            // frozenDates already set at start of loadData
        }
        print("[HomeViewModel] #\(callID) published light data to @Published properties")

        // Update DataManager cache
        DataManager.shared.userStats = userStats
        DataManager.shared.submissionStats = submissionStats
        DataManager.shared.solveStats = solveStats
        DataManager.shared.achievementStats = achievementStats
        DataManager.shared.todayRevisions = todayAndOverdue
        DataManager.shared.completedRevisions = recentCompletedRevisions
        if let scoreResult = scoreResult {
            DataManager.shared.revisionScore = scoreResult
        }

        // Update timestamp
        DataManager.shared.lastFetchTimestamp = Date()

        // Persist the data
        let persistStart = Date()
        DataManager.shared.persistData()
        print("[HomeViewModel] #\(callID) persistData done elapsed=\(Date().timeIntervalSince(persistStart))s")

        // Update widgets - send exactly what we want to display (today + overdue)
        let widgetStart = Date()
        updateWidgets(userStats: userStats.stats, recentSolve: self.recentSolves?.first, revisions: todayAndOverdue)
        print("[HomeViewModel] #\(callID) updateWidgets done elapsed=\(Date().timeIntervalSince(widgetStart))s")

        // --- Second wave: solves.
        //
        // Failure here is deliberately non-fatal. The charts fall back to the
        // shared persisted cache, which is strictly larger than one page
        // anyway, so a dropped request degrades nothing but freshness.
        let solvesStart = Date()
        do {
            let solvesResponse = try await solvesTask
            let mergedSolves = DataManager.shared.mergeAndPersistSolves(solvesResponse.solves)
            print("[HomeViewModel] #\(callID) solves wave done elapsed=\(Date().timeIntervalSince(solvesStart))s fetched=\(solvesResponse.solves.count) merged=\(mergedSolves.count)")

            await MainActor.run {
                self.recentSolves = mergedSolves
                self.rebuildLoadBreakdown()
            }
            updateWidgets(userStats: userStats.stats, recentSolve: mergedSolves.first, revisions: todayAndOverdue)
        } catch let error where error is CancellationError {
            print("[HomeViewModel] #\(callID) solves wave cancelled")
        } catch {
            print("[HomeViewModel] #\(callID) solves wave FAILED (non-fatal): \(error)")
        }

        // Check if solved today and end live activity if needed
        DataManager.shared.checkSolvedTodayAndEndActivity()

        // Trigger app updates & toast check
        let toastStart = Date()
        await AchievementToastManager.shared.syncAppOpenUpdates()
        print("[HomeViewModel] #\(callID) syncAppOpenUpdates done elapsed=\(Date().timeIntervalSince(toastStart))s")

        await MainActor.run {
            isLoading = false
        }
        print("[HomeViewModel] #\(callID) loadData END totalElapsed=\(Date().timeIntervalSince(startTime))s")
    }

    /// Recomputes the training-load card from whatever revisions and solves are
    /// currently in memory. Cheap enough to call after either wave lands.
    private func rebuildLoadBreakdown() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let windowStart = calendar.date(byAdding: .day, value: -ActivityMetrics.loadBaselineDays, to: today) ?? today

        let recentRevisions = allRevisions.filter { revision in
            guard let completed = ActivityTimestamp.date(from: revision.completedAt) else { return false }
            return completed >= windowStart
        }

        revisionLoad = RevisionLoadBreakdown.build(
            revisions: recentRevisions,
            solves: recentSolves ?? []
        )
    }

    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {
        guard let solves = recentSolves else { return false }

        let calendar = Calendar.current
        let now = Date()

        return solves.contains { solve in
            guard let solveDate = solve.activityDate else { return false }
            return calendar.isDate(solveDate, inSameDayAs: now)
        }
    }

    private func updateWidgets(userStats: UserStatsData, recentSolve: Solve?, revisions: [Revision]) {
        // Update streak widget
        let solvedToday = hasSolvedToday(recentSolves: self.recentSolves)
        WidgetDataUpdater.shared.updateStreakStatus(
            solvedToday: solvedToday,
            currentStreak: userStats.currentStreak,
            totalXp: userStats.totalXp,
            totalSolves: userStats.totalSolves
        )

        // Update all widgets with complete data
        WidgetDataUpdater.shared.updateWidgetData(
            userStats: userStats,
            recentSolve: recentSolve,
            revisions: revisions,
            achievementStats: self.achievementStats?.stats,
            solvedToday: solvedToday
        )
    }

    func refreshWidgets() {
        // Refresh widgets with current cached data when app is opened
        guard let userStats = self.userStats?.stats else { return }

        // Recalculate solvedToday in case it changed
        let solvedToday = hasSolvedToday(recentSolves: self.recentSolves)

        WidgetDataUpdater.shared.updateStreakStatus(
            solvedToday: solvedToday,
            currentStreak: userStats.currentStreak,
            totalXp: userStats.totalXp,
            totalSolves: userStats.totalSolves
        )

        WidgetDataUpdater.shared.updateWidgetData(
            userStats: userStats,
            recentSolve: self.recentSolves?.first,
            revisions: self.todayRevisions,
            achievementStats: self.achievementStats?.stats,
            solvedToday: solvedToday
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
