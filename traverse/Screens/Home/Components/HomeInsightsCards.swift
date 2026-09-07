import SwiftUI
import Charts

struct MistakeTagsAnalysisCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var cardData: (tagCounts: [(String, Int)], totalTags: Int, maxCount: Int) {
        var counts: [String: Int] = [:]
        for solve in solves {
            if let tags = solve.mistakeTags ?? solve.submission.mistakeTags {
                var seen = Set<String>()
                for tag in tags {
                    guard seen.insert(tag).inserted else { continue }
                    counts[tag, default: 0] += 1
                }
            }
        }
        let sorted = counts.sorted {
            if $0.value != $1.value {
                return $0.value > $1.value
            }
            return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }
        let total = sorted.reduce(0) { $0 + $1.1 }
        let maxC = max(sorted.map { $0.1 }.max() ?? 1, 1)
        return (sorted, total, maxC)
    }
    
    var body: some View {
        let data = cardData
        let tagCounts = data.tagCounts
        let totalTags = data.totalTags
        let maxCount = data.maxCount
        
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(paletteManager.color(at: 5))
                    Text("Mistake Analysis")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("\(tagCounts.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 5))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !tagCounts.isEmpty {
                // Hero total
                VStack(spacing: 4) {
                    Text("\(totalTags)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Total Mistakes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Horizontal bars for TOP 3 tags
                VStack(spacing: 12) {
                    ForEach(Array(tagCounts.prefix(3).enumerated()), id: \.element.0) { index, item in
                        MistakeTagProgressRow(
                            label: item.0,
                            count: item.1,
                            maxCount: maxCount,
                            color: paletteManager.color(at: index % 10)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("No mistakes detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Keep solving problems!")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 120)
                .padding()
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Mistake Tag Progress Row
struct MistakeTagProgressRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    
    private var progress: CGFloat {
        guard maxCount > 0 else { return 0 }
        let p = CGFloat(count) / CGFloat(maxCount)
        return (p.isFinite && !p.isNaN) ? min(max(p, 0), 1) : 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            
            GeometryReader { geometry in
                let targetWidth = geometry.size.width * progress
                let safeWidth = (targetWidth.isFinite && !targetWidth.isNaN && geometry.size.width > 0)
                    ? max(min(targetWidth, geometry.size.width), count > 0 ? 12 : 0)
                    : (count > 0 ? 12 : 0)
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: safeWidth, height: 12)
                }
            }
            .frame(height: 12)
            
            Text("\(count)")
                .font(.subheadline)
                .bold()
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Mistake Tags Detail View

struct AchievementStatsCard: View {
    let stats: AchievementStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var glowPhase: CGFloat = 0
    
    // Progress determines glow intensity (0 to 1)
    private var progress: CGFloat {
        CGFloat(stats.unlocked) / CGFloat(max(stats.total, 1))
    }
    
    // Break up complex expressions for compiler
    private var glowFillOpacity: Double {
        let baseOpacity: Double = 0.15
        let progressMultiplier: Double = Double(progress) * 0.4
        let animationFactor: Double = 0.5 + 0.5 * sin(glowPhase)
        return baseOpacity + progressMultiplier * animationFactor
    }
    
    private var accentColor: Color {
        paletteManager.color(at: 3)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero number only
            VStack(spacing: 8) {
                Text("\(stats.unlocked)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("of \(stats.total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(glowFillOpacity), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .allowsHitTesting(false)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
}

// MARK: - Productivity Insights Card (Weekly Activity)
struct ProductivityInsightsCard: View {
    let solves: [Solve]
    let completedRevisions: [Revision]
    @ObservedObject var paletteManager: ColorPaletteManager

    private struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let solves: Int
        let revisions: Int
    }

    private var last7DaysData: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Count solves by day
        var solveCounts: [Date: Int] = [:]
        for solve in solves {
            var date = formatter.date(from: solve.solvedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: solve.solvedAt)
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            }
            if let solveDate = date {
                let dayStart = calendar.startOfDay(for: solveDate)
                solveCounts[dayStart, default: 0] += 1
            }
        }

        // Count completed revisions by day
        var revisionCounts: [Date: Int] = [:]
        for revision in completedRevisions {
            guard let completedAtString = revision.completedAt else { continue }
            var date = formatter.date(from: completedAtString)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: completedAtString)
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            }
            if let completedDate = date {
                let dayStart = calendar.startOfDay(for: completedDate)
                revisionCounts[dayStart, default: 0] += 1
            }
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

    private var maxValue: Int {
        let maxSolves = last7DaysData.map { $0.solves }.max() ?? 0
        let maxRevisions = last7DaysData.map { $0.revisions }.max() ?? 0
        return max(maxSolves, maxRevisions, 1)
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
                        x: .value("Day", day.label),
                        y: .value("Count", day.solves)
                    )
                    .foregroundStyle(paletteManager.color(at: 0))
                    .position(by: .value("Type", "Solves"))

                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Count", day.revisions)
                    )
                    .foregroundStyle(paletteManager.color(at: 1))
                    .position(by: .value("Type", "Revisions"))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
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
    }
}

// MARK: - Best Solving Hours Card
struct BestSolvingHoursCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var hourlyData: [(hour: Int, count: Int, avgTime: Double)] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var hourCounts: [Int: Int] = [:]
        var hourTimes: [Int: [Int]] = [:]
        
        for solve in solves {
            if let date = formatter.date(from: solve.solvedAt) {
                let hour = Calendar.current.component(.hour, from: date)
                hourCounts[hour, default: 0] += 1
                if let time = solve.submission.timeTaken {
                    hourTimes[hour, default: []].append(time)
                }
            }
        }
        
        return (0..<24).map { hour in
            let count = hourCounts[hour] ?? 0
            let times = hourTimes[hour] ?? []
            let avgTime = times.isEmpty ? 0 : Double(times.reduce(0, +)) / Double(times.count)
            return (hour, count, avgTime)
        }
    }
    
    private var peakHour: (hour: Int, count: Int) {
        if let max = hourlyData.max(by: { $0.count < $1.count }) {
            return (max.hour, max.count)
        }
        return (0, 0)
    }
    
    private var fastestHour: (hour: Int, avgTime: Double)? {
        let validHours = hourlyData.filter { $0.avgTime > 0 }
        return validHours.min(by: { $0.avgTime < $1.avgTime }).map { ($0.hour, $0.avgTime) }
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12am" }
        if hour < 12 { return "\(hour)am" }
        if hour == 12 { return "12pm" }
        return "\(hour - 12)pm"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        if mins > 0 { return "\(mins)m" }
        return "\(Int(seconds))s"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(paletteManager.color(at: 6))
                    Text("Solving Hours")
                        .font(.headline)
                }
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Stats summary
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatHour(peakHour.hour))
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
                        Text("Fastest (\(formatTime(fastest.avgTime)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Bar chart showing activity by hour
            Chart(hourlyData, id: \.hour) { data in
                BarMark(
                    x: .value("Hour", data.hour),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(
                    data.hour == peakHour.hour
                        ? paletteManager.color(at: 6).gradient
                        : paletteManager.color(at: 6).opacity(0.4).gradient
                )
                .cornerRadius(2)
            }
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
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - All Achievements View
