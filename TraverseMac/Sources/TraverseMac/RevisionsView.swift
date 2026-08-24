import SwiftUI
import Charts

struct RevisionsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                stats
                mlSummary
                revisionList
            }
            .padding(24)
        }
        .navigationTitle("ML Revisions")
        .task { await appState.refreshRevisions() }
    }

    private var header: some View {
        ThemedCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ML Revision Queue")
                        .font(.largeTitle.weight(.bold))
                    Text("Paid accounts use the ML schedule only. Swipe a row left to delete it.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
            MetricCard(title: "Total", value: appState.revisionStats?.total ?? 0, symbol: "tray.full", color: paletteManager.color(at: 0))
            MetricCard(title: "Due Today", value: appState.revisionStats?.dueToday ?? 0, symbol: "calendar.badge.clock", color: paletteManager.color(at: 1))
            MetricCard(title: "Overdue", value: appState.revisionStats?.overdue ?? 0, symbol: "exclamationmark.triangle", color: .orange)
            MetricCard(title: "Completed", value: appState.revisionStats?.completed ?? 0, symbol: "checkmark.circle", color: paletteManager.color(at: 2))
        }
    }

    private var mlSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let today = appState.todayRevisions {
                ThemedCard {
                    HStack {
                        Label("\(today.total) due today", systemImage: "brain")
                        Spacer()
                        Text("Daily cap \(today.maxDaily)")
                            .foregroundStyle(.secondary)
                        if today.overflow > 0 {
                            Text("\(today.overflow) overflow")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.headline)
                }
            }
            if let analytics = appState.revisionAnalytics {
                HStack(alignment: .top, spacing: 14) {
                    WeeklyCompletionChart(points: analytics.weeklyCompletion)
                    TopicBreakdownChart(points: analytics.topicBreakdown)
                }
                RetentionRiskTable(items: analytics.retentionHeatmap)
            }
        }
    }

    private var revisionList: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scheduled Reviews")
                    .font(.title3.weight(.bold))
                if appState.revisionGroups.isEmpty {
                    PanelFeedback(status: appState.panelStatus(.revisions), isEmpty: true, emptyTitle: "No ML revisions due", emptySystemImage: "clock.badge.checkmark", emptyDescription: "Your ML schedule will appear here.")
                } else {
                    ForEach(appState.revisionGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.displayDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                            ForEach(group.revisions) { revision in
                                NavigationLink {
                                    RevisionDetailView(revision: revision)
                                } label: {
                                    RevisionRow(revision: revision)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await appState.deleteRevision(revision) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button("Delete Revision", role: .destructive) {
                                        Task { await appState.deleteRevision(revision) }
                                    }
                                }
                                if revision.id != group.revisions.last?.id { Divider() }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

struct RevisionRow: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let revision: Revision

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(revision.problem.title)
                        .font(.headline)
                    Text("#\(revision.revisionNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("\(revision.problem.platform) • \(revision.problem.difficulty.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if revision.isOverdue {
                Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption.weight(.semibold))
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct WeeklyCompletionChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let points: [WeeklyCompletion]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Weekly Activity").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: points.isEmpty, emptyTitle: "No weekly activity", emptySystemImage: "chart.bar.fill", emptyDescription: "Weekly review activity will appear here.")
                Chart(points) { point in
                    BarMark(x: .value("Week", point.week), y: .value("Completions", point.count))
                        .foregroundStyle(paletteManager.color(at: 3))
                }
                .frame(height: 190)
            }
        }
    }
}

struct TopicBreakdownChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let points: [RevisionTopicMetric]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Topic Mastery").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: points.isEmpty, emptyTitle: "No topic data", emptySystemImage: "chart.bar.xaxis", emptyDescription: "Topic retention breakdown will appear here.")
                Chart(points.prefix(6)) { point in
                    BarMark(
                        x: .value("Retention", point.averageRetention * 100),
                        y: .value("Topic", point.topic)
                    )
                    .foregroundStyle(paletteManager.color(at: 2))
                }
                .frame(height: 190)
            }
        }
    }
}

struct RetentionRiskTable: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let items: [RevisionRetentionItem]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Retention Risk").font(.headline)
                if items.isEmpty {
                    PanelFeedback(status: .loaded(.now), isEmpty: true, emptyTitle: "No retention risk", emptySystemImage: "brain", emptyDescription: "Risk scores will appear when ML analytics are available.")
                } else {
                    ForEach(items.sorted { $0.retrievability < $1.retrievability }.prefix(8)) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.problemTitle).font(.subheadline.weight(.semibold))
                                Text("\(item.platform) • \(item.difficulty.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(item.retrievability * 100))%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(item.isLeech ? .orange : paletteManager.selectedPalette.primary)
                        }
                        if item.id != items.prefix(8).last?.id { Divider() }
                    }
                }
            }
        }
    }
}
