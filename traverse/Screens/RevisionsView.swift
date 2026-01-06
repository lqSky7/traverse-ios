//
//  RevisionsView.swift
//  traverse
//

import SwiftUI

struct RevisionsView: View {
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var revisionGroups: [RevisionGroup] = []
    @State private var stats: RevisionStatsResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCompletedRevisions = false
    @State private var notificationsEnabled = false
    @State private var useMLRevision = false
    @State private var selectedRevision: Revision?
    @State private var showMLAttemptSheet = false
    @AppStorage("revisionMode") private var revisionMode: String = "normal"
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
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
                        Toggle(isOn: $showCompletedRevisions) {
                            Label("Show Completed", systemImage: showCompletedRevisions ? "checkmark.circle.fill" : "circle")
                        }
                        .onChange(of: showCompletedRevisions) { _, _ in
                            Task { await loadData() }
                        }
                        
                        Toggle(isOn: $useMLRevision) {
                            Label("ML-Based Scheduling", systemImage: useMLRevision ? "brain.head.profile.fill" : "brain.head.profile")
                        }
                        .onChange(of: useMLRevision) { _, newValue in
                            revisionMode = newValue ? "ml" : "normal"
                            let typeToLoad = newValue ? "ml" : "normal"
                            Task { await loadData(forceType: typeToLoad) }
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
        .onAppear {
            useMLRevision = revisionMode == "ml"
            Task {
                await loadData()
                await checkNotificationStatus()
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
            let response = try await NetworkService.shared.getGroupedRevisions(
                includeCompleted: showCompletedRevisions,
                type: type
            )
            revisionGroups = response.groups
            
            if notificationsEnabled {
                let allRevisions = response.groups.flatMap { $0.revisions }
                await NotificationManager.shared.scheduleRevisionNotifications(for: allRevisions)
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
        
        isLoading = false
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
}
