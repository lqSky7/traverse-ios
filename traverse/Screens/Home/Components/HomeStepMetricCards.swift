//
//  HomeStepMetricCards.swift
//  traverse
//
//  Time and attempt analysis, rebuilt in the shape of the Apple Fitness
//  "Step Count" tile: a title with a circular chevron, a period caption, one
//  large coloured number, and a thin bar strip underneath.
//
//  Both cards default to the last seven days rather than today. A single day is
//  empty for anyone who does not solve every day, and an all-zero strip reads as
//  a broken chart rather than a rest day. Seven bars also give the strip a shape
//  to compare against, which is the whole point of putting it on the feed.
//
//  Both cards are deliberately dumb — they read a `[Solve]` array and render.
//  All of the "when did this happen" logic lives in `ActivityMetrics`, so the
//  cards and their detail screens can never disagree about which timestamp or
//  which timezone a bucket belongs to.
//

import SwiftUI
import Charts

// MARK: - Formatting

enum MetricFormat {
    static func minutes(_ value: Double) -> String {
        let total = Int(value.rounded())
        guard total > 0 else { return "0m" }
        let hours = total / 60
        let mins = total % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    /// Compact form for chart axis labels: "2h", "45m".
    static func minutesShort(_ value: Double) -> String {
        let total = Int(value.rounded())
        guard total > 0 else { return "0" }
        if total >= 60 {
            let hours = Double(total) / 60
            return hours == hours.rounded() ? "\(Int(hours))h" : String(format: "%.1fh", hours)
        }
        return "\(total)m"
    }

    static func count(_ value: Double) -> String {
        let total = Int(value.rounded())
        return total.formatted(.number.grouping(.automatic))
    }
}

// MARK: - Bar point

/// One bar in a card's strip. Positional rather than date-keyed so the axis
/// stays evenly spaced regardless of whether the buckets are hours or days.
struct MetricBarPoint: Identifiable {
    let index: Int
    let label: String
    let value: Double

    var id: Int { index }
}

private let metricWeekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEEE"
    return formatter
}()

/// Seven days of buckets, oldest first, labelled with single weekday letters.
private func weeklyBarPoints(
    solves: [Solve],
    value: @escaping (Solve) -> Double
) -> [MetricBarPoint] {
    ActivityMetrics.daily(solves: solves, days: 7, value: value)
        .enumerated()
        .map { index, bucket in
            MetricBarPoint(
                index: index,
                label: metricWeekdayFormatter.string(from: bucket.date),
                value: bucket.value
            )
        }
}

// MARK: - Time Analysis

struct TimeAnalysisCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    private static let minutesPerSolve: (Solve) -> Double = {
        Double($0.submission.timeTaken ?? 0) / 60
    }

    private var points: [MetricBarPoint] {
        weeklyBarPoints(solves: solves, value: Self.minutesPerSolve)
    }

    var body: some View {
        StepMetricCard(
            title: "Time Analysis",
            caption: "This Week",
            value: MetricFormat.minutes(points.reduce(0) { $0 + $1.value }),
            points: points,
            accent: paletteManager.color(at: 5)
        )
    }
}

// MARK: - Attempts Analysis

struct AttemptsAnalysisCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    private static let attemptsPerSolve: (Solve) -> Double = {
        Double(max($0.submission.numberOfTries ?? 1, 1))
    }

    private var points: [MetricBarPoint] {
        weeklyBarPoints(solves: solves, value: Self.attemptsPerSolve)
    }

    var body: some View {
        StepMetricCard(
            title: "Attempts Analysis",
            caption: "This Week",
            value: MetricFormat.count(points.reduce(0) { $0 + $1.value }),
            points: points,
            accent: paletteManager.color(at: 7)
        )
    }
}

// MARK: - Shared shell

struct StepMetricCard: View {
    let title: String
    let caption: String
    let value: String
    let points: [MetricBarPoint]
    let accent: Color

    private var maxValue: Double {
        max(points.map(\.value).max() ?? 0, 1)
    }

    /// A half-width card fits about seven letters, so short series get a label
    /// per bar and long ones get every fourth. This is the same rule the detail
    /// screens use for their axes.
    private var axisIndices: [Int] {
        guard points.count > 8 else { return points.map(\.index) }
        return Array(stride(from: 0, to: points.count, by: 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(caption)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Index", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(accent)
                .cornerRadius(1.5)
            }
            .chartYScale(domain: 0...maxValue)
            .chartXScale(domain: -0.5...(Double(max(points.count, 1)) - 0.5))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: axisIndices) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), points.indices.contains(index) {
                            Text(points[index].label)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    }
                }
            }
            .frame(height: 58)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .traceInvalidFrame("StepMetricCard")
    }
}

#Preview {
    HStack(spacing: 12) {
        TimeAnalysisCard(solves: [], paletteManager: ColorPaletteManager.shared)
        AttemptsAnalysisCard(solves: [], paletteManager: ColorPaletteManager.shared)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
