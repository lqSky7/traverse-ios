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
                MLAttemptSheet(revision: revision) { outcome, numTries, timeSpent in
                    await recordMLAttempt(revision: revision, outcome: outcome, numTries: numTries, timeSpent: timeSpent)
                    showMLAttemptSheet = false
                }
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
    
    private func recordMLAttempt(revision: Revision, outcome: Int, numTries: Int, timeSpent: Double) async {
        do {
            let response = try await NetworkService.shared.recordRevisionAttempt(
                id: revision.id,
                outcome: outcome,
                numTries: numTries,
                timeSpentMinutes: timeSpent
            )
            HapticManager.shared.success()
            
            // You could surface response.prediction to the user as a toast/banner if desired
            print("Next review in \(response.prediction.nextReviewIntervalDays) days (Confidence: \(response.prediction.confidence))")
            
            await loadData()
        } catch {
            print("Failed to record ML attempt: \(error.localizedDescription)")
            HapticManager.shared.error()
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
}

struct RevisionGroupCard: View {
    let group: RevisionGroup
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onMLAttempt: (Revision) -> Void
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
                    RevisionCard(revision: revision, useMLMode: useMLMode, onComplete: onComplete, onMLAttempt: onMLAttempt)
                    
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
    @State private var isCompleting = false
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
    let onSubmit: (Int, Int, Double) async -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var outcome: Int = 1 // 0 = failed, 1 = success
    @State private var numTries: Int = 1
    @State private var timeSpent: Double = 10
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Problem Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(revision.problem.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            HStack {
                                Text(revision.problem.platform.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(revision.problem.difficulty.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(difficultyColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Outcome Toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Did you solve it today?")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Outcome", selection: $outcome) {
                                Text("Failed").tag(0)
                                Text("Success").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Number of Tries
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How many attempts?")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            HStack {
                                Button {
                                    if numTries > 1 { numTries -= 1; HapticManager.shared.success() }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(paletteManager.color(at: 0))
                                }
                                .disabled(numTries <= 1)
                                
                                Spacer()
                                
                                Text("\(numTries)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 60)
                                
                                Spacer()
                                
                                Button {
                                    if numTries < 20 { numTries += 1; HapticManager.shared.success() }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(paletteManager.color(at: 1))
                                }
                                .disabled(numTries >= 20)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Time Spent
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Time spent (minutes)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            HStack {
                                Slider(value: $timeSpent, in: 1...120, step: 1)
                                    .tint(paletteManager.selectedPalette.primary)
                                
                                Text("\(Int(timeSpent)) min")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 70, alignment: .trailing)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // Submit Button
                        Button(action: {
                            Task {
                                isSubmitting = true
                                await onSubmit(outcome, numTries, timeSpent)
                                HapticManager.shared.success()
                                isSubmitting = false
                                dismiss()
                            }
                        }) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Submit Attempt")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(paletteManager.selectedPalette.primary)
                        .cornerRadius(12)
                        .disabled(isSubmitting)
                    }
                    .padding()
                }
            }
            .navigationTitle("Record Attempt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
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

#Preview {
    RevisionsView()
}
