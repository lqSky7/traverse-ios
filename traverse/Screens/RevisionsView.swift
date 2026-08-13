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
    @State private var showCompletedRevisions = false
    @State private var notificationsEnabled = false
    @State private var useMLRevision = false
    @State private var selectedRevision: Revision?
    @State private var selectedRevisionForCoach: Revision? = nil
    @State private var showMLInfoSheet = false
    @State private var showDailyLimitSheet = false
    @State private var dailyCapDraft: Int = 20
    @State private var isSavingDailyCap = false
    @State private var dailyCapMessage: String?
    @AppStorage("revisionMode") private var revisionMode: String = "normal"
    @State private var loadTask: Task<Void, Never>?
    @State private var isSubscribed = false
    @State private var showProUpgradeSheet = false
    @State private var mlTab: MLTab = .upcoming
    @State private var showPauseConfirm = false
    @State private var showResumeConfirm = false
    @State private var pauseDaysInput: Int = 7
    @State private var backlogDaysInput: Int = 3
    @State private var isPausingOrResuming = false

    // Exam mode caching to prevent flicker on load
    @AppStorage("cachedExamModeActive") private var isExamModeActive: Bool = false

    // Subscription caching - only check once per day at 00:01
    @AppStorage("cachedSubscriptionStatus") private var cachedSubscriptionStatus: Bool = false
    @AppStorage("lastSubscriptionCheckDate") private var lastSubscriptionCheckDate: Double = 0

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
                            if useMLRevision {
                                if isSubscribed {
                                    Picker("ML View", selection: $mlTab) {
                                        ForEach(MLTab.allCases) { tab in
                                            Text(tab.rawValue).tag(tab)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                if mlTab == .analytics {
                                    if isAnalyticsLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                                            .padding(.top, 8)
                                    } else if let analytics = analytics {
                                        RevisionAnalyticsSection(analytics: analytics)
                                    } else if let analyticsError = analyticsError {
                                        Text(analyticsError)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if !useMLRevision || mlTab == .upcoming {
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
                                            useMLMode: useMLRevision,
                                            onComplete: { revision in
                                                await completeRevision(revision)
                                            },
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showMLInfoSheet = true }) {
                            Label("How ML Scheduling Works", systemImage: "brain.head.profile")
                        }

                        Button(action: { showDailyLimitSheet = true }) {
                            Label("Daily Revision Limit", systemImage: "slider.horizontal.3")
                        }

                        if !useMLRevision {
                            Toggle(isOn: $showCompletedRevisions) {
                                Label("Show Completed", systemImage: showCompletedRevisions ? "checkmark.circle.fill" : "circle")
                            }
                            .onChange(of: showCompletedRevisions) { _, _ in
                                Task { await loadData() }
                            }
                        }

                        if !isSubscribed {
                            Toggle(isOn: Binding(
                                get: { useMLRevision },
                                set: { newValue in
                                    if newValue {
                                        // User is trying to enable ML - force check subscription status
                                        Task {
                                            await checkSubscriptionStatus(forceCheck: true)
                                            await MainActor.run {
                                                if isSubscribed {
                                                    useMLRevision = true
                                                    revisionMode = "ml"
                                                    Task { await loadData(forceType: "ml") }
                                                } else {
                                                    // Not subscribed - show upgrade sheet
                                                    showProUpgradeSheet = true
                                                }
                                            }
                                        }
                                    } else {
                                        // Turning off ML - no need to check subscription
                                        useMLRevision = false
                                        revisionMode = "normal"
                                        Task { await loadData(forceType: "normal") }
                                    }
                                }
                            )) {
                                Label("ML-Based Scheduling", systemImage: useMLRevision ? "brain.head.profile.fill" : "brain.head.profile")
                            }
                        }
                        
                        Divider()
                        
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
            useMLRevision = revisionMode == "ml"
            if cachedSubscriptionStatus {
                useMLRevision = true
                revisionMode = "ml"
            }
            dailyCapDraft = authViewModel.currentUser?.maxDailyReviews ?? 20
            // Load from cache first
            if !DataManager.shared.revisionGroups.isEmpty {
                revisionGroups = DataManager.shared.revisionGroups
            }
            if let cachedStats = DataManager.shared.revisionStats {
                stats = cachedStats
            }
            Task {
                await checkSubscriptionStatus(reloadIfNeeded: false)
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
    
    private func loadData(forceType: String? = nil) async {
        loadTask?.cancel()
        
        let revisionType = forceType ?? (useMLRevision ? "ml" : "normal")
        
        loadTask = Task {
            guard !Task.isCancelled else { return }
            await loadStats(type: revisionType)
            
            guard !Task.isCancelled else { return }
            await loadRevisions(type: revisionType)

            guard !Task.isCancelled else { return }
            if revisionType == "ml" {
                await loadAnalytics()
            } else {
                analytics = nil
                analyticsError = nil
                isAnalyticsLoading = false
                do {
                    todaySummary = try await NetworkService.shared.getTodayRevisions()
                    if let isPaused = todaySummary?.isPaused {
                        isExamModeActive = isPaused
                    }
                } catch {
                    print("Failed to check today summary: \(error.localizedDescription)")
                }
            }
        }
        
        await loadTask?.value
    }
    
    private func loadStats(type: String) async {
        do {
            stats = try await NetworkService.shared.getRevisionStats(type: type)
        } catch {
            print("Failed to load revision stats: \(error.localizedDescription)")
        }
    }
    
    private func loadRevisions(type: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            if type == "ml" {
                let response = try await NetworkService.shared.getTodayRevisions()
                todaySummary = response
                if let isPaused = response.isPaused {
                    isExamModeActive = isPaused
                }
                revisionGroups = groupRevisionsByDate(response.revisions)

                if notificationsEnabled {
                    await NotificationManager.shared.scheduleRevisionNotifications(for: response.revisions)
                }
            } else {
                let response = try await NetworkService.shared.getGroupedRevisions(
                    includeCompleted: showCompletedRevisions,
                    type: type
                )
                revisionGroups = response.groups

                if notificationsEnabled {
                    let allRevisions = response.groups.flatMap { $0.revisions }
                    await NotificationManager.shared.scheduleRevisionNotifications(for: allRevisions)
                }
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
        DataManager.shared.revisionMode = useMLRevision ? "ml" : "normal"
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
    
    private func checkSubscriptionStatus(forceCheck: Bool = false, reloadIfNeeded: Bool = true) async {
        // Use cached value first
        isSubscribed = cachedSubscriptionStatus

        // Check if we need to refresh from network
        let now = Date()
        let lastCheckDate = Date(timeIntervalSince1970: lastSubscriptionCheckDate)
        let calendar = Calendar.current

        // Calculate 00:01 today
        let todayStart = calendar.startOfDay(for: now)
        guard let todayAt0001 = calendar.date(byAdding: .minute, value: 1, to: todayStart) else { return }

        // Only fetch from network if:
        // 1. forceCheck is true (ML toggle was pressed), OR
        // 2. It's past 00:01 today AND we haven't checked today yet
        let lastCheckWasBeforeToday = !calendar.isDate(lastCheckDate, inSameDayAs: now)
        let isPast0001 = now >= todayAt0001
        let shouldRefresh = forceCheck || (isPast0001 && lastCheckWasBeforeToday)

        guard shouldRefresh else {
            await MainActor.run {
                if isSubscribed {
                    if !useMLRevision {
                        useMLRevision = true
                        revisionMode = "ml"
                        if reloadIfNeeded {
                            Task { await loadData(forceType: "ml") }
                        }
                    }
                } else if useMLRevision {
                    useMLRevision = false
                    revisionMode = "normal"
                    if reloadIfNeeded {
                        Task { await loadData(forceType: "normal") }
                    }
                }
            }
            return
        }

        do {
            let status = try await NetworkService.shared.getSubscriptionStatus()
            await MainActor.run {
                isSubscribed = status.isSubscriptionActive
                cachedSubscriptionStatus = status.isSubscriptionActive
                lastSubscriptionCheckDate = now.timeIntervalSince1970

                if isSubscribed {
                    if !useMLRevision {
                        useMLRevision = true
                        revisionMode = "ml"
                        if reloadIfNeeded {
                            Task { await loadData(forceType: "ml") }
                        }
                    }
                } else if useMLRevision {
                    useMLRevision = false
                    revisionMode = "normal"
                    if reloadIfNeeded {
                        Task { await loadData(forceType: "normal") }
                    }
                }
            }
        } catch {
            print("Failed to check subscription status: \(error.localizedDescription)")
            // Keep using cached value on error
        }
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
            let revisionType = useMLRevision ? "ml" : "normal"
            let response = try await NetworkService.shared.getRevisions(
                upcoming: true,
                limit: 1000,
                type: revisionType
            )
            await NotificationManager.shared.scheduleRevisionNotifications(for: response.revisions)
            await NotificationManager.shared.scheduleDailyRevisionReminder()
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }
    
    private func completeRevision(_ revision: Revision) async {
        do {
            _ = try await NetworkService.shared.completeRevision(id: revision.id)
            HapticManager.shared.success()

            // Notify HomeView to refresh and check live activity
            NotificationCenter.default.post(name: .revisionCompleted, object: nil)

            await loadData()
        } catch {
            print("Failed to complete revision: \(error.localizedDescription)")
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
            showPauseConfirm = false
            await loadData(forceType: "ml")
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
            await loadData(forceType: "ml")
        } catch {
            print("Failed to resume revisions: \(error.localizedDescription)")
            isExamModeActive = true
            HapticManager.shared.error()
        }
        isPausingOrResuming = false
    }

    private func formattedPausedDate(_ dateString: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
            await loadData(forceType: "ml")
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

struct RevisionGroupCard: View {
    let group: RevisionGroup
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onOpenCoach: (Revision) -> Void
    let onDelete: (Revision) async -> Void
    let onReschedule: (Revision, Int) async -> Void
    let onDeleteProblem: (Revision) async -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header - OUTSIDE the card as section header
            HStack(spacing: 8) {
                Image(systemName: dateIcon)
                    .foregroundStyle(dateColor)
                    .font(.caption)
                Text(formattedDate.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(group.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(dateColor)
            }
            .padding(.horizontal, 4)
            
            // Card with revisions
            VStack(spacing: 0) {
                ForEach(Array(group.revisions.enumerated()), id: \.element.id) { index, revision in
                    RevisionCard(
                         revision: revision,
                         useMLMode: useMLMode,
                         onComplete: onComplete,
                         onOpenCoach: onOpenCoach,
                         onDelete: onDelete,
                         onReschedule: onReschedule,
                         onDeleteProblem: onDeleteProblem
                    )
                    
                    // Add inset divider between items (not after last)
                    if index < group.revisions.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: group.displayDate)
    }
    
    private var dateIcon: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.displayDate) {
            return "calendar.badge.clock"
        } else if calendar.isDateInTomorrow(group.displayDate) {
            return "calendar.badge.plus"
        } else {
            return "calendar"
        }
    }
    
    private var dateColor: Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.displayDate) {
            return paletteManager.color(at: 2)
        } else {
            return paletteManager.color(at: 4)
        }
    }
}

struct RevisionCard: View {
    let revision: Revision
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onOpenCoach: (Revision) -> Void
    let onDelete: (Revision) async -> Void
    let onReschedule: (Revision, Int) async -> Void
    let onDeleteProblem: (Revision) async -> Void
    @State private var isCompleting = false
    @State private var isDeleting = false
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    private var difficultyColor: Color {
        switch revision.problem.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(difficultyColor)
                .frame(width: 4)
                .cornerRadius(4)
            
            Button(action: { onOpenCoach(revision) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(revision.problem.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(revision.problem.platform.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("Revision #\(revision.revisionNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // AI Coach Button
            Button(action: { onOpenCoach(revision) }) {
                Image(systemName: "sparkles")
                    .foregroundStyle(paletteManager.color(at: 3))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(6)
                    .background(paletteManager.color(at: 3).opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            if !useMLMode {
                if revision.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(paletteManager.color(at: 1))
                        .font(.title2)
                } else {
                    Button(action: {
                        Task {
                            isCompleting = true
                            await onComplete(revision)
                            isCompleting = false
                        }
                    }) {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .font(.title2)
                        }
                    }
                    .disabled(isCompleting)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .opacity(revision.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            Button {
                onOpenCoach(revision)
            } label: {
                Label("AI Revision Coach & Hints", systemImage: "sparkles")
            }
            if !revision.isCompleted {
                Button {
                    Task {
                        await onReschedule(revision, 7)
                    }
                } label: {
                    Label("Reschedule 7 Days Later", systemImage: "calendar.badge.plus")
                }
                
                Button {
                    Task {
                        await onReschedule(revision, 14)
                    }
                } label: {
                    Label("Reschedule 14 Days Later", systemImage: "calendar.badge.plus")
                }
                
                Button(role: .destructive) {
                    Task {
                        await onDeleteProblem(revision)
                    }
                } label: {
                    Label("Remove from Revision List", systemImage: "trash")
                }
                
                if useMLMode {
                    Divider()
                    Button(role: .destructive) {
                        Task {
                            isDeleting = true
                            await onDelete(revision)
                            isDeleting = false
                        }
                    } label: {
                        Label("Delete Single ML Revision", systemImage: "minus.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Stat Badge for Floating Toolbar
struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Daily Review Limit Card
struct DailyReviewLimitCard: View {
    let currentCap: Int
    @Binding var draftCap: Int
    let isSaving: Bool
    let message: String?
    let summary: RevisionTodayResponse?
    let onSave: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Daily Review Limit")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text("Cap the number of ML revisions shown each day. Overflow rolls into the next days.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: $draftCap, in: 1...200) {
                HStack {
                    Text("Max per day")
                        .font(.subheadline)
                    Spacer()
                    Text("\(draftCap)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }

            if let summary = summary {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.revisions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(paletteManager.color(at: 1))
                        Text("Showing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.total)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Total Due")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.overflow)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(paletteManager.color(at: 0))
                        Text("Overflow")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("Save Limit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .tint(paletteManager.selectedPalette.primary)
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || draftCap == currentCap)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Daily Review Limit Sheet
struct DailyReviewLimitSheet: View {
    let currentCap: Int
    @Binding var draftCap: Int
    let isSaving: Bool
    let message: String?
    let summary: RevisionTodayResponse?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    DailyReviewLimitCard(
                        currentCap: currentCap,
                        draftCap: $draftCap,
                        isSaving: isSaving,
                        message: message,
                        summary: summary,
                        onSave: onSave
                    )
                    .padding(20)
                }
            }
            .navigationTitle("Daily Revision Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.height(420), .medium])
    }
}

// MARK: - Revision Analytics Section
struct RevisionAnalyticsSection: View {
    let analytics: RevisionAnalyticsResponse

    var body: some View {
        VStack(spacing: 16) {
            RevisionOverviewCard(overview: analytics.overview, streaks: analytics.streaks)
            RevisionStabilityDistributionCard(distribution: analytics.stabilityDistribution)
            RevisionAccuracyTrendCard(points: analytics.accuracyTrend)
            RevisionIntervalGrowthCard(points: analytics.averageIntervalGrowth)
            RevisionProjectedLoadCard(points: analytics.projectedLoad)
            RevisionRetentionRiskCard(items: analytics.retentionHeatmap)
        }
    }
}

struct RevisionOverviewCard: View {
    let overview: RevisionAnalyticsOverview
    let streaks: RevisionAnalyticsStreaks
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private var retrievabilityPercent: String {
        String(format: "%.0f", overview.averageRetrievability * 100)
    }

    private var successRatePercent: String {
        String(format: "%.0f", streaks.overallSuccessRate * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(paletteManager.color(at: 3))
                Text("Revision Analytics")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(overview.totalProblemsTracked)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Problems Tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(retrievabilityPercent)%")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 1))
                    Text("Avg Retrievability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(successRatePercent)%")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Success Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct RevisionStabilityDistributionCard: View {
    let distribution: RevisionStabilityDistribution
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private struct Bucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    private var buckets: [Bucket] {
        [
            Bucket(label: "Critical", count: distribution.critical, color: paletteManager.color(at: 0)),
            Bucket(label: "Weak", count: distribution.weak, color: paletteManager.color(at: 1)),
            Bucket(label: "Developing", count: distribution.developing, color: paletteManager.color(at: 2)),
            Bucket(label: "Strong", count: distribution.strong, color: paletteManager.color(at: 3)),
            Bucket(label: "Mastered", count: distribution.mastered, color: paletteManager.color(at: 4)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(paletteManager.color(at: 4))
                Text("Retention Health")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Bucket", bucket.label),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(bucket.color.gradient)
                .cornerRadius(3)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks(values: buckets.map { $0.label }) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct RevisionAccuracyTrendCard: View {
    let points: [RevisionAccuracyPoint]
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private var sortedPoints: [RevisionAccuracyPoint] {
        points.sorted { $0.date < $1.date }
    }

    private var averageRate: Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.successRate }.reduce(0, +) / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(paletteManager.color(at: 5))
                Text("Accuracy Trend")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 12) {
                Text(String(format: "%.0f%%", averageRate * 100))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 5))
                Text("30-day average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedPoints.isEmpty {
                Text("No recent attempts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(Array(sortedPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Accuracy", point.successRate * 100)
                    )
                    .foregroundStyle(paletteManager.color(at: 5))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Accuracy", point.successRate * 100)
                    )
                    .foregroundStyle(paletteManager.color(at: 5).opacity(0.2))
                }
                .frame(height: 110)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct RevisionProjectedLoadCard: View {
    let points: [RevisionProjectedLoad]
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private struct LoadBar: Identifiable {
        let id = UUID()
        let dayIndex: Int
        let count: Int
        let kind: String
    }

    private var series: [LoadBar] {
        let sorted = points.sorted { $0.date < $1.date }
        return sorted.enumerated().flatMap { index, point in
            var bars: [LoadBar] = [LoadBar(dayIndex: index, count: point.dueCount, kind: "Due")]
            if point.overdueCount > 0 {
                bars.append(LoadBar(dayIndex: index, count: point.overdueCount, kind: "Overdue"))
            }
            return bars
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(paletteManager.color(at: 6))
                Text("Projected Load")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            if series.isEmpty {
                Text("No upcoming data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(series) { bar in
                    BarMark(
                        x: .value("Day", bar.dayIndex),
                        y: .value("Count", bar.count)
                    )
                    .foregroundStyle(bar.kind == "Overdue" ? paletteManager.color(at: 0) : paletteManager.color(at: 6))
                    .position(by: .value("Type", bar.kind))
                    .cornerRadius(2)
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: [0, 3, 6]) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self) {
                                Text(index == 0 ? "Today" : "T+\(index)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(paletteManager.color(at: 6))
                            .frame(width: 8, height: 8)
                        Text("Due")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(paletteManager.color(at: 0))
                            .frame(width: 8, height: 8)
                        Text("Overdue")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct RevisionIntervalGrowthCard: View {
    let points: [RevisionIntervalGrowth]
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private struct IntervalPoint: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let avgInterval: Double
        let count: Int
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func parseMonthDate(_ raw: String) -> Date? {
        if let date = Self.monthFormatter.date(from: raw) {
            return date
        }
        if let date = Self.monthDayFormatter.date(from: raw) {
            return date
        }
        if let date = Self.isoFractionalFormatter.date(from: raw) {
            return date
        }
        if let date = Self.isoFormatter.date(from: raw) {
            return date
        }
        return nil
    }

    private func monthLabel(for date: Date?, fallback: String) -> String {
        guard let date = date else { return fallback }
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date()) ? "MMM" : "MMM yy"
        return formatter.string(from: date)
    }

    private var intervalPoints: [IntervalPoint] {
        let sorted = points.sorted { lhs, rhs in
            let left = parseMonthDate(lhs.month)
            let right = parseMonthDate(rhs.month)
            switch (left, right) {
            case let (l?, r?): return l < r
            case (_?, nil): return false
            case (nil, _?): return true
            default: return lhs.month < rhs.month
            }
        }

        return sorted.enumerated().map { index, point in
            let date = parseMonthDate(point.month)
            return IntervalPoint(
                index: index,
                label: monthLabel(for: date, fallback: point.month),
                avgInterval: point.avgInterval,
                count: point.count
            )
        }
    }

    private var latestInterval: Double? {
        intervalPoints.last?.avgInterval
    }

    private var intervalDelta: Double? {
        guard intervalPoints.count >= 2 else { return nil }
        return intervalPoints[intervalPoints.count - 1].avgInterval - intervalPoints[intervalPoints.count - 2].avgInterval
    }

    private var axisIndices: [Int] {
        let count = intervalPoints.count
        guard count > 0 else { return [] }
        if count <= 4 {
            return intervalPoints.map { $0.index }
        }
        let mid = count / 2
        return [0, mid, count - 1]
    }

    private func formatInterval(_ value: Double?) -> String {
        guard let value = value else { return "0" }
        return String(format: "%.1f", value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(paletteManager.color(at: 4))
                Text("Interval Growth")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatInterval(latestInterval))d")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 4))
                    Text("Latest average interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let delta = intervalDelta {
                    Divider()
                        .frame(height: 44)

                    HStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(delta >= 0 ? paletteManager.color(at: 3) : paletteManager.color(at: 0))
                        Text(String(format: "%+.1fd", delta))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(delta >= 0 ? paletteManager.color(at: 3) : paletteManager.color(at: 0))
                    }
                }
            }

            if intervalPoints.isEmpty {
                Text("Not enough history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(intervalPoints) { point in
                    LineMark(
                        x: .value("Month", point.index),
                        y: .value("Avg Interval", point.avgInterval)
                    )
                    .foregroundStyle(paletteManager.color(at: 4))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    AreaMark(
                        x: .value("Month", point.index),
                        y: .value("Avg Interval", point.avgInterval)
                    )
                    .foregroundStyle(paletteManager.color(at: 4).opacity(0.2))
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: axisIndices) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self),
                               let label = intervalPoints.first(where: { $0.index == index })?.label {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct RevisionRetentionRiskCard: View {
    let items: [RevisionRetentionItem]
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private struct RiskItem: Identifiable {
        let id = UUID()
        let index: Int
        let title: String
        let shortTitle: String
        let retrievability: Double
        let lapses: Int
        let isLeech: Bool
    }

    private var focusItems: [RiskItem] {
        let filtered = items.filter { $0.isLeech || $0.lapses > 0 || $0.retrievability < 0.7 }
        let base = filtered.isEmpty ? items : filtered
        let sorted = base.sorted {
            if $0.isLeech != $1.isLeech { return $0.isLeech && !$1.isLeech }
            if $0.retrievability != $1.retrievability { return $0.retrievability < $1.retrievability }
            return $0.lapses > $1.lapses
        }

        return Array(sorted.prefix(6)).enumerated().map { index, item in
            let short = item.problemTitle.count > 12 ? String(item.problemTitle.prefix(12)) + "..." : item.problemTitle
            return RiskItem(
                index: index,
                title: item.problemTitle,
                shortTitle: short,
                retrievability: item.retrievability,
                lapses: item.lapses,
                isLeech: item.isLeech
            )
        }
    }

    private var leechCount: Int {
        items.filter { $0.isLeech }.count
    }

    private var lowRetrievabilityCount: Int {
        items.filter { $0.retrievability < 0.6 }.count
    }

    private func barColor(for item: RiskItem) -> Color {
        if item.isLeech || item.retrievability < 0.5 {
            return paletteManager.color(at: 0)
        }
        if item.retrievability < 0.7 {
            return paletteManager.color(at: 1)
        }
        return paletteManager.color(at: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(paletteManager.color(at: 0))
                Text("At-Risk Problems")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(leechCount)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Leeches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(lowRetrievabilityCount)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 1))
                    Text("Below 60%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if focusItems.isEmpty {
                Text("No at-risk items yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(focusItems) { item in
                    BarMark(
                        x: .value("Retrievability", item.retrievability * 100),
                        y: .value("Problem", item.shortTitle)
                    )
                    .foregroundStyle(barColor(for: item))
                    .cornerRadius(2)
                }
                .frame(height: 130)
                .chartXAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            if let number = value.as(Int.self) {
                                Text("\(number)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(focusItems) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(barColor(for: item))
                                .frame(width: 6, height: 6)
                            Text(item.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", item.retrievability * 100))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - ML Scheduling Info Sheet
struct MLSchedulingInfoSheet: View {
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTechnicalDetails = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Hero Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 44))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                        
                        Text("FSRS-5 Spaced Repetition")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Power-Law Forgetting Curve Scheduling")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                
                // What is this section
                Section {
                    Text("This is an ML-powered spaced repetition system based on FSRS-5 (Free Spaced Repetition Scheduler). Instead of static intervals (1d, 3d, 7d...), the algorithm tracks item-level Memory Stability (S) and Difficulty (D) to schedule reviews right when your retrievability reaches 90%.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Target Recall: 90% (R = 0.9)")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("— optimal spacing window")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("What is this?", systemImage: "questionmark.circle.fill")
                }
                
                // Features Section
                Section {
                    FeatureListRow(icon: "clock", text: "Time Spent Ratio (28%)", detail: "Ratio vs your personal median time per difficulty", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "gauge.medium", text: "Problem Difficulty (18%)", detail: "Intrinsic problem baseline (Easy / Medium / Hard)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "exclamationmark.triangle", text: "Mistake Tags (18%)", detail: "Penalties for approach, TLE, syntax, or DS errors", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "arrow.counterclockwise", text: "Number of Retries (15%)", detail: "Softly scaled runs (typos & code runs non-punitive)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "calendar.badge.clock", text: "Spacing Bonus (13%)", detail: "Logarithmic reward for long-gap successful recall", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "number", text: "Attempt Number (8%)", detail: "Review iteration expectation adjustment", iconColor: paletteManager.selectedPalette.primary)
                } header: {
                    Label("6 Quality Signals We Track", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Signals compute a Quality Score (q ∈ [0, 1]) mapped to FSRS grades (Again, Hard, Good, Easy) to scale stability.")
                }
                
                // Technical Details Section
                Section {
                    DisclosureGroup(isExpanded: $showTechnicalDetails) {
                        VStack(alignment: .leading, spacing: 10) {
                            TechRow(label: "Algorithm", value: "FSRS-5 (Free Spaced Repetition)")
                            TechRow(label: "Curve Model", value: "Power-Law Forgetting")
                            TechRow(label: "Key States", value: "Stability (S) & Difficulty (D)")
                            TechRow(label: "Target Recall", value: "90% Retrievability (R = 0.9)")
                            TechRow(label: "Clustering Prevention", value: "±10% Dynamic Interval Fuzzing")
                            
                            Divider()
                            
                            Text("Power-Law Forgetting Curve")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("R(t, S) = (1 + 19/81 * (t / S))^(-0.5)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Retrievability R(t, S) represents recall probability after t days. At t = S, recall probability is exactly 90%.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            Text("Stability Recall Growth")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("S' = S * e^(w8) * (11 - D) * S^(-w9) * (e^(w10*(1-R)) - 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Successful recall expands stability S according to the spacing effect, while lapse/failure resets stability.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            Text("Next Review Interval")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("I = (S / (19/81)) * (0.9^(-2) - 1) ≈ S")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Reviews are scheduled right before memory retrievability drops below 90%, preventing item decay.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Under the hood", systemImage: "cpu")
                    }
                }
                
                // Got it Button
                Section {
                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .tint(paletteManager.color(at: 2))
                    .buttonStyle(.borderedProminent)
                    .modifier(LiquidGlassCapsuleButton())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .navigationTitle("Smart Revisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feature List Row
struct FeatureListRow: View {
    let icon: String
    let text: String
    let detail: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Tech Row
struct TechRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Easter Egg Helper
struct EasterEggHelper {
    static let quotes = [
        "Resting today makes memory stronger tomorrow. Go conquer those exams! 🎓✨",
        "Sharpening the sword before battle! Revisions will be waiting for your victorious return. ⚔️🧠",
        "Brains need off-time too. Good luck with your study grind! 📚🔥",
        "System offline for high-priority exam prep! Battery charging... ⚡️🔋",
        "Knowledge is consolidating in long-term memory storage... 💾💭",
        "Take a breather! Algorithms can wait, your exams come first! 🏆🚀",
        "Future coding grandmaster in exam mode! 🌟💻"
    ]

    static let patterns = [
        "(⌐■_■)  [ EXAM MODE ACTIVE ]",
        "🧠 ⚡️ 📚  [ BRAIN CHARGING ]",
        "🏖️ 🌴 ☕️  [ REVISIONS PAUSED ]",
        "✨ 🎓 🏆  [ CONQUER YOUR EXAMS ]"
    ]

    static func getTodayEasterEggMessage(date: Date = Date()) -> (pattern: String, quote: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        var hash: Int32 = 0
        for char in dateStr.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(char.value)
        }
        let index = Int(abs(hash))

        let quote = quotes[index % quotes.count]
        let pattern = patterns[index % patterns.count]

        return (pattern, quote)
    }
}

// MARK: - Exam Mode Active View
struct ExamModeActiveView: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    let isResuming: Bool
    let onResume: () -> Void

    @State private var dragPosition: CGPoint = CGPoint(x: 170, y: 140)
    @State private var tiltPosition: CGPoint = CGPoint(x: 170, y: 140)
    private let motionManager = CMMotionManager()

    var body: some View {
        VStack {
            Spacer()

            // Light & Tilt Shader Surface with Glass Container on Top
            ZStack {
                // Background Light & Tilt Shader Layer
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                paletteManager.selectedPalette.primary.opacity(0.8),
                                paletteManager.color(at: 2).opacity(0.6),
                                paletteManager.color(at: 1).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .layerEffect(
                        ShaderLibrary.shine(
                            .boundingRect,
                            .float2(tiltPosition),
                            .float(0.57),
                            .float(3.8)
                        ),
                        maxSampleOffset: .zero
                    )
                    .cornerRadius(32)
                    .shadow(color: paletteManager.selectedPalette.primary.opacity(0.35), radius: 24, x: 0, y: 12)

                // Glass Container on top of Shader Layer
                VStack(spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Exam Mode")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Button(action: onResume) {
                        HStack(spacing: 8) {
                            if isResuming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Stop Exam Mode")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .disabled(isResuming)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .modifier(LiquidGlassCardModifier())
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .padding(12)
            }
            .frame(maxWidth: 360)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragPosition = value.location
                        tiltPosition = value.location
                    }
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            if motionManager.isDeviceMotionAvailable {
                motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                    guard let motion = motion else { return }
                    let x = motion.attitude.roll
                    let y = motion.attitude.pitch
                    tiltPosition = CGPoint(x: 180 + CGFloat(x) * 350, y: 140 + CGFloat(y) * 350)
                }
            }
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

// MARK: - Pause Exam Mode Sheet
struct PauseExamModeSheet: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var pauseDays: Int
    let isSubmitting: Bool
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(paletteManager.selectedPalette.primary.opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                        }

                        Text("Pause Revisions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Pause scheduled revisions while preparing for exams. Your calendar feed will display daily quotes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Glass Stepper Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PAUSE DURATION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(pauseDays) Days")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Stepper("", value: $pauseDays, in: 1...30)
                                .labelsHidden()
                        }
                        .padding()
                        .modifier(LiquidGlassCardModifier())
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: { onConfirm(pauseDays) }) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm Pause")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(paletteManager.selectedPalette.primary.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(paletteManager.selectedPalette.primary.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Exam Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Resume Revisions Sheet
struct ResumeRevisionsSheet: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var backlogDays: Int
    let isSubmitting: Bool
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(paletteManager.selectedPalette.primary.opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                        }

                        Text("Resume Revisions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Spread accumulated backlog over a period of days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Glass Stepper Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SPREAD BACKLOG OVER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(backlogDays) Days")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Stepper("", value: $backlogDays, in: 1...14)
                                .labelsHidden()
                        }
                        .padding()
                        .modifier(LiquidGlassCardModifier())
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: { onConfirm(backlogDays) }) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Resume Schedule")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(paletteManager.selectedPalette.primary.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(paletteManager.selectedPalette.primary.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Catch Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RevisionsView()
        .environmentObject(AuthViewModel())
}

