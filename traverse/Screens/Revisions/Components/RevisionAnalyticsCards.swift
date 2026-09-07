import SwiftUI
import Charts

struct RevisionAnalyticsSection: View {
    let analytics: RevisionAnalyticsResponse

    var body: some View {
        VStack(spacing: 16) {
            RevisionOverviewCard(overview: analytics.overview, streaks: analytics.streaks)
            RevisionStabilityDistributionCard(distribution: analytics.stabilityDistribution)
            RevisionTopicBreakdownCard(topics: analytics.topicBreakdown)
            WeeklyCompletionCard(points: analytics.weeklyCompletion)
            RevisionRetentionRiskCard(items: analytics.retentionHeatmap)
        }
    }
}

// MARK: - Analytics Info Sheet
struct AnalyticsInfoSheet: View {
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

struct RevisionOverviewCard: View {
    let overview: RevisionAnalyticsOverview
    let streaks: RevisionAnalyticsStreaks
    @StateObject private var paletteManager = ColorPaletteManager.shared

    private var retrievabilityPercent: String {
        String(format: "%.0f", overview.averageRetrievability * 100)
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
                    Text("\(streaks.totalRevisionsCompleted)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Completed")
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
    @State private var showInfo = false

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
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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
        .sheet(isPresented: $showInfo) {
            AnalyticsInfoSheet(
                title: "Retention Health",
                explanation: "Shows how many of your tracked problems fall into each memory strength tier based on FSRS stability.\n\n• Critical (< 2 days): You'd forget within 2 days without review.\n• Weak (2–7 days): Early-stage memory, needs frequent reviews.\n• Developing (7–21 days): Building up, reviews getting spaced out.\n• Strong (21–60 days): Solid retention, long review intervals.\n• Mastered (60+ days): Deeply learned, rarely needs review."
            )
        }
    }
}

// MARK: - Weekly Completion Card
struct WeeklyCompletionCard: View {
    let points: [WeeklyCompletion]
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var showInfo = false

    private struct WeekBar: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let count: Int
    }

    private var weekBars: [WeekBar] {
        let labels = ["3w ago", "2w ago", "Last wk", "This wk"]
        return points.enumerated().map { index, point in
            WeekBar(
                index: index,
                label: labels[min(index, labels.count - 1)],
                count: point.count
            )
        }
    }

    private var totalCount: Int {
        points.map { $0.count }.reduce(0, +)
    }

    private var weekDelta: Int? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].count - points[points.count - 2].count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(paletteManager.color(at: 3))
                Text("Weekly Activity")
                    .font(.headline)
                Spacer()
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalCount)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Last 4 weeks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let delta = weekDelta {
                    Divider()
                        .frame(height: 44)

                    HStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(delta >= 0 ? paletteManager.color(at: 3) : paletteManager.color(at: 0))
                        Text("\(delta >= 0 ? "+" : "")\(delta) this week")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(delta >= 0 ? paletteManager.color(at: 3) : paletteManager.color(at: 0))
                    }
                }
            }

            if weekBars.isEmpty {
                Text("No completions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(weekBars) { bar in
                    BarMark(
                        x: .value("Week", bar.label),
                        y: .value("Count", bar.count)
                    )
                    .foregroundStyle(paletteManager.color(at: 3).opacity(bar.index == weekBars.count - 1 ? 1.0 : 0.5))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if bar.count > 0 {
                            Text("\(bar.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks { value in
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
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showInfo) {
            AnalyticsInfoSheet(
                title: "Weekly Activity",
                explanation: "Shows how many revisions you completed each week over the last 4 weeks.\n\nConsistent weekly activity strengthens long-term retention. The arrow shows whether your activity this week is trending up or down compared to last week."
            )
        }
    }
}

// MARK: - Topic Mastery Card (Top 4 + Full Sheet)
struct RevisionTopicBreakdownCard: View {
    let topics: [RevisionTopicMetric]
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var showAllTopics = false
    @State private var showInfo = false

    private var displayTopics: [RevisionTopicMetric] {
        Array(topics.prefix(4))
    }

    private func retentionColor(for retention: Double) -> Color {
        if retention >= 0.80 {
            return paletteManager.color(at: 3)
        } else if retention >= 0.60 {
            return paletteManager.color(at: 1)
        } else {
            return paletteManager.color(at: 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(paletteManager.color(at: 2))
                Text("Topic Mastery & Speed")
                    .font(.headline)
                Spacer()
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            if topics.isEmpty {
                Text("No topic data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 14) {
                    ForEach(displayTopics) { topic in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(topic.displayTopic)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text("• \(topic.problemCount) \(topic.problemCount == 1 ? "problem" : "problems")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                if topic.averageTimeMinutes > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text(String(format: "%.1fm", topic.averageTimeMinutes))
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(4)
                                }

                                Text(String(format: "%.0f%%", topic.averageRetention * 100))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(retentionColor(for: topic.averageRetention))
                                    .frame(width: 38, alignment: .trailing)
                            }

                            // Horizontal Retention Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(retentionColor(for: topic.averageRetention))
                                        .frame(width: max(geo.size.width * CGFloat(min(max(topic.averageRetention, 0), 1.0)), 4), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }

                if topics.count > 4 {
                    Button {
                        showAllTopics = true
                    } label: {
                        HStack {
                            Text("View All Topics (\(topics.count))")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(paletteManager.color(at: 2))
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showAllTopics) {
            AllTopicsSheet(topics: topics)
        }
        .sheet(isPresented: $showInfo) {
            AnalyticsInfoSheet(
                title: "Topic Mastery & Speed",
                explanation: "Breaks down your memory retention and recall speed across DSA categories.\n\n• Retention Bar: Probability you recall problems in this topic right now.\n• Clock Badge: Average time you spend solving problems in this topic.\n\nHelps identify which algorithms need practice and where your solve velocity is fastest."
            )
        }
    }
}

// MARK: - All Topics Detail Sheet

struct RevisionRetentionRiskCard: View {
    let items: [RevisionRetentionItem]
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var showAllAtRisk = false
    @State private var showInfo = false

    private struct RiskItem: Identifiable {
        let id = UUID()
        let problemId: Int
        let title: String
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

        return Array(sorted.prefix(5)).map { item in
            RiskItem(
                problemId: item.problemId,
                title: item.problemTitle,
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

    private func riskColor(for item: RiskItem) -> Color {
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
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
                VStack(spacing: 10) {
                    ForEach(focusItems) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(riskColor(for: item))
                                .frame(width: 8, height: 8)

                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            // Inline mini progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(riskColor(for: item))
                                        .frame(width: max(geo.size.width * CGFloat(min(max(item.retrievability, 0), 1.0)), 2), height: 4)
                                }
                            }
                            .frame(width: 50, height: 4)

                            Text(String(format: "%.0f%%", item.retrievability * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }

                if items.count > 5 {
                    Button {
                        showAllAtRisk = true
                    } label: {
                        HStack {
                            Text("View All At-Risk Problems (\(items.count))")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(paletteManager.color(at: 0))
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showAllAtRisk) {
            AllAtRiskProblemsSheet(items: items)
        }
        .sheet(isPresented: $showInfo) {
            AnalyticsInfoSheet(
                title: "At-Risk Problems",
                explanation: "Problems with the weakest memory retention right now — these are most likely to be forgotten if not reviewed soon.\n\n• Leeches: Problems you've forgotten 8+ times. These need a different approach — try re-solving from scratch.\n• Below 60%: Problems where your recall probability has dropped significantly.\n\nThe percentage shows how likely you are to remember the solution right now."
            )
        }
    }
}

// MARK: - All At-Risk Problems Detail Sheet
