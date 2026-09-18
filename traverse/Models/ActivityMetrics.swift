//
//  ActivityMetrics.swift
//  traverse
//
//  Shared plumbing for every "how much / when" chart in the app.
//
//  Three problems kept showing up across the home feed and are solved once,
//  here, instead of in each card:
//
//  1. Timestamp parsing. The API emits ISO-8601 with fractional seconds for
//     most fields but not all of them. Cards that hard-coded
//     `.withFractionalSeconds` silently dropped every row that arrived without
//     milliseconds — no error, the row just vanished from the chart, which is
//     how a histogram ends up reporting the wrong peak hour.
//
//  2. Which timestamp to trust. `solvedAt` is stamped once, when a problem is
//     first accepted, and the backend never moves it: re-solving or revising a
//     problem only bumps `lastActivityAt`. Anything that claims to describe
//     *when you work* has to read `activityAt`, or a revision-heavy account
//     looks like it only ever solved problems on the day it first met them.
//
//  3. Bucketing. Every card needs the same "group these rows by local calendar
//     day / hour" loop, and doing it inline is where timezone and
//     start-of-day mistakes creep in.
//

import Foundation
import SwiftUI

// MARK: - Timestamp parsing

enum ActivityTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Parses either flavour of ISO-8601 the backend produces. Returns `nil`
    /// only for genuinely unparseable input.
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = fractional.date(from: string) { return date }
        return plain.date(from: string)
    }

    /// Local calendar day, used as the bucket key everywhere.
    static func day(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// `yyyy-MM-dd` in the *local* calendar — matches the freeze-date keys the
    /// backend hands back.
    static func key(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }
}

// MARK: - Solve activity time

extension Solve {
    /// When the user last touched this problem: the newest accepted submission
    /// if the backend reported one, otherwise the original solve.
    var activityAt: String { lastActivityAt ?? solvedAt }

    var activityDate: Date? { ActivityTimestamp.date(from: activityAt) }

    var solvedDate: Date? { ActivityTimestamp.date(from: solvedAt) }
}

// MARK: - Difficulty weighting

enum DifficultyWeight {
    /// Relative cost of a problem, used so a hard revision counts as more
    /// training load than an easy one.
    static func weight(for difficulty: String) -> Double {
        switch difficulty.lowercased() {
        case "easy": return 1
        case "medium": return 2
        case "hard": return 3
        default: return 1
        }
    }

    /// Canonical ordering, easiest first.
    static let order = ["easy", "medium", "hard"]

    static func rank(for difficulty: String) -> Int {
        order.firstIndex(of: difficulty.lowercased()) ?? order.count
    }

    static func displayName(for difficulty: String) -> String {
        switch difficulty.lowercased() {
        case "easy": return "Easy"
        case "medium": return "Medium"
        case "hard": return "Hard"
        default: return difficulty.capitalized
        }
    }
}

// MARK: - Bucket value types

struct DayValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct HourValue: Identifiable {
    let hour: Int
    let value: Double
    var id: Int { hour }
}

struct MetricSummary {
    let total: Double
    let average: Double
    let maximum: Double
    let sampleCount: Int

    static let empty = MetricSummary(total: 0, average: 0, maximum: 0, sampleCount: 0)
}

struct DifficultyMetric: Identifiable {
    let difficulty: String
    let solves: Int
    let attempts: Int

    var id: String { difficulty }
    var averageAttempts: Double {
        solves > 0 ? Double(attempts) / Double(solves) : 0
    }
}

// MARK: - Bucketing

enum ActivityMetrics {

    // MARK: Revision load

    /// Preferred baseline window.
    static let loadBaselineDays = 28
    /// Fallback baseline window for accounts that do not have a month of history
    /// yet. Two weeks is still long enough for a 7-day average to mean something.
    static let loadFallbackBaselineDays = 15
    static let loadRecentDays = 7

    /// Apple Fitness' "Training Load" idea, translated to problem practice.
    ///
    /// Load for a day is the difficulty-weighted amount of work done that day:
    /// every completed revision plus every problem worked on. The 7-day daily
    /// average is compared against a longer baseline average, so a week of heavy
    /// practice against a light month reads as "Above".
    ///
    /// The baseline is 28 days when there is 28 days of history to compare
    /// against, and 15 days when there is not — a brand-new account used to get
    /// "No Data" for its first month, which is exactly when a load reading is
    /// most useful. Below 15 days of history the comparison genuinely is not
    /// meaningful, so the card says so instead of inventing a verdict.
    static func revisionLoad(
        revisions: [Revision],
        solves: [Solve],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RevisionLoadSnapshot {
        let today = calendar.startOfDay(for: now)

        // Flatten both sources into (day, weight) contributions once.
        var contributions: [(day: Date, weight: Double)] = []

        for revision in revisions {
            guard let completed = ActivityTimestamp.date(from: revision.completedAt) else { continue }
            contributions.append((
                calendar.startOfDay(for: completed),
                DifficultyWeight.weight(for: revision.problem.difficulty)
            ))
        }

        for solve in solves {
            guard let date = solve.activityDate else { continue }
            contributions.append((
                calendar.startOfDay(for: date),
                DifficultyWeight.weight(for: solve.problem.difficulty)
            ))
        }

        let historyDays: Int
        if let earliest = contributions.map(\.day).min() {
            historyDays = calendar.dateComponents([.day], from: earliest, to: today).day ?? 0
        } else {
            historyDays = 0
        }

        let baselineDays: Int
        if historyDays >= loadBaselineDays {
            baselineDays = loadBaselineDays
        } else if historyDays >= loadFallbackBaselineDays {
            baselineDays = loadFallbackBaselineDays
        } else {
            baselineDays = 0
        }

        // Always draw a window, even when there is not enough history to grade
        // it. A chart with no verdict beats a chart with no bars.
        let windowDays = baselineDays > 0 ? baselineDays : loadFallbackBaselineDays
        var buckets: [Date: Double] = [:]
        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            buckets[day] = 0
        }

        for contribution in contributions {
            guard buckets[contribution.day] != nil else { continue }
            buckets[contribution.day, default: 0] += contribution.weight
        }

        let series = buckets.keys.sorted().map { day in
            DailyLoadPoint(day: day, value: buckets[day] ?? 0)
        }

        let windowTotal = series.reduce(0) { $0 + $1.value }
        let recentTotal = series.suffix(loadRecentDays).reduce(0) { $0 + $1.value }
        let recentAverage = recentTotal / Double(loadRecentDays)

        guard baselineDays > 0, windowTotal > 0 else {
            return RevisionLoadSnapshot(
                band: .noData,
                percentChange: nil,
                recentDailyAverage: recentAverage,
                baselineDailyAverage: 0,
                series: series,
                windowTotal: windowTotal,
                baselineDays: nil
            )
        }

        let baselineAverage = windowTotal / Double(baselineDays)
        guard baselineAverage > 0 else {
            return RevisionLoadSnapshot(
                band: .noData,
                percentChange: nil,
                recentDailyAverage: recentAverage,
                baselineDailyAverage: 0,
                series: series,
                windowTotal: windowTotal,
                baselineDays: nil
            )
        }

        let ratio = recentAverage / baselineAverage
        let percent = Int(((ratio - 1) * 100).rounded())

        return RevisionLoadSnapshot(
            band: RevisionLoadBand.from(ratio: ratio),
            percentChange: percent,
            recentDailyAverage: recentAverage,
            baselineDailyAverage: baselineAverage,
            series: series,
            windowTotal: windowTotal,
            baselineDays: baselineDays
        )
    }

    // MARK: Hourly

    /// 24 buckets for the given local day, oldest hour first.
    static func hourly(
        solves: [Solve],
        on day: Date = Date(),
        value: (Solve) -> Double,
        calendar: Calendar = .current
    ) -> [HourValue] {
        let target = calendar.startOfDay(for: day)
        var buckets = [Double](repeating: 0, count: 24)

        for solve in solves {
            guard let date = solve.activityDate else { continue }
            guard calendar.startOfDay(for: date) == target else { continue }
            let hour = calendar.component(.hour, from: date)
            guard hour >= 0, hour < 24 else { continue }
            buckets[hour] += value(solve)
        }

        return (0..<24).map { HourValue(hour: $0, value: buckets[$0]) }
    }

    // MARK: Daily / monthly

    /// One bucket per local day, oldest first, covering `days` days ending today.
    /// Days with no activity are present with a value of `0` so charts keep an
    /// even x-axis instead of collapsing gaps.
    static func daily(
        solves: [Solve],
        days: Int,
        now: Date = Date(),
        value: (Solve) -> Double,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let today = calendar.startOfDay(for: now)
        var buckets: [Date: Double] = [:]
        for offset in 0..<max(days, 1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            buckets[day] = 0
        }

        for solve in solves {
            guard let date = solve.activityDate else { continue }
            let day = calendar.startOfDay(for: date)
            guard buckets[day] != nil else { continue }
            buckets[day, default: 0] += value(solve)
        }

        return buckets.keys.sorted().map { DayValue(date: $0, value: buckets[$0] ?? 0) }
    }

    /// One bucket per calendar month, oldest first, ending with the current month.
    static func monthly(
        solves: [Solve],
        months: Int,
        now: Date = Date(),
        value: (Solve) -> Double,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let componentSet: Set<Calendar.Component> = [.year, .month]
        let currentComponents = calendar.dateComponents(componentSet, from: now)
        guard let currentMonthStart = calendar.date(from: currentComponents) else { return [] }

        var buckets: [Date: Double] = [:]
        for offset in 0..<max(months, 1) {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else { continue }
            buckets[month] = 0
        }

        for solve in solves {
            guard let date = solve.activityDate else { continue }
            let components = calendar.dateComponents(componentSet, from: date)
            guard let monthStart = calendar.date(from: components) else { continue }
            guard buckets[monthStart] != nil else { continue }
            buckets[monthStart, default: 0] += value(solve)
        }

        return buckets.keys.sorted().map { DayValue(date: $0, value: buckets[$0] ?? 0) }
    }

    // MARK: Summaries

    static func summary(
        solves: [Solve],
        value: (Solve) -> Double?
    ) -> MetricSummary {
        var total: Double = 0
        var maximum: Double = 0
        var count = 0

        for solve in solves {
            guard let sample = value(solve) else { continue }
            total += sample
            maximum = max(maximum, sample)
            count += 1
        }

        return MetricSummary(
            total: total,
            average: count > 0 ? total / Double(count) : 0,
            maximum: maximum,
            sampleCount: count
        )
    }

    /// Per-difficulty solve counts and attempt totals, easiest first.
    static func byDifficulty(solves: [Solve]) -> [DifficultyMetric] {
        var solvesByDifficulty: [String: Int] = [:]
        var attemptsByDifficulty: [String: Int] = [:]

        for solve in solves {
            let key = solve.problem.difficulty.lowercased()
            solvesByDifficulty[key, default: 0] += 1
            attemptsByDifficulty[key, default: 0] += max(solve.submission.numberOfTries ?? 1, 1)
        }

        return DifficultyWeight.order.compactMap { key in
            guard let solveCount = solvesByDifficulty[key], solveCount > 0 else { return nil }
            return DifficultyMetric(
                difficulty: key,
                solves: solveCount,
                attempts: attemptsByDifficulty[key] ?? solveCount
            )
        }
    }
}

// MARK: - Revision load model

struct DailyLoadPoint: Identifiable {
    let day: Date
    let value: Double
    var id: Date { day }
}

enum RevisionLoadBand: String {
    case wellBelow = "Well Below"
    case below = "Below"
    case optimal = "Optimal"
    case above = "Above"
    case wellAbove = "Well Above"
    case noData = "No Data"

    /// Bands are the same shape Apple uses for training load: a 20% swing either
    /// way is normal week-to-week noise, beyond that it is worth naming.
    static func from(ratio: Double) -> RevisionLoadBand {
        if ratio < 0.8 { return .wellBelow }
        if ratio < 1.0 { return .below }
        if ratio <= 1.3 { return .optimal }
        if ratio <= 1.5 { return .above }
        return .wellAbove
    }

    /// Slot in the user's palette this band draws from.
    ///
    /// The reference screenshots are Apple Fitness, whose bands are purple /
    /// green / teal. This app is palette-driven, and a card that ignores the
    /// user's chosen palette looks pasted on — so bands map onto palette slots
    /// instead of hard-coded colours: slot 0 (the palette's primary) means "on
    /// track", and the slots either side of it get progressively further from it
    /// as the reading moves away from Optimal. With the Monochrome palette that
    /// reads as a lightness ramp, which is the correct behaviour.
    var paletteIndex: Int {
        switch self {
        case .optimal: return 0
        case .above: return 1
        case .wellAbove: return 2
        case .below: return 3
        case .wellBelow: return 4
        case .noData: return 3
        }
    }

    /// Plain-language read on what the band means for the user, mirroring the
    /// paragraph Apple puts under the status word.
    var explanation: String {
        switch self {
        case .wellBelow:
            return "Your 7-day load is well below your baseline. That's a real taper — fine after a hard stretch, but memory decays without reviews, so expect more overdue revisions soon."
        case .below:
            return "Your 7-day load is below your baseline. A lighter week is normal, but if it stays here your retention will start to slip."
        case .optimal:
            return "Your 7-day load is in line with your baseline. This is the range where retention grows without burning you out."
        case .above:
            return "Your 7-day load is above your baseline. You may see gains in retention, but recover as needed if you feel especially fatigued."
        case .wellAbove:
            return "Your 7-day load is well above your baseline. This is a sharp ramp — watch your accuracy and take a lighter day if revisions start failing."
        case .noData:
            return "Not enough history yet. Load compares your last 7 days against a longer baseline, and it needs about two weeks of activity before that comparison means anything. Keep going — this fills in on its own."
        }
    }
}

/// Palette-aware colour for a revision-load band, so the card follows the user's
/// chosen palette the way every other card on the feed does.
extension ColorPaletteManager {
    func loadColor(for band: RevisionLoadBand) -> Color {
        band == .noData ? Color.white.opacity(0.55) : color(at: band.paletteIndex)
    }
}

/// Which slice of practice a load figure covers. Mirrors the workout-type chips
/// Apple puts above the training-load status.
enum LoadScope: String, CaseIterable, Identifiable {
    case all
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Practice"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// `nil` for `.all`; otherwise the backend difficulty string.
    var difficultyKey: String? {
        self == .all ? nil : rawValue
    }
}

/// The overall load plus a per-difficulty breakdown, so the detail view can
/// switch chips without recomputing anything on every redraw.
struct RevisionLoadBreakdown {
    let overall: RevisionLoadSnapshot
    let easy: RevisionLoadSnapshot
    let medium: RevisionLoadSnapshot
    let hard: RevisionLoadSnapshot

    static let empty = RevisionLoadBreakdown(
        overall: .empty,
        easy: .empty,
        medium: .empty,
        hard: .empty
    )

    func snapshot(for scope: LoadScope) -> RevisionLoadSnapshot {
        switch scope {
        case .all: return overall
        case .easy: return easy
        case .medium: return medium
        case .hard: return hard
        }
    }

    static func build(
        revisions: [Revision],
        solves: [Solve],
        now: Date = Date()
    ) -> RevisionLoadBreakdown {
        let easySolves = solves.filter { $0.problem.difficulty.lowercased() == "easy" }
        let mediumSolves = solves.filter { $0.problem.difficulty.lowercased() == "medium" }
        let hardSolves = solves.filter { $0.problem.difficulty.lowercased() == "hard" }

        let easyRevisions = revisions.filter { $0.problem.difficulty.lowercased() == "easy" }
        let mediumRevisions = revisions.filter { $0.problem.difficulty.lowercased() == "medium" }
        let hardRevisions = revisions.filter { $0.problem.difficulty.lowercased() == "hard" }

        return RevisionLoadBreakdown(
            overall: ActivityMetrics.revisionLoad(revisions: revisions, solves: solves, now: now),
            easy: ActivityMetrics.revisionLoad(revisions: easyRevisions, solves: easySolves, now: now),
            medium: ActivityMetrics.revisionLoad(revisions: mediumRevisions, solves: mediumSolves, now: now),
            hard: ActivityMetrics.revisionLoad(revisions: hardRevisions, solves: hardSolves, now: now)
        )
    }
}

struct RevisionLoadSnapshot {
    let band: RevisionLoadBand
    /// Percent change of the 7-day daily average against the baseline daily
    /// average. `nil` when there is nothing to compare against.
    let percentChange: Int?
    let recentDailyAverage: Double
    let baselineDailyAverage: Double
    let series: [DailyLoadPoint]
    let windowTotal: Double
    /// Length of the baseline window actually in use: 28 normally, 15 while the
    /// account is younger than a month, `nil` when there is not enough history
    /// to grade at all.
    let baselineDays: Int?

    static let empty = RevisionLoadSnapshot(
        band: .noData,
        percentChange: nil,
        recentDailyAverage: 0,
        baselineDailyAverage: 0,
        series: [],
        windowTotal: 0,
        baselineDays: nil
    )

    var hasData: Bool { band != .noData }

    /// "+38%" / "-12%" / nil.
    var formattedPercentChange: String? {
        guard let percentChange else { return nil }
        return percentChange >= 0 ? "+\(percentChange)%" : "\(percentChange)%"
    }

    /// "7-day vs. 28-day load" — or 15-day, while that is the window in use.
    var comparisonLabel: String {
        let days = baselineDays ?? ActivityMetrics.loadBaselineDays
        return "7-day vs. \(days)-day load"
    }

    /// "28-Day Daily Load" / "15-Day Daily Load".
    var baselineLabel: String {
        let days = baselineDays ?? ActivityMetrics.loadBaselineDays
        return "\(days)-Day Daily Load"
    }

    /// The band a single day's load falls into, so chart points can be tinted.
    func band(for value: Double) -> RevisionLoadBand {
        guard baselineDailyAverage > 0 else { return .noData }
        guard value > 0 else { return .wellBelow }
        return RevisionLoadBand.from(ratio: value / baselineDailyAverage)
    }
}
