import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var paletteManager: ColorPaletteManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                metricsGrid
                chartGrid
            }
            .padding(24)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        ThemedCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back, \(appState.user?.username ?? "coder")")
                        .font(.largeTitle.weight(.bold))
                    Text("Your Traverse progress, revision pressure, and coding activity in one desktop view.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StreakBadge(streak: appState.userStats?.stats.currentStreak ?? appState.user?.currentStreak ?? 0)
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            MetricCard(title: "Total XP", value: appState.userStats?.stats.totalXp ?? appState.user?.totalXp ?? 0, symbol: "sparkles", color: paletteManager.color(at: 0))
            MetricCard(title: "Solves", value: appState.userStats?.stats.totalSolves ?? 0, symbol: "checkmark.seal", color: paletteManager.color(at: 1))
            MetricCard(title: "Submissions", value: appState.userStats?.stats.totalSubmissions ?? 0, symbol: "terminal", color: paletteManager.color(at: 2))
            MetricCard(title: "Achievements", value: appState.achievementStats?.stats.unlocked ?? 0, symbol: "trophy", color: paletteManager.color(at: 3))
            MetricCard(title: "Freezes", value: appState.userStats?.stats.availableFreezes ?? appState.freezeInfo?.availableFreezes ?? 0, symbol: "snowflake", color: Color(red: 0.31, green: 0.76, blue: 0.97))
        }
    }

    private var chartGrid: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                DifficultyChart(difficulty: appState.solveStats?.stats.byDifficulty ?? appState.userStats?.stats.problemsByDifficulty ?? .init())
                PlatformChart(platforms: appState.solveStats?.stats.byPlatform ?? [:])
            }
            HStack(alignment: .top, spacing: 14) {
                SubmissionChart(stats: appState.submissionStats?.stats)
                LanguageChart(languages: appState.submissionStats?.stats.languageBreakdown ?? [])
            }
            HStack(alignment: .top, spacing: 14) {
                HeatmapCard(solves: appState.allSolves.isEmpty ? appState.recentSolves : appState.allSolves, freezeDates: Set(appState.freezeDates))
                TriesChart(solves: appState.allSolves.isEmpty ? appState.recentSolves : appState.allSolves)
            }
        }
    }

}

struct MetricCard: View {
    let title: String
    let value: Int
    let symbol: String
    let color: Color

    var body: some View {
        ThemedCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value.formatted())
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.16), in: Circle())
            }
        }
    }
}

struct StreakBadge: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let streak: Int

    var body: some View {
        let colors = paletteManager.streakGradientColors(for: streak)
        VStack(spacing: 2) {
            Text("\(streak)")
                .font(.system(size: 42, weight: .black, design: .rounded))
            Text("Day Streak")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(width: 130, height: 96)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct DifficultyChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let difficulty: ProblemsByDifficulty

    var data: [(String, Int)] {
        [("Easy", difficulty.easy), ("Medium", difficulty.medium), ("Hard", difficulty.hard)]
    }

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Problems by Difficulty").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: data.allSatisfy { $0.1 == 0 }, emptyTitle: "No difficulty data", emptySystemImage: "chart.bar", emptyDescription: "Difficulty breakdown appears after solves sync.")
                Chart(data, id: \.0) { item in
                    BarMark(x: .value("Difficulty", item.0), y: .value("Problems", item.1))
                        .foregroundStyle(color(for: item.0))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 190)
                .chartYAxis(.automatic)
            }
        }
    }

    private func color(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": paletteManager.color(at: 0)
        case "Medium": paletteManager.color(at: 1)
        default: paletteManager.color(at: 2)
        }
    }
}

struct PlatformChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let platforms: [String: Int]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Platform Breakdown").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: platforms.isEmpty, emptyTitle: "No platform data", emptySystemImage: "chart.bar.xaxis", emptyDescription: "Platform breakdown appears after solves sync.")
                Chart(Array(platforms.sorted { $0.value > $1.value }), id: \.key) { item in
                    BarMark(x: .value("Count", item.value), y: .value("Platform", item.key))
                        .foregroundStyle(paletteManager.color(at: abs(item.key.hashValue) % 5))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .frame(height: 190)
            }
        }
    }
}

struct SubmissionChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let stats: SubmissionStatsData?

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Submission Quality").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: (stats?.total ?? 0) == 0, emptyTitle: "No submissions", emptySystemImage: "terminal", emptyDescription: "Accepted and failed submissions will appear here.")
                Chart([
                    ("Accepted", stats?.accepted ?? 0),
                    ("Failed", stats?.failed ?? 0)
                ], id: \.0) { item in
                    SectorMark(angle: .value("Submissions", item.1), innerRadius: .ratio(0.62), angularInset: 2)
                        .foregroundStyle(item.0 == "Accepted" ? paletteManager.color(at: 0) : paletteManager.color(at: 2))
                }
                .frame(height: 160)
                Text("Acceptance rate \(stats?.acceptanceRate ?? "0%")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LanguageChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let languages: [LanguageBreakdown]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Languages").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: languages.isEmpty, emptyTitle: "No language data", emptySystemImage: "curlybraces", emptyDescription: "Language usage appears after submission sync.")
                Chart(languages.prefix(8)) { item in
                    BarMark(x: .value("Language", item.language), y: .value("Count", item.count))
                        .foregroundStyle(paletteManager.color(at: abs(item.language.hashValue) % 5))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .frame(height: 190)
            }
        }
    }
}

struct HeatmapCard: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let solves: [Solve]
    let freezeDates: Set<String>

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity Heatmap").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: solves.isEmpty, emptyTitle: "No activity yet", emptySystemImage: "calendar", emptyDescription: "Solve activity appears after data sync.")
                GeometryReader { proxy in
                    let spacing: CGFloat = 4
                    let columns = 26
                    let cell = max(7, min(13, (proxy.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: columns), spacing: spacing) {
                        ForEach(days, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: day))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
                .frame(height: 86)
                HStack(spacing: 8) {
                    Text("Less").font(.caption).foregroundStyle(.secondary)
                    PaletteStrip(palette: paletteManager.selectedPalette)
                    Text("More").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        return (0..<130).compactMap { calendar.date(byAdding: .day, value: -129 + $0, to: calendar.startOfDay(for: .now)) }
    }

    private func color(for date: Date) -> Color {
        let key = Self.keyFormatter.string(from: date)
        if freezeDates.contains(key) { return Color(red: 0.31, green: 0.76, blue: 0.97) }
        let count = solves.filter { solve in
            guard let solved = DateParser.parse(solve.solvedAt) else { return false }
            return Calendar.current.isDate(solved, inSameDayAs: date)
        }.count
        if count == 0 { return Color.secondary.opacity(0.16) }
        return paletteManager.color(at: min(count - 1, 4))
    }

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct TriesChart: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let solves: [Solve]

    var body: some View {
        ThemedCard {
            VStack(alignment: .leading) {
                Text("Tries Distribution").font(.headline)
                PanelFeedback(status: .loaded(.now), isEmpty: distribution.isEmpty, emptyTitle: "No tries data", emptySystemImage: "chart.xyaxis.line", emptyDescription: "Number-of-tries distribution appears when solves include attempt data.")
                Chart(distribution, id: \.0) { item in
                    BarMark(x: .value("Tries", item.0), y: .value("Solves", item.1))
                        .foregroundStyle(paletteManager.color(at: item.0 % 5))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .frame(height: 190)
            }
        }
    }

    private var distribution: [(Int, Int)] {
        Dictionary(grouping: solves.compactMap(\.submission.numberOfTries), by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }
}

struct SolveRow: View {
    @EnvironmentObject private var paletteManager: ColorPaletteManager
    let solve: Solve

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(solve.problem.title)
                    .font(.headline)
                Text("\(solve.problem.platform) • \(solve.submission.language) • \(solve.xpAwarded) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(solve.problem.difficulty.capitalized)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(difficultyColor.opacity(0.16), in: Capsule())
                .foregroundStyle(difficultyColor)
        }
    }

    private var difficultyColor: Color {
        switch solve.problem.difficulty.lowercased() {
        case "easy": paletteManager.color(at: 0)
        case "medium": paletteManager.color(at: 1)
        default: paletteManager.color(at: 2)
        }
    }
}
