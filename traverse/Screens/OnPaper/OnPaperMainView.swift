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
