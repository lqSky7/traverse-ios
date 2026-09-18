//
//  HomeHoursCard.swift
//  traverse
//
//  "Solving Hours" — a 24-bar histogram of when you actually sit down to work.
//
//  Rewritten because the card was reporting the wrong hours. Three separate
//  causes, all fixed here:
//
//  1. It bucketed on `solvedAt`. The backend stamps that once, when a problem is
//     first accepted, and never moves it — re-solving or revising only bumps
//     `lastActivityAt`. For an account that mostly revises, the histogram was
//     therefore describing the day each problem was first met, which can be
//     months away from when the work actually happened. It now buckets on
//     `activityAt` (see `ActivityMetrics`).
//
//  2. It parsed timestamps with `.withFractionalSeconds` only, so any row whose
//     timestamp arrived without milliseconds was dropped without an error.
//
//  3. With no activity at all, `max(by:)` returned hour 0 and the card happily
//     announced "12am" as your peak hour. Empty is now empty.
//

import SwiftUI
import Charts

struct BestSolvingHoursCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    /// One solve in an hour is not evidence of anything. The "fastest hour"
    /// claim needs a minimum sample before it is allowed on screen.
    private static let minimumSamplesForFastestHour = 3

    private struct HourBucket {
        let hour: Int
        let count: Int
        let totalSeconds: Int

        var averageSeconds: Double {
            count > 0 ? Double(totalSeconds) / Double(count) : 0
        }
    }

    private var buckets: [HourBucket] {
        var counts = [Int](repeating: 0, count: 24)
        var totals = [Int](repeating: 0, count: 24)

        for solve in solves {
            guard let date = ActivityTimestamp.date(from: solve.activityAt) else { continue }
            let hour = Calendar.current.component(.hour, from: date)
            guard hour >= 0, hour < 24 else { continue }

            counts[hour] += 1
            if let time = solve.submission.timeTaken, time > 0 {
                totals[hour] += time
            }
        }

        return (0..<24).map { HourBucket(hour: $0, count: counts[$0], totalSeconds: totals[$0]) }
    }

    /// Earliest hour with the most solves, or `nil` when nothing is recorded.
    private var peakHour: HourBucket? {
        buckets.filter { $0.count > 0 }.max { $0.count < $1.count }
    }

    private var fastestHour: HourBucket? {
        buckets
            .filter { $0.count >= Self.minimumSamplesForFastestHour && $0.averageSeconds > 0 }
            .min { $0.averageSeconds < $1.averageSeconds }
    }

    private var maxCount: Int {
        max(buckets.map(\.count).max() ?? 0, 1)
    }

    private var hasData: Bool { peakHour != nil }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12am" }
        if hour < 12 { return "\(hour)am" }
        if hour == 12 { return "12pm" }
        return "\(hour - 12)pm"
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes > 0 { return "\(minutes)m" }
        return "\(Int(seconds))s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(paletteManager.color(at: 6))
                Text("Solving Hours")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            if hasData {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatHour(peakHour?.hour ?? 0))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 6))
                        Text("Peak Hour")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let fastest = fastestHour {
                        Divider()
                            .frame(height: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatHour(fastest.hour))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(paletteManager.color(at: 0))
                            Text("Fastest (\(formatTime(fastest.averageSeconds)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Chart(buckets, id: \.hour) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(
                        bucket.hour == peakHour?.hour
                            ? paletteManager.color(at: 6).gradient
                            : paletteManager.color(at: 6).opacity(0.4).gradient
                    )
                    .cornerRadius(2)
                }
                .chartYScale(domain: 0...maxCount)
                .frame(height: 80)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(formatHour(hour))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
            } else {
                EmptyStateView(
                    icon: "clock.badge.questionmark",
                    title: "No solving activity recorded yet",
                    message: "Once Traverse has seen you work, your peak and fastest hours show up here.",
                    compact: true
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .traceInvalidFrame("BestSolvingHoursCard")
    }
}
