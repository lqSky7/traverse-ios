//
//  OnPaperMainView.swift
//  traverse
//
//  OnPaper Project-Based Interview Readiness Companion Screen
//  Strictly adheres to Apple HIG, Traverse Design System, and zero emojis policy.
//

import SwiftUI
import Charts

public struct OnPaperMainView: View {
    @StateObject private var apiService = OnPaperAPIService.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    @State private var selectedTab = 0
    @State private var showReviewSheet = false
    @State private var showAccountSheet = false
    @State private var showInfoSheet = false
    @State private var infoSheetTitle = ""
    @State private var infoSheetExplanation = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Segmented Tab Picker
                    Picker("Navigation", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Curriculum").tag(1)
                        Text("Revisions").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onChange(of: selectedTab) { _, _ in
                        HapticManager.shared.selection()
                    }
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case 0:
                                overviewDashboardView
                            case 1:
                                curriculumAndSessionsView
                            case 2:
                                revisionsAndMasteryView
                            default:
                                overviewDashboardView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await apiService.refreshAll()
                    }
                }
            }
            .navigationTitle("Interview Prep")
            .navigationBarTitleDisplayMode(.large)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        HapticManager.shared.selection()
                        showAccountSheet = true
                    }) {
                        if let username = apiService.currentUsername {
                            Text(username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(paletteManager.selectedPalette.primary.opacity(0.15), in: Capsule())
                        } else {
                            Text("Sign In")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(UIColor.systemGray5), in: Capsule())
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.selection()
                        Task { await apiService.refreshAll() }
                    }) {
                        if apiService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .task {
                await apiService.refreshAll()
            }
            .sheet(isPresented: $showReviewSheet) {
                OnPaperFSRSReviewSheet()
            }
            .sheet(isPresented: $showAccountSheet) {
                OnPaperAccountSheet()
            }
            .sheet(isPresented: $showInfoSheet) {
                OnPaperInfoSheet(title: infoSheetTitle, explanation: infoSheetExplanation)
            }
        }
    }
    
    // MARK: - 1. Overview Dashboard
    private var overviewDashboardView: some View {
        VStack(spacing: 16) {
            // Top Row: Streak Card & Daily Goal Card
            HStack(spacing: 12) {
                // Streak Card (inspired by HomeView StreakCard)
                StreakHeroCard(
                    streak: apiService.summary?.currentStreak ?? 0,
                    paletteManager: paletteManager
                )
                
                // Daily Goal Card
                DailyGoalHeroCard(
                    isComplete: apiService.summary?.streakQualifiedToday ?? false,
                    paletteManager: paletteManager
                )
            }
            
            // Progress Multi-Metric Card (inspired by RevisionOverviewCard)
            OnPaperProgressMetricsCard(
                summary: apiService.summary,
                sessionsCount: apiService.sessions.count,
                dueCount: apiService.dueCards.count,
                mistakes: apiService.mistakes,
                paletteManager: paletteManager
            )
            
            // Due Spaced Revisions Quick Banner
            OnPaperSpacedRevisionsBanner(
                dueCount: apiService.dueCards.count,
                paletteManager: paletteManager,
                onStartReview: {
                    HapticManager.shared.selection()
                    showReviewSheet = true
                }
            )
            
            // FSRS Memory Strength Distribution (inspired by RevisionStabilityDistributionCard)
            OnPaperRetentionHealthCard(
                dueCards: apiService.dueCards,
                paletteManager: paletteManager,
                onShowInfo: {
                    infoSheetTitle = "Retention Health"
                    infoSheetExplanation = "Shows how many of your interview concepts fall into each memory strength tier based on FSRS-4.5 stability.\n\n• Critical (< 2 days): Needs immediate reinforcement.\n• Weak (2–7 days): Early-stage recall, scheduled for near-term review.\n• Developing (7–21 days): Solidifying concepts, intervals expanding.\n• Strong (21–60 days): High retention confidence.\n• Mastered (60+ days): Deeply internalized mental models."
                    showInfoSheet = true
                }
            )
            
            // Active Repositories Quick Glance
            OnPaperConnectedReposGlanceCard(
                projects: apiService.projects,
                paletteManager: paletteManager
            )
            
            // Cloud Synchronization & Endpoint Status
            OnPaperCloudStatusCard(
                isAuthenticated: apiService.authToken != nil,
                lastSync: apiService.lastSyncTime,
                region: apiService.region,
                paletteManager: paletteManager
            )
        }
    }
    
    // MARK: - 2. Curriculum & Sessions View
    private var curriculumAndSessionsView: some View {
        VStack(spacing: 16) {
            // Projects / Repositories Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Connected Repositories")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(apiService.projects.count) Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if apiService.projects.isEmpty {
                    EmptyStateCard(
                        icon: "folder.badge.gearshape",
                        title: "No Repositories Synchronized",
                        subtitle: "Run 'onpaper init' in your local project repository to build the natural chronological curriculum.",
                        paletteManager: paletteManager
                    )
                } else {
                    ForEach(apiService.projects) { project in
                        OnPaperProjectCard(project: project, paletteManager: paletteManager)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            
            // Sessions History Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 1))
                    Text("Learning Sessions History")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(apiService.sessions.count) Recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if apiService.sessions.isEmpty {
                    EmptyStateCard(
                        icon: "clock.arrow.circlepath",
                        title: "No Recorded Learning Sessions",
                        subtitle: "Start an interactive learning session in your IDE terminal using 'onpaper start-unit'.",
                        paletteManager: paletteManager
                    )
                } else {
                    ForEach(apiService.sessions) { session in
                        OnPaperSessionCard(session: session, paletteManager: paletteManager)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - 3. Revisions & Mastery View
    private var revisionsAndMasteryView: some View {
        VStack(spacing: 16) {
            // FSRS Flashcard Review Queue
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("FSRS Flashcard Queue")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if !apiService.dueCards.isEmpty {
                        Button(action: {
                            HapticManager.shared.selection()
                            showReviewSheet = true
                        }) {
                            Text("Start Review")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(paletteManager.selectedPalette.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                if apiService.dueCards.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Flashcards Reviewed")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text("Your memory retention schedule is completely up to date.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(apiService.dueCards) { card in
                        OnPaperCardRow(card: card, paletteManager: paletteManager)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            
            // Mistakes & Misconceptions Tracker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Misconceptions & Pitfalls")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(apiService.mistakes.count) Tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                if apiService.mistakes.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zero Active Misconceptions")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text("No recurring architectural or conceptual bugs detected.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(apiService.mistakes) { mistake in
                        OnPaperMistakeCard(mistake: mistake, paletteManager: paletteManager)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            
            // Concept Mastery Taxonomy
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Concept Mastery Taxonomy")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                if apiService.sessions.isEmpty && apiService.projects.isEmpty {
                    EmptyStateCard(
                        icon: "chart.bar.xaxis",
                        title: "No Concepts Assessed Yet",
                        subtitle: "Complete interactive exercises and rubric evaluations to establish competency benchmarks.",
                        paletteManager: paletteManager
                    )
                } else {
                    ForEach(apiService.projects) { project in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(project.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(project.curriculumStatus.capitalized)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(paletteManager.selectedPalette.primary)
                            }
                            
                            HStack(spacing: 6) {
                                ForEach(project.primaryLanguages, id: \.self) { lang in
                                    Text(lang)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08), in: Capsule())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Subcomponents & Cards

// MARK: - Streak Hero Card (Half Width)
struct StreakHeroCard: View {
    let streak: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var displayNumber: String {
        "\(streak)"
    }
    
    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: streak == 0 ? "flame" : "flame.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(streak == 0 ? .white.opacity(0.5) : .orange)
                
                Spacer()
                
                Text("STREAK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayNumber)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(daysText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            ZStack {
                Color(UIColor.systemGray6)
                if streak > 0 {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.20), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Daily Goal Hero Card (Half Width)
struct DailyGoalHeroCard: View {
    let isComplete: Bool
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isComplete ? .green : paletteManager.selectedPalette.primary)
                
                Spacer()
                
                Text("DAILY GOAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isComplete ? "Completed" : "Incomplete")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isComplete ? .green : .white)
                Text(isComplete ? "Target Met Today" : "Review unit to qualify")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            ZStack {
                Color(UIColor.systemGray6)
                if isComplete {
                    LinearGradient(
                        colors: [Color.green.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Progress Multi-Metric Card (Inspired by RevisionOverviewCard)
struct OnPaperProgressMetricsCard: View {
    let summary: OnPaperProgressSummary?
    let sessionsCount: Int
    let dueCount: Int
    let mistakes: [OnPaperMistake]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var totalSessions: Int {
        summary?.totalSessions ?? sessionsCount
    }
    
    private var activeMistakes: Int {
        summary?.activeMistakesCount ?? mistakes.filter { $0.status != "resolved" }.count
    }
    
    private var resolvedMistakes: Int {
        summary?.resolvedMistakesCount ?? mistakes.filter { $0.status == "resolved" }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(paletteManager.color(at: 0))
                Text("Curriculum Readiness")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalSessions)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dueCount)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 1))
                    Text("Due Cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(resolvedMistakes)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Resolved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Spaced Revisions Quick Banner
struct OnPaperSpacedRevisionsBanner: View {
    let dueCount: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    let onStartReview: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPACED REPETITION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("\(dueCount) Flashcards Scheduled")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                if dueCount > 0 {
                    Button(action: onStartReview) {
                        Text("Review Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(paletteManager.selectedPalette.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Text("Reviews are optimized mathematically via FSRS-4.5 to reinforce key patterns before decay.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Retention Health Distribution Card
struct OnPaperRetentionHealthCard: View {
    let dueCards: [OnPaperFSRSCard]
    @ObservedObject var paletteManager: ColorPaletteManager
    let onShowInfo: () -> Void
    
    private struct StabilityBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }
    
    private var buckets: [StabilityBucket] {
        let critical = dueCards.filter { $0.stability < 2.0 }.count
        let weak = dueCards.filter { $0.stability >= 2.0 && $0.stability < 7.0 }.count
        let developing = dueCards.filter { $0.stability >= 7.0 && $0.stability < 21.0 }.count
        let strong = dueCards.filter { $0.stability >= 21.0 && $0.stability < 60.0 }.count
        let mastered = dueCards.filter { $0.stability >= 60.0 }.count
        
        // Show realistic baseline defaults if no cards have been loaded yet
        let total = dueCards.count
        return [
            StabilityBucket(label: "Critical", count: total > 0 ? critical : 0, color: paletteManager.color(at: 0)),
            StabilityBucket(label: "Weak", count: total > 0 ? weak : 0, color: paletteManager.color(at: 1)),
            StabilityBucket(label: "Developing", count: total > 0 ? developing : 0, color: paletteManager.color(at: 2)),
            StabilityBucket(label: "Strong", count: total > 0 ? strong : 0, color: paletteManager.color(at: 3)),
            StabilityBucket(label: "Mastered", count: total > 0 ? mastered : 0, color: paletteManager.color(at: 4))
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(paletteManager.color(at: 4))
                Text("Retention Stability Tiers")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {
                    HapticManager.shared.selection()
                    onShowInfo()
                }) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Tier", bucket.label),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(bucket.color.gradient)
                .cornerRadius(3)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 110)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Connected Repositories Glance Card
struct OnPaperConnectedReposGlanceCard: View {
    let projects: [OnPaperProject]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(paletteManager.color(at: 1))
                Text("Connected Repositories")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(projects.count) Active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if projects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Repositories Synchronized")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Initialize your project with 'onpaper init' to sync curriculum units and learning sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(projects) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Languages: \(project.primaryLanguages.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(project.curriculumStatus.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(paletteManager.selectedPalette.primary.opacity(0.15), in: Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Cloud Architecture & Sync Card
struct OnPaperCloudStatusCard: View {
    let isAuthenticated: Bool
    let lastSync: Date?
    let region: String
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.caption)
                    .foregroundStyle(isAuthenticated ? .green : paletteManager.color(at: 0))
                Text("CLOUD ARCHITECTURE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isAuthenticated ? "Authenticated (\(region))" : "Connected (\(region))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isAuthenticated ? .green : .secondary)
            }
            
            if let lastSync = lastSync {
                Text("Last synchronized: \(lastSync.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Project Card
struct OnPaperProjectCard: View {
    let project: OnPaperProject
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(project.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(project.curriculumStatus.capitalized)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(paletteManager.selectedPalette.primary.opacity(0.2), in: Capsule())
                    .foregroundStyle(paletteManager.selectedPalette.primary)
            }
            
            Text("Project ID: \(project.projectId)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack {
                HStack(spacing: 4) {
                    ForEach(project.primaryLanguages, id: \.self) { lang in
                        Text(lang)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: project.gitAvailable ? "arrow.triangle.branch" : "folder")
                        .font(.caption2)
                    Text(project.gitAvailable ? "Git Synced" : "Standard")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Session Card
struct OnPaperSessionCard: View {
    let session: OnPaperSession
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session \(session.sessionId.prefix(8))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(session.state.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(session.state.contains("complete") ? .green : paletteManager.selectedPalette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (session.state.contains("complete") ? Color.green : paletteManager.selectedPalette.primary).opacity(0.15),
                        in: Capsule()
                    )
            }
            
            if let summary = session.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Text("Started: \(session.startedAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.durationSeconds > 0 {
                    Text("\(session.durationSeconds / 60) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Card Row
struct OnPaperCardRow: View {
    let card: OnPaperFSRSCard
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.prompt ?? card.conceptId ?? card.mistakeId ?? "Concept Card: \(card.cardId.prefix(8))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Text("\(card.reps) reps")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(paletteManager.selectedPalette.primary.opacity(0.12), in: Capsule())
            }
            
            if let userAns = card.userAnswer, !userAns.isEmpty {
                Text("Your answer: \"\(userAns)\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .italic()
            }
            
            HStack(spacing: 8) {
                Text("Due: \(card.dueAt)")
                Text("•")
                Text("Stability: \(String(format: "%.1f", card.stability))d")
                if let concept = card.conceptId {
                    Text("•")
                    Text(concept)
                        .foregroundStyle(paletteManager.color(at: 1))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mistake Card
struct OnPaperMistakeCard: View {
    let mistake: OnPaperMistake
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var severityColor: Color {
        switch mistake.severity.lowercased() {
        case "critical", "high":
            return .red
        case "medium", "warning":
            return .orange
        default:
            return paletteManager.selectedPalette.primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mistake.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(mistake.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(mistake.status == "resolved" ? .green : severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((mistake.status == "resolved" ? Color.green : severityColor).opacity(0.15), in: Capsule())
            }
            
            HStack(spacing: 6) {
                Text("Category: \(mistake.category.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Severity: \(mistake.severity.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(severityColor)
            }
            
            HStack {
                Text("Occurrences: \(mistake.occurrenceCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Resolved: \(mistake.resolvedCount)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Info Sheet (Matches Traverse AnalyticsInfoSheet 1:1)
struct OnPaperInfoSheet: View {
    let title: String
    let explanation: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Cognito Account Sheet
struct OnPaperAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = OnPaperAPIService.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    
    @State private var isSignUp = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isProcessing = false
    @State private var authError: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if apiService.authToken != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.green)
                            
                            Text("Signed In to OnPaper")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            if let name = apiService.currentUsername {
                                Text("Authenticated User: \(name)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button(action: {
                                HapticManager.shared.selection()
                                apiService.signOut()
                                dismiss()
                            }) {
                                Text("Sign Out")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color(white: 0.15), in: Capsule())
                            }
                            .padding(.top, 12)
                        }
                        .padding(30)
                    } else {
                        VStack(spacing: 16) {
                            Text(isSignUp ? "Create OnPaper Account" : "Sign In to OnPaper")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    TextField("Username", text: $username)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                if isSignUp {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        TextField("Email Address", text: $email)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .keyboardType(.emailAddress)
                                            .foregroundStyle(.white)
                                    }
                                    .padding(12)
                                    .background(Color(UIColor.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    SecureField("Password", text: $password)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            
                            if let error = authError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if let success = successMessage {
                                Text(success)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            
                            Button(action: handleAuth) {
                                if isProcessing {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .font(.headline)
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(paletteManager.selectedPalette.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .disabled(username.isEmpty || password.isEmpty || isProcessing)
                            .padding(.top, 4)
                            
                            Button(action: {
                                withAnimation {
                                    isSignUp.toggle()
                                    authError = nil
                                    successMessage = nil
                                }
                            }) {
                                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.footnote)
                                    .foregroundStyle(paletteManager.selectedPalette.primary)
                            }
                            .padding(.top, 6)
                        }
                        .padding(20)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func handleAuth() {
        HapticManager.shared.selection()
        isProcessing = true
        authError = nil
        successMessage = nil
        
        Task {
            do {
                if isSignUp {
                    try await apiService.registerWithCognito(username: username, email: email, password: password)
                    await MainActor.run {
                        self.isProcessing = false
                        HapticManager.shared.success()
                        dismiss()
                    }
                } else {
                    try await apiService.loginWithCognito(username: username, password: password)
                    await MainActor.run {
                        self.isProcessing = false
                        HapticManager.shared.success()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isProcessing = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - FSRS Flashcard Review Sheet
struct OnPaperFSRSReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = OnPaperAPIService.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    
    var currentCard: OnPaperFSRSCard? {
        if currentIndex < apiService.dueCards.count {
            return apiService.dueCards[currentIndex]
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let card = currentCard {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(paletteManager.selectedPalette.primary)
                                        .frame(
                                            width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(apiService.dueCards.count, 1)),
                                            height: 4
                                        )
                                }
                            }
                            .frame(height: 4)
                            
                            // Header metadata
                            HStack {
                                Text("Card \(currentIndex + 1) of \(apiService.dueCards.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Stability: \(String(format: "%.1f", card.stability))d")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Question Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("RECALL PROMPT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(paletteManager.color(at: 0))
                                    Spacer()
                                    Text("\(card.reps) reps")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(card.prompt ?? card.conceptId ?? card.mistakeId ?? "Assessed Architectural Concept")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                
                                if let concept = card.conceptId {
                                    Text("Focus: \(concept)")
                                        .font(.caption)
                                        .foregroundStyle(paletteManager.color(at: 1))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                            
                            // User's own previous answer
                            if let userAns = card.userAnswer, !userAns.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "quote.opening")
                                            .font(.caption2)
                                            .foregroundStyle(paletteManager.color(at: 2))
                                        Text("YOUR PREVIOUS ANSWER (In your words)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(paletteManager.color(at: 2))
                                    }
                                    
                                    Text(userAns)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .italic()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(white: 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(paletteManager.color(at: 2).opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            
                            if isAnswerRevealed {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("DETAILED EXPLANATION & MENTAL MODEL")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.green)
                                    
                                    Text(card.explanation ?? "Recall core invariant guarantees, boundary edge conditions, state transitions, and memory lifecycle tradeoffs.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .lineSpacing(4)
                                    
                                    if let takeaway = card.keyTakeaway, !takeaway.isEmpty {
                                        Divider()
                                            .background(Color.green.opacity(0.3))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("KEY TAKEAWAY")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                            Text(takeaway)
                                                .font(.footnote.weight(.medium))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(Color.green.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                
                                // Rating Controls (Again, Hard, Good, Easy)
                                VStack(spacing: 8) {
                                    Text("Rate recall precision:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack(spacing: 8) {
                                        Button("Again") { submitRating("Again") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .red))
                                        Button("Hard") { submitRating("Hard") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .orange))
                                        Button("Good") { submitRating("Good") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .blue))
                                        Button("Easy") { submitRating("Easy") }
                                            .buttonStyle(FSRSRatingButtonStyle(color: .green))
                                    }
                                }
                                .padding(.top, 8)
                            } else {
                                Button(action: {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isAnswerRevealed = true
                                    }
                                }) {
                                    Text("Reveal Explanation & Mental Model")
                                        .font(.headline)
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(paletteManager.selectedPalette.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .padding(.top, 12)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("Session Complete")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("All due flashcards for today have been reviewed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.white, in: Capsule())
                            .padding(.top, 8)
                    }
                    .padding(40)
                }
            }
            .navigationTitle("Revision Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func submitRating(_ rating: String) {
        guard let card = currentCard else { return }
        HapticManager.shared.selection()
        Task {
            _ = try? await apiService.submitFSRSReview(cardId: card.cardId, rating: rating)
            await MainActor.run {
                withAnimation {
                    isAnswerRevealed = false
                    currentIndex += 1
                }
            }
        }
    }
}

// MARK: - FSRS Rating Button Style
struct FSRSRatingButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

