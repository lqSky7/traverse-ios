//
//  MetricDetailView.swift
//  traverse
//
//  The pushed screen behind both Step-Count style cards, laid out like Apple
//  Fitness' metric detail: large title, D/W/M/Y range picker, a headline total
//  over a bar chart with real grid lines and axis labels, then a button that
//  expands the all-time numbers.
//
//  Attempts additionally carries the "By Difficulty" breakdown that used to be
//  its own card on the home feed.
//

import SwiftUI
import Charts

// MARK: - Range

enum MetricRange: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case year = "Y"

    var id: String { rawValue }

    var periodLabel: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}

// MARK: - Kind

enum MetricKind {
    case time
    case attempts

    var navigationTitle: String {
        switch self {
        case .time: return "Time Analysis"
        case .attempts: return "Attempts Analysis"
        }
    }

    var metricsButtonTitle: String {
        switch self {
        case .time: return "View All Time Metrics"
        case .attempts: return "View All Attempt Metrics"
        }
    }

    /// The per-solve sample being bucketed.
    var value: (Solve) -> Double {
        switch self {
        case .time:
            return { Double($0.submission.timeTaken ?? 0) / 60 }
        case .attempts:
            return { Double(max($0.submission.numberOfTries ?? 1, 1)) }
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .time: return MetricFormat.minutes(value)
        case .attempts: return MetricFormat.count(value)
        }
    }

    func formatAxis(_ value: Double) -> String {
        switch self {
        case .time: return MetricFormat.minutesShort(value)
        case .attempts: return MetricFormat.count(value)
        }
    }

    /// Headline for an empty range. A bar chart with nothing in it looks like a
    /// rendering failure, so the chart is replaced outright when the range has
    /// no data rather than drawn flat.
    var emptyTitle: String {
        switch self {
        case .time: return "No time recorded"
        case .attempts: return "No attempts recorded"
        }
    }
}

// MARK: - Detail view

struct MetricDetailView: View {
    let kind: MetricKind
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    /// Weekly by default — a single day is mostly empty for anyone who is not
    /// solving every day, and an empty chart reads as a broken chart.
    @State private var range: MetricRange = .week
    @State private var showAllMetrics = false

    private var accent: Color {
        switch kind {
        case .time: return paletteManager.color(at: 5)
        case .attempts: return paletteManager.color(at: 7)
        }
    }

    private var calendar: Calendar { Calendar.current }

    private static let narrowWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private struct ChartPoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    // MARK: Data

    private var chartPoints: [ChartPoint] {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: Date())
            return ActivityMetrics.hourly(solves: solves, value: kind.value).compactMap { bucket in
                guard let date = calendar.date(byAdding: .hour, value: bucket.hour, to: start) else { return nil }
                return ChartPoint(date: date, value: bucket.value)
            }
        case .week:
            return ActivityMetrics.daily(solves: solves, days: 7, value: kind.value)
                .map { ChartPoint(date: $0.date, value: $0.value) }
        case .month:
            return ActivityMetrics.daily(solves: solves, days: 30, value: kind.value)
                .map { ChartPoint(date: $0.date, value: $0.value) }
        case .year:
            return ActivityMetrics.monthly(solves: solves, months: 12, value: kind.value)
                .map { ChartPoint(date: $0.date, value: $0.value) }
        }
    }

    private var rangeTotal: Double {
        chartPoints.reduce(0) { $0 + $1.value }
    }

    /// Months read better as an average than as a sum — the same choice Apple
    /// makes on the M tab.
    private var headlineCaption: String {
        range == .month ? "Daily Average" : "Total"
    }

    private var headlineValue: String {
        switch range {
        case .month:
            // Divide by the days *elapsed* in the month, not by 30. On the 8th
            // of the month a 30-day divisor reported an average 3.75x lower
            // than the truth, which reads as "you are slacking" on a month
            // that has barely started.
            let elapsed = calendar.component(.day, from: Date())
            return kind.format(rangeTotal / Double(max(elapsed, 1)))
        default:
            return kind.format(rangeTotal)
        }
    }

    private var headlineSubtitle: String {
        let now = Date()
        switch range {
        case .day, .week:
            return range.periodLabel
        case .month:
            return Self.monthYearFormatter.string(from: now).uppercased()
        case .year:
            return Self.yearFormatter.string(from: now)
        }
    }

    /// Explicit axis positions so the grid lines land where a reader expects
    /// them (00/06/12/18, every seventh day, one per month) instead of wherever
    /// the automatic stride happens to fall.
    private var axisDates: [Date] {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: Date())
            return [0, 6, 12, 18].compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
        case .week, .year:
            return chartPoints.map(\.date)
        case .month:
            return stride(from: 0, to: chartPoints.count, by: 7).compactMap { index in
                chartPoints.indices.contains(index) ? chartPoints[index].date : nil
            }
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .day:
            return String(format: "%02d", calendar.component(.hour, from: date))
        case .week:
            return Self.narrowWeekdayFormatter.string(from: date)
        case .month:
            return "\(calendar.component(.day, from: date))"
        case .year:
            return Self.monthFormatter.string(from: date)
        }
    }

    private var yUpperBound: Double {
        max((chartPoints.map(\.value).max() ?? 0) * 1.15, 1)
    }

    /// An explicit domain with half a bar of padding on each end. Without the
    /// padding `BarMark`s on the first and last date get sliced in half, and
    /// without the explicit domain the axis re-derives itself on every range
    /// change, which is what made the grid lines appear to jump.
    private var xDomain: ClosedRange<Date> {
        guard let first = chartPoints.first?.date,
              let last = chartPoints.last?.date,
              first < last else {
            let now = Date()
            return now.addingTimeInterval(-1800)...now
        }
        let step = last.timeIntervalSince(first) / Double(max(chartPoints.count - 1, 1))
        return first.addingTimeInterval(-step / 2)...last.addingTimeInterval(step / 2)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker
                headline
                if rangeTotal == 0 {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: kind.emptyTitle,
                        message: "Nothing in \(range.periodLabel.lowercased()). Try a wider range, or solve a problem with the browser extension installed.",
                        compact: true
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    rangeChart
                }

                metricsButton

                if showAllMetrics {
                    allTimeMetrics
                }

                if kind == .attempts {
                    difficultyBreakdown
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.black)
        .navigationTitle(kind.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
        .animation(.smooth(duration: 0.3), value: showAllMetrics)
    }

    // MARK: Chart

    /// The chart is identity-scoped to the range and swapped with a horizontal
    /// push. Morphing in place is not possible here — D is 24 hours, W is 7
    /// days, M is 30 days, Y is 12 months, so no two ranges share a mark. The
    /// alternative (letting SwiftUI re-lay-out one chart) is what produced the
    /// scale-up/scale-down re-render; a push reads as moving along a timeline
    /// instead. The fixed frame plus `clipped()` keeps the swap from spilling
    /// into the rows above and below it.
    private var rangeChart: some View {
        ZStack {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value(kind.navigationTitle, point.value)
                )
                .foregroundStyle(accent)
                .cornerRadius(2)
            }
            .chartYScale(domain: 0...yUpperBound)
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: axisDates) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.14))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.white.opacity(0.14))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(kind.formatAxis(number))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 220)
            .id(range)
            .transition(.push(from: .trailing))
        }
        .frame(height: 220)
        .clipped()
        .animation(.smooth(duration: 0.4), value: range)
    }

    // MARK: Pieces

    /// The platform's own segmented picker. On iOS 26 this *is* Liquid Glass —
    /// the container, the sliding selection pill and the interactive response
    /// all come from the system, so there is nothing to hand-roll and nothing
    /// to keep in sync with the OS. A hand-built capsule stack would only ever
    /// be an approximation of it.
    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(MetricRange.allCases) { candidate in
                Text(candidate.rawValue).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Chart range")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(headlineCaption)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(headlineValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(headlineSubtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsButton: some View {
        Button {
            HapticManager.shared.selection()
            showAllMetrics.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(showAllMetrics ? "Hide Metrics" : kind.metricsButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                Image(systemName: showAllMetrics ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    private var allTimeMetrics: some View {
        VStack(spacing: 0) {
            ForEach(Array(allTimeRows.enumerated()), id: \.element.label) { index, row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(row.value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .padding(.vertical, 12)

                if index < allTimeRows.count - 1 {
                    Divider().overlay(Color.white.opacity(0.10))
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // `blurReplace` fades and un-blurs the block where it already sits.
        // The previous `.move(edge: .top)` slid it in from above its own frame,
        // which put it on top of the chart on the way in.
        .transition(.blurReplace)
    }

    private var allTimeRows: [(label: String, value: String)] {
        let summary = ActivityMetrics.summary(solves: solves, value: kind.value)

        switch kind {
        case .time:
            return [
                ("Total Time", MetricFormat.minutes(summary.total)),
                ("Average per Problem", MetricFormat.minutes(summary.average)),
                ("Longest Single Solve", MetricFormat.minutes(summary.maximum)),
                ("Problems Timed", "\(summary.sampleCount)")
            ]
        case .attempts:
            return [
                ("Total Attempts", MetricFormat.count(summary.total)),
                ("Average per Problem", String(format: "%.1f", summary.average)),
                ("Most Attempts", MetricFormat.count(summary.maximum)),
                ("Problems Solved", "\(summary.sampleCount)")
            ]
        }
    }

    // MARK: Difficulty (moved off the home feed)

    private var difficultyBreakdown: some View {
        let metrics = ActivityMetrics.byDifficulty(solves: solves)
        let maxSolves = max(metrics.map(\.solves).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("By Difficulty")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No attempts recorded yet",
                    message: "Once Traverse has a few attempts to read, they are broken down by difficulty here.",
                    compact: true
                )
            } else {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        DifficultyProgressRow(
                            label: DifficultyWeight.displayName(for: metric.difficulty),
                            count: metric.solves,
                            maxCount: maxSolves,
                            color: difficultyColor(metric.difficulty)
                        )

                        Text(String(format: "%.1f attempts per problem", metric.averageAttempts))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.leading, 62)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        MetricDetailView(kind: .time, solves: [], paletteManager: ColorPaletteManager.shared)
    }
    .preferredColorScheme(.dark)
}
