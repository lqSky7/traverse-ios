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
    @Published var frozenDates: Set<String> = []  // YYYY-MM-DD format for reliable comparison
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        // Use cache if fresh (< 2 hours), otherwise fetch from server
        
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
        
        do {
            async let userStatsTask = NetworkService.shared.getUserStats(username: username)
            async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
            async let solveStatsTask = NetworkService.shared.getSolveStats()
            async let achievementStatsTask = NetworkService.shared.getAchievementStats()
            async let recentSolvesTask = NetworkService.shared.getSolves(limit: 200)
            async let revisionsTask = NetworkService.shared.getRevisions(upcoming: true, limit: 50)
            async let completedRevisionsTask = NetworkService.shared.getGroupedRevisions(includeCompleted: true)
            async let scoreTask = try? NetworkService.shared.getRevisionScore()

            let networkStart = Date()
            let (userStats, submissionStats, solveStats, achievementStats, solvesResponse, revisionsResponse, completedRevisionsResponse, scoreResult) = try await (
                userStatsTask,
                submissionStatsTask,
                solveStatsTask,
                achievementStatsTask,
                recentSolvesTask,
                revisionsTask,
                completedRevisionsTask,
                scoreTask
            )
            print("[HomeViewModel] #\(callID) all network calls completed elapsed=\(Date().timeIntervalSince(networkStart))s solves=\(solvesResponse.solves.count) revisions=\(revisionsResponse.revisions.count) scoreOK=\(scoreResult != nil)")
            
            // Filter for today + overdue only (upcoming includes future dates we don't want)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let todayAndOverdue = revisionsResponse.revisions.filter { revision in
                let revisionDate = calendar.startOfDay(for: revision.scheduledDate)
                return revisionDate <= today
            }

            // Extract completed revisions from last 7 days
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let recentCompletedRevisions = completedRevisionsResponse.groups.flatMap { $0.revisions }
                .filter { revision in
                    guard let completedAtString = revision.completedAt else { return false }
                    var completedDate = formatter.date(from: completedAtString)
                    if completedDate == nil {
                        formatter.formatOptions = [.withInternetDateTime]
                        completedDate = formatter.date(from: completedAtString)
                    }
                    guard let date = completedDate else { return false }
                    return date >= sevenDaysAgo
                }

            // Merge and persist solves inside DataManager, getting the merged array back
            let mergeStart = Date()
            let mergedSolves = DataManager.shared.mergeAndPersistSolves(solvesResponse.solves)
            print("[HomeViewModel] #\(callID) mergeAndPersistSolves done elapsed=\(Date().timeIntervalSince(mergeStart))s mergedCount=\(mergedSolves.count)")

            await MainActor.run {
                self.userStats = userStats
                self.submissionStats = submissionStats
                self.solveStats = solveStats
                self.achievementStats = achievementStats
                self.recentSolves = mergedSolves
                self.todayRevisions = todayAndOverdue
                self.completedRevisions = recentCompletedRevisions
                if let scoreResult = scoreResult {
                    self.revisionScore = scoreResult
                }
                // frozenDates already set at start of loadData
            }
            print("[HomeViewModel] #\(callID) published data to @Published properties")
            
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
            updateWidgets(userStats: userStats.stats, recentSolve: mergedSolves.first, revisions: todayAndOverdue)
            print("[HomeViewModel] #\(callID) updateWidgets done elapsed=\(Date().timeIntervalSince(widgetStart))s")

            // Check if solved today and end live activity if needed
            DataManager.shared.checkSolvedTodayAndEndActivity()
            
            // Trigger app updates & toast check
            let toastStart = Date()
            await AchievementToastManager.shared.syncAppOpenUpdates()
            print("[HomeViewModel] #\(callID) syncAppOpenUpdates done elapsed=\(Date().timeIntervalSince(toastStart))s")

        } catch let error where error is CancellationError {
            // Ignore cancellation errors - user likely released pull-to-refresh
            print("[HomeViewModel] #\(callID) loadData CANCELLED elapsed=\(Date().timeIntervalSince(startTime))s")
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("[HomeViewModel] #\(callID) loadData FAILED elapsed=\(Date().timeIntervalSince(startTime))s error=\(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
        print("[HomeViewModel] #\(callID) loadData END totalElapsed=\(Date().timeIntervalSince(startTime))s")
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

