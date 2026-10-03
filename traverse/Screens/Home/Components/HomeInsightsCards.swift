import SwiftUI
import Charts

/// The Awards card on the home feed.
///
/// Apple leads with the badge you earned most recently rather than a raw count, so the
/// card shows the newest award's medal and name. The whole card is a navigation target
/// into the Awards shelf.
struct AchievementStatsCard: View {
    let stats: AchievementStatsData
    @ObservedObject var paletteManager: ColorPaletteManager

    private var latest: AchievementDetail? { stats.latestAward }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Awards")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }

            Spacer(minLength: 6)

            if let latest {
                MedalView(
                    medal: latest.medalAsset,
                    unlocked: latest.unlocked,
                    interactive: false
                )
                .frame(height: 92)

                Spacer(minLength: 6)

                Text(latest.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            } else {
                // Nothing earned yet — keep the card's silhouette rather than collapsing it.
                MedalView(
                    medal: MedalCatalog.fallback(for: "first_solve"),
                    unlocked: false,
                    interactive: false,
                    showsShadow: false
                )
                .frame(height: 92)

                Spacer(minLength: 6)

                Text("Solve a problem to earn your first award")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .traceInvalidFrame("AchievementStatsCard")
    }
}

// MARK: - Productivity Insights Card (Weekly Activity)
struct ProductivityInsightsCard: View {
    let solves: [Solve]
    let completedRevisions: [Revision]
    @ObservedObject var paletteManager: ColorPaletteManager

    private struct DayData: Identifiable {
        var id: Date { date }
        let date: Date
        let label: String
        let solves: Int
        let revisions: Int
    }

    private var last7DaysData: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Count solves by day. `activityAt`, not `solvedAt`: the backend freezes
        // the solve date at first acceptance and only moves the activity stamp
        // afterwards, so bucketing on `solvedAt` made a week of re-solving look
        // like a week off.
        var solveCounts: [Date: Int] = [:]
        for solve in solves {
            guard let solveDate = ActivityTimestamp.date(from: solve.activityAt) else { continue }
            solveCounts[calendar.startOfDay(for: solveDate), default: 0] += 1
        }

        // Count completed revisions by day
        var revisionCounts: [Date: Int] = [:]
        for revision in completedRevisions {
            guard let completedDate = ActivityTimestamp.date(from: revision.completedAt) else { continue }
            revisionCounts[calendar.startOfDay(for: completedDate), default: 0] += 1
        }

        // Build last 7 days array
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEEE"  // Single letter day (M, T, W, etc.)

        var data: [DayData] = []
        for dayOffset in (0..<7).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let label = dayFormatter.string(from: dayDate)
            data.append(DayData(
                date: dayDate,
                label: label,
                solves: solveCounts[dayDate] ?? 0,
                revisions: revisionCounts[dayDate] ?? 0
            ))
        }
        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Weekly Activity")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Chart
            Chart {
                ForEach(last7DaysData) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Count", day.solves)
                    )
                    .foregroundStyle(paletteManager.color(at: 0))
                    .position(by: .value("Type", "Solves"))

                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Count", day.revisions)
                    )
                    .foregroundStyle(paletteManager.color(at: 1))
                    .position(by: .value("Type", "Revisions"))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .frame(height: 100)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(paletteManager.color(at: 0))
                        .frame(width: 8, height: 8)
                    Text("Solves")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(paletteManager.color(at: 1))
                        .frame(width: 8, height: 8)
                    Text("Revisions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .traceInvalidFrame("ProductivityInsightsCard")
    }
}
