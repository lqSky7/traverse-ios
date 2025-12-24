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
                                RevisionGroupCard(group: group, onComplete: { revision in
                                    await completeRevision(revision)
                                })
                            }
                        }
                    }
                    .padding()
                    .padding(.top, 80) // Space for floating toolbar
                }
                
                // Floating Liquid Glass Stats Toolbar
                if let stats = stats {
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
            .navigationTitle("Revisions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle(isOn: $showCompletedRevisions) {
                            Label("Show Completed", systemImage: showCompletedRevisions ? "checkmark.circle.fill" : "circle")
                        }
                        .onChange(of: showCompletedRevisions) {
                            Task {
                                await loadRevisions()
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task {
                                await toggleNotifications()
                            }
                        }) {
                            Label(
                                notificationsEnabled ? "Disable Notifications" : "Enable Notifications",
                                systemImage: notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                            )
                        }
                        
                        Button(action: {
                            Task {
                                await scheduleAllNotifications()
                            }
                        }) {
                            Label("Reschedule All Notifications", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await loadData()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await loadData()
                await checkNotificationStatus()
            }
        }
    }
    
    private func loadData() async {
        await loadStats()
        await loadRevisions()
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
            let response = try await NetworkService.shared.getGroupedRevisions(includeCompleted: showCompletedRevisions)
            revisionGroups = response.groups
            
            // Schedule notifications for upcoming revisions
            if notificationsEnabled {
                let allRevisions = response.groups.flatMap { $0.revisions }
                await NotificationManager.shared.scheduleRevisionNotifications(for: allRevisions)
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load revisions"
        }
        
        isLoading = false
    }
    
    private func checkNotificationStatus() async {
        notificationsEnabled = await NotificationManager.shared.checkAuthorizationStatus()
    }
    
    private func toggleNotifications() async {
        if notificationsEnabled {
            // Disable notifications
            await NotificationManager.shared.removePendingRevisionNotifications()
            notificationsEnabled = false
        } else {
            // Request permission and enable
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                notificationsEnabled = true
                await scheduleAllNotifications()
            }
        }
    }
    
    private func scheduleAllNotifications() async {
        guard notificationsEnabled else { return }
        
        // Get all upcoming revisions
        do {
            let response = try await NetworkService.shared.getRevisions(upcoming: true, limit: 1000)
            await NotificationManager.shared.scheduleRevisionNotifications(for: response.revisions)
            
            // Also schedule daily reminder
            await NotificationManager.shared.scheduleDailyRevisionReminder()
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }
    
    private func completeRevision(_ revision: Revision) async {
        do {
            _ = try await NetworkService.shared.completeRevision(id: revision.id)
            HapticManager.shared.success()
            await loadData() // Reload all data
        } catch {
            print("Failed to complete revision: \(error.localizedDescription)")
        }
    }
}

struct RevisionGroupCard: View {
    let group: RevisionGroup
    let onComplete: (Revision) async -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header
            HStack {
                Image(systemName: dateIcon)
                    .foregroundStyle(dateColor)
                Text(formattedDate)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(group.count) revision\(group.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Revisions List
            ForEach(group.revisions) { revision in
                RevisionCard(revision: revision, onComplete: onComplete)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
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
    let onComplete: (Revision) async -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    @State private var isCompleting = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Difficulty Indicator
            Text(revision.problem.difficulty.capitalized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(difficultyColor)
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
            
            // Complete Button
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
                            .foregroundStyle(revision.isOverdue ? paletteManager.color(at: 0) : paletteManager.selectedPalette.primary)
                            .font(.title2)
                    }
                }
                .disabled(isCompleting)
            }
        }
        .padding(.vertical, 8)
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

#Preview {
    RevisionsView()
}
