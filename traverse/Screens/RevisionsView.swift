//
//  RevisionsView.swift
//  traverse
//

import SwiftUI
import Charts

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
    @State private var showMLAttemptSheet = false
    @State private var dailyCapDraft: Int = 20
    @State private var isSavingDailyCap = false
    @State private var dailyCapMessage: String?
    @AppStorage("revisionMode") private var revisionMode: String = "normal"
    @State private var loadTask: Task<Void, Never>?
    @State private var isSubscribed = false
    @State private var showProUpgradeSheet = false
    @State private var mlTab: MLTab = .upcoming
    @State private var isRecalibrating = false
    @State private var showRecalibrateConfirm = false

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

                            if mlTab == .upcoming {
                                DailyReviewLimitCard(
                                    currentCap: authViewModel.currentUser?.maxDailyReviews ?? 20,
                                    draftCap: $dailyCapDraft,
                                    isSaving: isSavingDailyCap,
                                    message: dailyCapMessage,
                                    summary: todaySummary,
                                    onSave: { Task { await saveDailyCap() } }
                                )
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
                                        onMLAttempt: { revision in
                                            selectedRevision = revision
                                            showMLAttemptSheet = true
                                        },
                                        onDelete: { revision in
                                            await deleteRevision(revision)
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
                                StatBadge(title: "Due Today", value: "\(stats.dueToday)", color: paletteManager.color(at: 2))
                                StatBadge(title: "Overdue", value: "\(stats.overdue)", color: paletteManager.color(at: 0))
                                StatBadge(title: "Done", value: "\(stats.completionRate)%", color: paletteManager.color(at: 1))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        } else {
                            HStack(spacing: 16) {
                                StatBadge(title: "Due Today", value: "\(stats.dueToday)", color: paletteManager.color(at: 2))
                                StatBadge(title: "Overdue", value: "\(stats.overdue)", color: paletteManager.color(at: 0))
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
            .navigationTitle("Revisions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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

                        if useMLRevision {
                            Button(action: { showRecalibrateConfirm = true }) {
                                Label("Recalibrate Schedule", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(isRecalibrating)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await loadData() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMLAttemptSheet) {
            if let revision = selectedRevision {
                MLAttemptSheet(revision: revision)
            }
        }
        .sheet(isPresented: $showProUpgradeSheet) {
            ProUpgradeSheet()
        }
        .confirmationDialog("Recalibrate ML schedule?", isPresented: $showRecalibrateConfirm, titleVisibility: .visible) {
            Button("Recalibrate Now", role: .destructive) {
                Task { await recalibrateRevisions() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reschedule all pending ML revisions starting today based on your daily cap.")
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
                todaySummary = nil
                analyticsError = nil
                isAnalyticsLoading = false
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
        do {
            try await NetworkService.shared.deleteRevision(id: revision.id)
            HapticManager.shared.success()
            await loadData()
        } catch {
            print("Failed to delete revision: \(error.localizedDescription)")
            HapticManager.shared.error()
        }
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

    private func recalibrateRevisions() async {
        guard !isRecalibrating else { return }
        isRecalibrating = true
        do {
            _ = try await NetworkService.shared.recalibrateMLRevisions()
            await loadData(forceType: "ml")
            if notificationsEnabled {
                await scheduleAllNotifications()
            }
        } catch { }
        isRecalibrating = false
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
    let onMLAttempt: (Revision) -> Void
    let onDelete: (Revision) async -> Void
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
                    RevisionCard(revision: revision, useMLMode: useMLMode, onComplete: onComplete, onMLAttempt: onMLAttempt, onDelete: onDelete)
                    
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
        } else if group.displayDate < Date() {
            return "calendar.badge.exclamationmark"
        } else {
            return "calendar"
        }
    }
    
    private var dateColor: Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.displayDate) {
            return paletteManager.color(at: 2)
        } else if group.displayDate < Date() {
            return paletteManager.color(at: 0)
        } else {
            return paletteManager.color(at: 4)
        }
    }
}

struct RevisionCard: View {
    let revision: Revision
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onMLAttempt: (Revision) -> Void
    let onDelete: (Revision) async -> Void
    @State private var isCompleting = false
    @State private var isDeleting = false
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(difficultyColor)
                .frame(width: 4)
                .cornerRadius(4)
            
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
            
            Spacer()
            
            if revision.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(paletteManager.color(at: 1))
                    .font(.title2)
            } else if useMLMode {
                Button(action: { onMLAttempt(revision) }) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(revision.isOverdue ? paletteManager.color(at: 0) : paletteManager.selectedPalette.primary)
                        .font(.title2)
                }
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
                            .foregroundStyle(revision.isOverdue ? paletteManager.color(at: 0) : paletteManager.selectedPalette.primary)
                            .font(.title2)
                    }
                }
                .disabled(isCompleting)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .opacity(revision.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            if useMLMode && !revision.isCompleted {
                Button(role: .destructive) {
                    Task {
                        isDeleting = true
                        await onDelete(revision)
                        isDeleting = false
                    }
                } label: {
                    Label("Delete Revision", systemImage: "trash")
                }
            }
        }
    }
    
    private var difficultyColor: Color {
        switch revision.problem.difficulty.lowercased() {
        case "easy":
            return paletteManager.color(at: 1)
        case "medium":
            return paletteManager.color(at: 2)
        case "hard":
            return paletteManager.color(at: 0)
        default:
            return .gray
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

// MARK: - ML Attempt Sheet
struct MLAttemptSheet: View {
    let revision: Revision
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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
                        
                        Text("LSTM Spaced Repetition")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Predicting your optimal review intervals")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                
                // What is this section
                Section {
                    Text("This is an ML-powered spaced repetition system. Instead of fixed review schedules (1 day, 3 days, 7 days...), our LSTM neural network learns YOUR learning patterns and predicts the perfect time for your next review.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("MAE: 1.78 days")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("— within ~2 days of optimal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("What is this?", systemImage: "questionmark.circle.fill")
                }
                
                // Features Section
                Section {
                    FeatureListRow(icon: "gauge.medium", text: "Problem difficulty", detail: "Easy / Medium / Hard", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "folder", text: "Category", detail: "Arrays, Trees, DP, Graphs...", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "number", text: "Attempt number", detail: "1st, 2nd, 3rd review...", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "calendar", text: "Days since last", detail: "Time gap between reviews", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "checkmark.circle", text: "Outcome", detail: "Success or failure — critical!", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "arrow.counterclockwise", text: "Number of tries", detail: "Submit attempts this session", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "clock", text: "Time spent", detail: "Minutes solving the problem", iconColor: paletteManager.selectedPalette.primary)
                } header: {
                    Label("7 Features We Track", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Every submission feeds into the model to improve predictions.")
                }
                
                // Technical Details Section
                Section {
                    DisclosureGroup(isExpanded: $showTechnicalDetails) {
                        VStack(alignment: .leading, spacing: 8) {
                            TechRow(label: "Architecture", value: "2-layer LSTM + BatchNorm")
                            TechRow(label: "Hidden size", value: "128 units")
                            TechRow(label: "Loss function", value: "Huber Loss")
                            TechRow(label: "Training data", value: "15,321 records")
                            TechRow(label: "Clusters", value: "5 learner patterns")
                            
                            Divider()
                            
                            Text("Exponential Decay Model")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("interval = -log(0.9) / exp(LSTM_output)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Recall probability decays exponentially. The LSTM learns your personal forgetting curve.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Under the hood", systemImage: "cpu")
                    }
                }
                
                // Buttons Section (not sticky, scrolls with content)
                Section {
                    VStack(spacing: 10) {
                        // Open Problem Button
                        Button(action: openProblem) {
                            Text("Solve: \(revision.problem.title)")
                                .font(.headline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .tint(paletteManager.selectedPalette.primary)
                        .buttonStyle(.borderedProminent)
                        .modifier(LiquidGlassCapsuleButton())
                        
                        // Got it Button
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
                    .padding(.vertical, 8)
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
    
    private func openProblem() {
        let baseURLs: [String: String] = [
            "leetcode": "https://leetcode.com/problems/",
            "codeforces": "https://codeforces.com/problemset/problem/",
            "hackerrank": "https://www.hackerrank.com/challenges/",
            "takeuforward": "https://takeuforward.org/practice/"
        ]
        
        if let baseURL = baseURLs[revision.problem.platform.lowercased()],
           let url = URL(string: "\(baseURL)\(revision.problem.slug)") {
            openURL(url)
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

#Preview {
    RevisionsView()
        .environmentObject(AuthViewModel())
}
