//
//  RevisionsView.swift
//  traverse
//

import SwiftUI
import Charts
import CoreMotion

struct RevisionsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var revisionGroups: [RevisionGroup] = []
    @State private var stats: RevisionStatsResponse?
    @State private var analytics: RevisionAnalyticsResponse?
    @State private var todaySummary: RevisionTodayResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAnalyticsLoading = false
    @State private var analyticsError: String?
    @State private var notificationsEnabled = false
    @State private var selectedRevisionForCoach: Revision? = nil
    @State private var showMLInfoSheet = false
    @State private var showDailyLimitSheet = false
    @State private var dailyCapDraft: Int = 20
    @State private var isSavingDailyCap = false
    @State private var dailyCapMessage: String?
    @State private var loadTask: Task<Void, Never>?
    // NOTE: `showProUpgradeSheet` is still bound to the ProUpgradeSheet sheet below,
    // but nothing sets it to true any more — revisions are no longer premium-gated.
    // Kept deliberately so the paywall entry point isn't lost; remove it together
    // with the sheet when that UI is redesigned.
    @State private var showProUpgradeSheet = false
    @State private var mlTab: MLTab = .upcoming
    @State private var showResumeConfirm = false
    @State private var backlogDaysInput: Int = 3
    @State private var isPausingOrResuming = false

    // Exam mode caching to prevent flicker on load
    @AppStorage("cachedExamModeActive") private var isExamModeActive: Bool = false

    private enum MLTab: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case analytics = "Analytics"

        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                if isExamModeActive {
                    ExamModeActiveView(
                        isResuming: isPausingOrResuming,
                        onResume: {
                            Task { await resumeRevisions(backlogDays: 3) }
                        }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Segmented Picker for Upcoming vs Analytics
                            Picker("View", selection: $mlTab) {
                                ForEach(MLTab.allCases) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)

                            if mlTab == .analytics {
                                if isAnalyticsLoading && analytics == nil {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                                        .padding(.top, 40)
                                } else if let analytics = analytics {
                                    RevisionAnalyticsSection(analytics: analytics)
                                } else if let analyticsError = analyticsError {
                                    VStack(spacing: 12) {
                                        Text(analyticsError)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Button("Retry") {
                                            Task { await loadAnalytics() }
                                        }
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(paletteManager.selectedPalette.primary)
                                    }
                                    .padding(.top, 40)
                                }
                            }

                            if mlTab == .upcoming {
                                if isLoading && revisionGroups.isEmpty {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                                        .padding(.top, 100)
                                } else if let errorMessage = errorMessage {
                                    VStack(spacing: 16) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 60))
                                            .foregroundStyle(.red)
                                        Text(errorMessage)
                                            .foregroundStyle(.red)
                                    }
                                    .padding(.top, 100)
                                } else if revisionGroups.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 60))
                                            .foregroundStyle(.secondary)
                                        Text("No Revisions Scheduled")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        Text("Complete problems to schedule revisions")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 100)
                                } else {
                                    ForEach(revisionGroups) { group in
                                        RevisionGroupCard(
                                            group: group,
                                            onOpenCoach: { revision in
                                                selectedRevisionForCoach = revision
                                            },
                                            onDelete: { revision in
                                                await deleteRevision(revision)
                                            },
                                            onReschedule: { revision, days in
                                                await rescheduleRevision(revision, days: days)
                                            },
                                            onDeleteProblem: { revision in
                                                await deleteProblemFromRevisionList(revision)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.top, 80) // Space for floating toolbar
                    }
                    
                    // Floating Liquid Glass Stats Toolbar + ML toggle
                    if let stats = stats {
                        VStack(spacing: 10) {
                            if #available(iOS 26.0, *) {
                                HStack(spacing: 16) {
                                    StatBadge(title: "Tracked", value: "\(stats.total)", color: paletteManager.color(at: 4))
                                    StatBadge(title: "Due Today", value: "\(stats.dueToday)", color: paletteManager.color(at: 2))
                                    StatBadge(title: "Done", value: "\(stats.completionRate)%", color: paletteManager.color(at: 1))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(.regular.interactive(), in: .capsule)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            } else {
                                HStack(spacing: 16) {
                                    StatBadge(title: "Tracked", value: "\(stats.total)", color: paletteManager.color(at: 4))
                                    StatBadge(title: "Due Today", value: "\(stats.dueToday)", color: paletteManager.color(at: 2))
                                    StatBadge(title: "Done", value: "\(stats.completionRate)%", color: paletteManager.color(at: 1))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Revisions")
            .navigationBarTitleDisplayMode(.large)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showMLInfoSheet = true }) {
                            Label("How ML Scheduling Works", systemImage: "brain.head.profile")
                        }

                        Button(action: { showDailyLimitSheet = true }) {
                            Label("Daily Revision Limit", systemImage: "slider.horizontal.3")
                        }

                        Button(action: { Task { await toggleNotifications() } }) {
                            Label(
                                notificationsEnabled ? "Disable Notifications" : "Enable Notifications",
                                systemImage: notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                            )
                        }
                        
                        Button(action: { Task { await scheduleAllNotifications() } }) {
                            Label("Reschedule All Notifications", systemImage: "arrow.clockwise")
                        }

                        if isExamModeActive {
                            Button(action: { Task { await resumeRevisions(backlogDays: 3) } }) {
                                Label("Stop Exam Mode", systemImage: "play.circle.fill")
                            }
                        } else {
                            Button(action: { Task { await pauseRevisions(days: 365) } }) {
                                Label("Exam Mode", systemImage: "graduationcap.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await loadData() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMLInfoSheet) {
            MLSchedulingInfoSheet()
        }
        .sheet(isPresented: $showDailyLimitSheet) {
            DailyReviewLimitSheet(
                currentCap: authViewModel.currentUser?.maxDailyReviews ?? 20,
                draftCap: $dailyCapDraft,
                isSaving: isSavingDailyCap,
                message: dailyCapMessage,
                summary: todaySummary,
                onSave: { Task { await saveDailyCap() } }
            )
        }
        .sheet(item: $selectedRevisionForCoach) { revision in
            RevisionCoachSheet(
                revision: revision,
                solve: findSolveForRevision(revision),
                todaySolve: findTodaySolveForRevision(revision)
            )
        }
        .sheet(isPresented: $showProUpgradeSheet) {
            ProUpgradeSheet()
        }
        .sheet(isPresented: $showResumeConfirm) {
            ResumeRevisionsSheet(
                backlogDays: $backlogDaysInput,
                isSubmitting: isPausingOrResuming,
                onConfirm: { days in
                    Task { await resumeRevisions(backlogDays: days) }
                }
            )
        }

        .onAppear {
            dailyCapDraft = authViewModel.currentUser?.maxDailyReviews ?? 20
            // Load from cache first
            if !DataManager.shared.revisionGroups.isEmpty {
                revisionGroups = DataManager.shared.revisionGroups
            }
            if let cachedStats = DataManager.shared.revisionStats {
                stats = cachedStats
            }
            Task {
                await loadData()
                await checkNotificationStatus()
            }
        }
        .onChange(of: authViewModel.currentUser?.maxDailyReviews) { _, newValue in
            if let newValue = newValue {
                dailyCapDraft = newValue
            }
        }
        .onChange(of: mlTab) { _, newValue in
            if newValue == .analytics && analytics == nil && !isAnalyticsLoading {
                Task { await loadAnalytics() }
            }
        }
    }
    
    private func loadData() async {
        loadTask?.cancel()
        
        loadTask = Task {
            guard !Task.isCancelled else { return }
            await loadStats()
            
            guard !Task.isCancelled else { return }
            await loadRevisions()

            guard !Task.isCancelled else { return }
            await loadAnalytics()
        }
        
        await loadTask?.value
    }
    
    private func loadStats() async {
        do {
            stats = try await NetworkService.shared.getRevisionStats()
        } catch {
            print("Failed to load revision stats: \(error.localizedDescription)")
        }
    }
    
    private func loadRevisions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkService.shared.getTodayRevisions()
            todaySummary = response
            if let isPaused = response.isPaused {
                isExamModeActive = isPaused
            }
            revisionGroups = groupRevisionsByDate(response.revisions)

            if notificationsEnabled {
                await NotificationManager.shared.scheduleRevisionNotifications(for: response.revisions)
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            errorMessage = "Failed to load revisions"
        }
        
        // Save to DataManager cache
        DataManager.shared.revisionGroups = revisionGroups
        DataManager.shared.revisionStats = stats
        DataManager.shared.persistData()
        
        isLoading = false
    }

    private func loadAnalytics() async {
        isAnalyticsLoading = true
        analyticsError = nil
        do {
            analytics = try await NetworkService.shared.getRevisionAnalytics()
        } catch {
            analyticsError = "Revision analytics unavailable"
        }
        isAnalyticsLoading = false
    }
    
    private func checkNotificationStatus() async {
        notificationsEnabled = await NotificationManager.shared.checkAuthorizationStatus()
    }
    
    private func toggleNotifications() async {
        if notificationsEnabled {
            await NotificationManager.shared.removePendingRevisionNotifications()
            notificationsEnabled = false
        } else {
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                notificationsEnabled = true
                await scheduleAllNotifications()
            }
        }
    }
    

    private func scheduleAllNotifications() async {
        guard notificationsEnabled else { return }
        
        do {
            let response = try await NetworkService.shared.getRevisions(
                upcoming: true,
                limit: 1000
            )
            await NotificationManager.shared.scheduleRevisionNotifications(for: response.revisions)
            await NotificationManager.shared.scheduleDailyRevisionReminder()
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }
    
    private func deleteRevision(_ revision: Revision) async {
        // Optimistically remove from UI so backend fetch doesn't backfill new items into capped list
        withAnimation {
            for i in 0..<revisionGroups.count {
                revisionGroups[i] = RevisionGroup(
                    date: revisionGroups[i].date,
                    revisions: revisionGroups[i].revisions.filter { $0.id != revision.id },
                    count: revisionGroups[i].revisions.filter { $0.id != revision.id }.count
                )
            }
            revisionGroups.removeAll { $0.revisions.isEmpty }
        }
        do {
            try await NetworkService.shared.deleteRevision(id: revision.id)
            HapticManager.shared.success()
        } catch {
            print("Failed to delete revision: \(error.localizedDescription)")
            HapticManager.shared.error()
            await loadData()
        }
    }
    
    private func rescheduleRevision(_ revision: Revision, days: Int) async {
        do {
            try await NetworkService.shared.rescheduleRevision(id: revision.id, days: days)
            HapticManager.shared.success()
            await loadData()
        } catch {
            print("Failed to reschedule revision: \(error.localizedDescription)")
            HapticManager.shared.error()
        }
    }
    
    private func deleteProblemFromRevisionList(_ revision: Revision) async {
        // Optimistically remove all revisions of this problem from UI
        withAnimation {
            for i in 0..<revisionGroups.count {
                let filtered = revisionGroups[i].revisions.filter { $0.problem.id != revision.problem.id }
                revisionGroups[i] = RevisionGroup(
                    date: revisionGroups[i].date,
                    revisions: filtered,
                    count: filtered.count
                )
            }
            revisionGroups.removeAll { $0.revisions.isEmpty }
        }
        do {
            try await NetworkService.shared.deleteProblemRevisions(problemId: revision.problem.id)
            HapticManager.shared.success()
        } catch {
            print("Failed to delete problem revisions: \(error.localizedDescription)")
            HapticManager.shared.error()
            await loadData()
        }
    }

    private func pauseRevisions(days: Int = 365) async {
        isPausingOrResuming = true
        isExamModeActive = true
        do {
            _ = try await NetworkService.shared.pauseMLRevisions(pauseDays: days)
            HapticManager.shared.success()
            await loadData()
        } catch {
            print("Failed to pause revisions: \(error.localizedDescription)")
            isExamModeActive = false
            HapticManager.shared.error()
        }
        isPausingOrResuming = false
    }

    private func resumeRevisions(backlogDays: Int) async {
        isPausingOrResuming = true
        isExamModeActive = false
        do {
            _ = try await NetworkService.shared.resumeMLRevisions(backlogDays: backlogDays)
            HapticManager.shared.success()
            showResumeConfirm = false
            await loadData()
        } catch {
            print("Failed to resume revisions: \(error.localizedDescription)")
            isExamModeActive = true
            HapticManager.shared.error()
        }
        isPausingOrResuming = false
    }

    private func saveDailyCap() async {
        guard let user = authViewModel.currentUser else { return }
        let currentCap = user.maxDailyReviews ?? 20
        guard dailyCapDraft != currentCap else { return }

        isSavingDailyCap = true
        dailyCapMessage = nil
        do {
            try await authViewModel.updateProfile(
                email: user.email,
                timezone: user.timezone,
                visibility: user.visibility,
                maxDailyReviews: dailyCapDraft
            )
            dailyCapMessage = "Daily limit updated"
            await loadData()
        } catch {
            dailyCapMessage = "Failed to update daily limit"
        }
        isSavingDailyCap = false
    }



    private func findSolveForRevision(_ revision: Revision) -> Solve? {
        if let revSolve = revision.solve {
            let problem = Problem(
                platform: revision.problem.platform,
                slug: revision.problem.slug,
                title: revision.problem.title,
                difficulty: revision.problem.difficulty,
                category: revision.problem.category,
                topic: revision.problem.topic,
                subtopic: revision.problem.subtopic
            )
            let submission = Submission(
                language: "unknown",
                happenedAt: revSolve.solvedAt,
                aiAnalysis: revSolve.aiAnalysis,
                mistakeTags: revSolve.mistakeTags,
                cognitiveTier: revSolve.cognitiveTier,
                recallScore: revSolve.recallScore,
                numberOfTries: nil,
                timeTaken: nil,
                attempts: revSolve.attempts
            )
            return Solve(
                id: revSolve.id,
                xpAwarded: revSolve.xpAwarded,
                solvedAt: revSolve.solvedAt,
                aiAnalysis: revSolve.aiAnalysis,
                mistakeTags: revSolve.mistakeTags,
                cognitiveTier: revSolve.cognitiveTier,
                recallScore: revSolve.recallScore,
                attempts: revSolve.attempts,
                problem: problem,
                submission: submission,
                highlight: nil
            )
        }
        let solves = DataManager.shared.recentSolves ?? []
        return solves.first { $0.problem.slug == revision.problem.slug }
    }

    private func findTodaySolveForRevision(_ revision: Revision) -> Solve? {
        let solves = DataManager.shared.recentSolves ?? []
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return solves.first { solve in
            guard solve.problem.slug == revision.problem.slug else { return false }
            var date = formatter.date(from: solve.solvedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: solve.solvedAt)
            }
            if let solveDate = date {
                return calendar.isDateInToday(solveDate)
            }
            return false
        }
    }

    private func groupRevisionsByDate(_ revisions: [Revision]) -> [RevisionGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        var grouped: [String: [Revision]] = [:]
        for revision in revisions {
            let key = formatter.string(from: revision.scheduledDate)
            grouped[key, default: []].append(revision)
        }

        return grouped
            .map { key, items in
                let sorted = items.sorted { $0.scheduledDate < $1.scheduledDate }
                return RevisionGroup(date: key, revisions: sorted, count: sorted.count)
            }
            .sorted { $0.displayDate < $1.displayDate }
    }
}

