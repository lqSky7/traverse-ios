import SwiftUI
import Charts
import Combine
import WidgetKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, M"
        return formatter.string(from: Date())
    }

    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "", forceRefresh: true)
                            }
                        })
                    } else {
                        // Streak Card
                        if let userStats = viewModel.userStats {
                            StreakCard(streak: userStats.stats.currentStreak, maxStreak: userStats.stats.totalStreakDays)
                        }
                        
                        // Main Stats Cards
                        if let solveStats = viewModel.solveStats {
                            MainStatsCard(stats: solveStats.stats, paletteManager: paletteManager)
                        }
                        
                        // Charts Section
                        VStack(spacing: 16) {
                            // Achievements and Insights side by side
                            if let achievementStats = viewModel.achievementStats,
                               let solves = viewModel.recentSolves, !solves.isEmpty {
                                HStack(alignment: .top, spacing: 16) {
                                    NavigationLink(destination: AllAchievementsView()) {
                                        AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    ProductivityInsightsCard(solves: solves, completedRevisions: viewModel.completedRevisions, paletteManager: paletteManager)
                                }
                            } else if let achievementStats = viewModel.achievementStats {
                                NavigationLink(destination: AllAchievementsView()) {
                                    AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if let solveStats = viewModel.solveStats,
                               let solves = viewModel.recentSolves {
                                // Difficulty and Activity side by side
                                HStack(alignment: .top, spacing: 16) {
                                    DifficultyChartCard(stats: solveStats.stats, paletteManager: paletteManager)
                                    NavigationLink(destination: ActivityDetailView(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)) {
                                        SolveHeatmapCard(solves: solves, frozenDates: viewModel.frozenDates, paletteManager: paletteManager)
                                            .id(viewModel.frozenDates.count)  // Force re-render when frozenDates changes
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Mistake Tags Analysis full width
                                NavigationLink(destination: MistakeTagsDetailView(solves: solves, paletteManager: paletteManager)) {
                                    MistakeTagsAnalysisCard(solves: solves, paletteManager: paletteManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Best Solving Hours (replaces Submission Breakdown)
                                BestSolvingHoursCard(solves: solves, paletteManager: paletteManager)
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                RecentSolvesCard(solves: solves, paletteManager: paletteManager)
                                
                                // New Performance Charts
                                PerformanceMetricsCard(solves: solves, paletteManager: paletteManager)
                                
                                TriesDistributionCard(solves: solves, paletteManager: paletteManager)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.large)
            .toolbarScrollMinimization()
            .refreshable {
                if let username = authViewModel.currentUser?.username {
                    // Use Task to prevent early cancellation from pull-to-refresh gesture
                    await Task {
                        await viewModel.loadData(username: username, forceRefresh: true)
                    }.value
                }
            }
        }
        .onAppear {
            if let username = authViewModel.currentUser?.username {
                // Set username for Watch sync
                WidgetDataUpdater.shared.currentUsername = username
                Task {
                    await viewModel.loadData(username: username)
                }
            }
        }
        .onChange(of: authViewModel.currentUser?.username) { oldUsername, newUsername in
            if let username = newUsername {
                // Update username for Watch sync
                WidgetDataUpdater.shared.currentUsername = username
                if viewModel.solveStats == nil {
                    Task {
                        await viewModel.loadData(username: username)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .revisionCompleted)) { _ in
            if let username = authViewModel.currentUser?.username {
                Task {
                    await viewModel.loadData(username: username, forceRefresh: true)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {
        guard let solves = recentSolves else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Create ISO8601 formatter that handles optional fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return solves.contains { solve in
            // Try with fractional seconds first, then without
            var date = formatter.date(from: solve.solvedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: solve.solvedAt)
            }
            
            if let solveDate = date {
                return calendar.isDate(solveDate, inSameDayAs: now)
            }
            return false
        }
    }
    

}

// MARK: - Streak Card
struct StreakCard: View {
    let streak: Int
    var maxStreak: Int? = nil
    
    private var displayNumber: String {
        streak == 0 ? "0" : "\(streak)"
    }
    
    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }
    
    private var maxStreakDisplay: Int {
        max(streak, maxStreak ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: streak == 0 ? "flame" : "flame.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayNumber)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text(daysText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            if maxStreakDisplay > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BEST")
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                    Text("\(maxStreakDisplay) DAYS")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LightingSunBackground(streak: streak)
        )
        .cornerRadius(16)
    }
}

// MARK: - Lighting Sun Background (Lighting Simulation Shader from Settings > Demo)
struct LightingSunBackground: View {
    let streak: Int
    @State private var animatedProgress: Double = 0.0
    
    private var targetProgress: Double {
        Double(min(max(Float(streak), 0), 15.0) / 15.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            AnimatableLightingSun(
                progress: animatedProgress,
                cardHeight: geometry.size.height
            )
        }
        .onAppear {
            animatedProgress = 0.0
            withAnimation(.spring(response: 1.1, dampingFraction: 0.72, blendDuration: 0)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: streak) { _, newStreak in
            let newTarget = Double(min(max(Float(newStreak), 0), 15.0) / 15.0)
            withAnimation(.spring(response: 1.1, dampingFraction: 0.72, blendDuration: 0)) {
                animatedProgress = newTarget
            }
        }
    }
}

private struct AnimatableLightingSun: View, Animatable {
    var progress: Double
    var cardHeight: CGFloat
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        let p = Float(progress)
        let intensity = 0.3 + p * 2.2
        let disperse = 0.15 + p * 0.60
        let radius = 10.0 + p * 40.0
        let height = Float(cardHeight > 0 ? cardHeight : 90.0)
        let targetY = height / 1.2
        
        Color.black
            .layerEffect(
                ShaderLibrary.lightingSimulation(
                    .float2(5.0, targetY),
                    .float(intensity),
                    .float(disperse),
                    .float(-Float.pi / 2.0),
                    .float(radius)
                ),
                maxSampleOffset: .zero
            )
    }
}



// MARK: - Main Stats Card
struct MainStatsCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Your Progress")
                        .font(.headline)
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            HStack(spacing: 0) {
                StatItem(
                    title: "Total Solves",
                    value: "\(stats.totalSolves)",
                    icon: "checkmark.seal.fill",
                    color: paletteManager.color(at: 0)
                )
                
                Divider()
                    .frame(height: 60)
                
                StatItem(
                    title: "Total XP",
                    value: "\(stats.totalXp)",
                    icon: "sparkles",
                    color: paletteManager.color(at: 1)
                )
                
                Divider()
                    .frame(height: 60)
                
                StatItem(
                    title: "Streak",
                    value: "\(stats.totalStreakDays)",
                    icon: "flame.fill",
                    color: paletteManager.color(at: 2)
                )
            }
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Difficulty Chart Card
struct DifficultyChartCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var totalProblems: Int {
        stats.byDifficulty.easy + stats.byDifficulty.medium + stats.byDifficulty.hard
    }
    
    private var maxCount: Int {
        max(stats.byDifficulty.easy, stats.byDifficulty.medium, stats.byDifficulty.hard, 1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Difficulty")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Hero total
            VStack(spacing: 4) {
                Text("\(totalProblems)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text("Total Solved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Horizontal progress bars
            VStack(spacing: 10) {
                DifficultyProgressRow(
                    label: "Easy",
                    count: stats.byDifficulty.easy,
                    maxCount: maxCount,
                    color: paletteManager.color(at: 0)
                )
                
                DifficultyProgressRow(
                    label: "Medium",
                    count: stats.byDifficulty.medium,
                    maxCount: maxCount,
                    color: paletteManager.color(at: 1)
                )
                
                DifficultyProgressRow(
                    label: "Hard",
                    count: stats.byDifficulty.hard,
                    maxCount: maxCount,
                    color: paletteManager.color(at: 2)
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Difficulty Progress Row
struct DifficultyProgressRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    
    private var progress: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    // Progress bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progress, count > 0 ? 12 : 0), height: 12)
                }
            }
            .frame(height: 12)
            
            Text("\(count)")
                .font(.subheadline)
                .bold()
                .foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Platform Chart Card
struct PlatformChartCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var chartData: [(String, Int)] {
        stats.byPlatform.map { ($0.key.capitalized, $0.value) }
            .sorted { $0.1 > $1.1 }
    }
    
    private var totalSolves: Int {
        chartData.reduce(0) { $0 + $1.1 }
    }
    
    private var maxCount: Int {
        chartData.map { $0.1 }.max() ?? 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "laptopcomputer")
                        .foregroundStyle(paletteManager.color(at: 4))
                    Text("Platforms")
                        .font(.headline)
                }
                Spacer()
                Text("\(chartData.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 4))
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !chartData.isEmpty {
                // Hero total
                VStack(spacing: 4) {
                    Text("\(totalSolves)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Total Solves")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Horizontal bars for each platform
                VStack(spacing: 12) {
                    ForEach(Array(chartData.prefix(4).enumerated()), id: \.element.0) { index, item in
                        PlatformProgressRow(
                            label: item.0,
                            count: item.1,
                            maxCount: maxCount,
                            color: paletteManager.color(at: index)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "laptopcomputer")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No platform data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 100)
                .padding()
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Platform Progress Row
struct PlatformProgressRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    
    private var progress: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            
            GeometryReader { geometry in
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
                        .frame(width: max(geometry.size.width * progress, count > 0 ? 12 : 0), height: 12)
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

// MARK: - Mistake Tags Analysis Card
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
struct MistakeTagsDetailView: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    @State private var searchText = ""
    @State private var selectedDifficulty: String = "All"
    @State private var sortOption: MistakeSortOption = .mostFrequent
    @State private var expandedTags: Set<String> = []
    
    enum MistakeSortOption: String, CaseIterable {
        case mostFrequent = "Most Frequent"
        case leastFrequent = "Least Frequent"
        case alphabetical = "Alphabetical"
    }
    
    struct MistakeSolveSummary: Identifiable {
        let id: String
        let title: String
        let difficulty: String
        let solvedAt: String
    }
    
    struct TagAnalysisItem: Identifiable {
        let id: String
        let tag: String
        let count: Int
        let matchingSolves: [MistakeSolveSummary]
    }
    
    private struct MistakeAnalysisData {
        let allItems: [TagAnalysisItem]
        let displayedItems: [TagAnalysisItem]
        let totalMistakes: Int
        let maxCount: Int
        let cleanPercentage: Int
    }
    
    private var analysisData: MistakeAnalysisData {
        // 1. Filter solves by difficulty
        let difficultyLower = selectedDifficulty.lowercased()
        let filteredSolves: [Solve]
        if selectedDifficulty == "All" {
            filteredSolves = solves
        } else {
            filteredSolves = solves.filter { $0.problem.difficulty.lowercased() == difficultyLower }
        }
        
        // 2. Count mistakes and group solves by tag in one O(N) pass
        var tagCounts: [String: Int] = [:]
        var tagSolves: [String: [MistakeSolveSummary]] = [:]
        var solvesWithMistakes = 0
        
        for solve in filteredSolves {
            let tags = solve.mistakeTags ?? solve.submission.mistakeTags ?? []
            if !tags.isEmpty {
                solvesWithMistakes += 1
                var seen = Set<String>()
                let summary = MistakeSolveSummary(
                    id: "\(solve.id)_\(solve.solvedAt)",
                    title: solve.problem.title,
                    difficulty: solve.problem.difficulty,
                    solvedAt: solve.solvedAt
                )
                for tag in tags {
                    guard seen.insert(tag).inserted else { continue }
                    tagCounts[tag, default: 0] += 1
                    tagSolves[tag, default: []].append(summary)
                }
            }
        }
        
        // 3. Build TagAnalysisItems
        let allItems: [TagAnalysisItem] = tagCounts.map { tag, count in
            TagAnalysisItem(
                id: tag,
                tag: tag,
                count: count,
                matchingSolves: tagSolves[tag] ?? []
            )
        }
        
        let totalMistakes = allItems.reduce(0) { $0 + $1.count }
        let maxCount = max(allItems.map { $0.count }.max() ?? 1, 1)
        
        let cleanSolves = filteredSolves.count - solvesWithMistakes
        let cleanPercentage = filteredSolves.isEmpty ? 100 : Int((Double(max(0, cleanSolves)) / Double(filteredSolves.count)) * 100)
        
        // 4. Search filter
        let searchTrimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredBySearch: [TagAnalysisItem]
        if searchTrimmed.isEmpty {
            filteredBySearch = allItems
        } else {
            filteredBySearch = allItems.filter { item in
                item.tag.localizedCaseInsensitiveContains(searchTrimmed) ||
                item.matchingSolves.contains { $0.title.localizedCaseInsensitiveContains(searchTrimmed) }
            }
        }
        
        // 5. Sort
        let displayedItems: [TagAnalysisItem]
        switch sortOption {
        case .mostFrequent:
            displayedItems = filteredBySearch.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        case .leastFrequent:
            displayedItems = filteredBySearch.sorted {
                if $0.count != $1.count { return $0.count < $1.count }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        case .alphabetical:
            displayedItems = filteredBySearch.sorted {
                $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        }
        
        return MistakeAnalysisData(
            allItems: allItems,
            displayedItems: displayedItems,
            totalMistakes: totalMistakes,
            maxCount: maxCount,
            cleanPercentage: cleanPercentage
        )
    }
    
    private func iconForTag(_ tag: String) -> String {
        let lower = tag.lowercased()
        if lower.contains("time") || lower.contains("tle") {
            return "clock.badge.exclamationmark"
        } else if lower.contains("memory") || lower.contains("mle") || lower.contains("space") {
            return "memorychip"
        } else if lower.contains("edge") || lower.contains("corner") || lower.contains("bound") {
            return "exclamationmark.triangle.fill"
        } else if lower.contains("approach") || lower.contains("logic") || lower.contains("algo") {
            return "brain.head.profile"
        } else if lower.contains("base") || lower.contains("recursion") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("null") || lower.contains("nil") || lower.contains("pointer") {
            return "questionmark.diamond.fill"
        } else if lower.contains("syntax") || lower.contains("type") {
            return "curlybraces"
        } else if lower.contains("overflow") {
            return "arrow.up.right.and.arrow.down.left.rectangle"
        } else if lower.contains("off-by-one") || lower.contains("index") {
            return "arrow.left.and.right"
        } else {
            return "tag.fill"
        }
    }
    
    private func formattedTagName(_ tag: String) -> String {
        tag.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .blue
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let d = date else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: d)
    }
    
    var body: some View {
        let data = analysisData
        let totalMistakes = data.totalMistakes
        let maxCount = max(data.maxCount, 1)
        let displayedTags = data.displayedItems
        
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Metrics Row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalMistakes)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                        Text("Total Mistakes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(data.allItems.count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 2))
                        Text("Mistake Types")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(data.cleanPercentage)%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 1))
                        Text("Clean Solves")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                
                // Difficulty Segmented Picker
                Picker("Difficulty", selection: $selectedDifficulty) {
                    Text("All").tag("All")
                    Text("Easy").tag("Easy")
                    Text("Medium").tag("Medium")
                    Text("Hard").tag("Hard")
                }
                .pickerStyle(.segmented)
                
                // Search Bar & Sort Menu
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search", text: $searchText)
                            .font(.subheadline)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(MistakeSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                    }
                }
                
                // Tags List
                if displayedTags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "No mistake tags found" : "No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(displayedTags.enumerated()), id: \.element.id) { index, item in
                            let isExpanded = expandedTags.contains(item.id)
                            let tagColor = paletteManager.color(at: index % 10)
                            let percentage = totalMistakes > 0 ? Int((Double(item.count) / Double(totalMistakes)) * 100) : 0
                            
                            VStack(alignment: .leading, spacing: 10) {
                                // Header row (tappable to expand)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if isExpanded {
                                            expandedTags.remove(item.id)
                                        } else {
                                            expandedTags.insert(item.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(tagColor.opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: iconForTag(item.tag))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(tagColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formattedTagName(item.tag))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                            
                                            Text("\(percentage)% of all mistakes • \(item.matchingSolves.count) \(item.matchingSolves.count == 1 ? "problem" : "problems")")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(item.count)")
                                            .font(.headline)
                                            .bold()
                                            .foregroundStyle(tagColor)
                                        
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Progress Bar
                                GeometryReader { geo in
                                    let ratio = maxCount > 0 ? CGFloat(item.count) / CGFloat(maxCount) : 0
                                    let targetWidth = geo.size.width * ratio
                                    let safeWidth = (targetWidth.isFinite && !targetWidth.isNaN && geo.size.width > 0)
                                        ? max(min(targetWidth, geo.size.width), 8)
                                        : 8

                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [tagColor, tagColor.opacity(0.7)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: safeWidth, height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                // Expanded Problem List
                                if isExpanded {
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.vertical, 2)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recent Problems")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        
                                        ForEach(item.matchingSolves) { solve in
                                            HStack(spacing: 8) {
                                                Text(solve.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Text(solve.difficulty.capitalized)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(difficultyColor(solve.difficulty).opacity(0.15))
                                                    .foregroundStyle(difficultyColor(solve.difficulty))
                                                    .cornerRadius(4)
                                                
                                                Text(formatDate(solve.solvedAt))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 3)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Mistake Analysis")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
    }
}


// MARK: - Achievement Stats Card (Compact Half-Width)
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
struct AllAchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var filterMode: AchievementFilter = .all
    
    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case locked = "Locked"
    }
    
    private var filteredAchievements: [AchievementDetail]? {
        guard let achievements = viewModel.achievements else { return nil }
        
        switch filterMode {
        case .all:
            return achievements
        case .unlocked:
            return achievements.filter { $0.unlocked }
        case .locked:
            return achievements.filter { !$0.unlocked }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadAchievements()
                            }
                        })
                    } else if let achievements = filteredAchievements {
                        // Spacer for sticky card
                        Color.clear
                            .frame(height: 130)
                        
                        // Categories with expandable achievements
                        CategoriesSection(achievements: achievements, paletteManager: paletteManager)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            
            // Sticky Summary Card
            if let achievements = viewModel.achievements {
                VStack {
                    SummaryCard(
                        achievements: achievements,
                        paletteManager: paletteManager
                    )
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("All Achievements")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(AchievementFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            filterMode = filter
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                if filterMode == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear {
            if viewModel.achievements == nil {
                Task {
                    await viewModel.loadAchievements()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }
    
    private var totalCount: Int {
        achievements.count
    }
    
    private var progressPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(unlockedCount) / Double(totalCount)) * 100)
    }
    
    private var remainingCount: Int {
        totalCount - unlockedCount
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress with vertical separators
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(totalCount)")
                        .font(.title)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Vertical separator
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("\(progressPercentage)%")
                        .font(.title)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Vertical separator
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 4) {
                    Text("\(remainingCount)")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.gray)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mesh Gradient Background
struct MeshGradientBackground: View {
    @ObservedObject var paletteManager: ColorPaletteManager
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Multiple gradient layers for mesh effect
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    paletteManager.color(at: index).opacity(0.3),
                                    paletteManager.color(at: index).opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(
                            x: geometry.size.width * (0.3 + CGFloat(index) * 0.2) * (1 + phase * 0.3) - 200,
                            y: geometry.size.height * (0.2 + CGFloat(index) * 0.3) * (1 - phase * 0.2) - 200
                        )
                        .blur(radius: 60)
                }
                
                // Additional moving gradient layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                paletteManager.color(at: 4).opacity(0.25),
                                paletteManager.color(at: 3).opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(
                        x: geometry.size.width * 0.7 * (1 - phase * 0.4) - 250,
                        y: geometry.size.height * 0.6 * (1 + phase * 0.3) - 250
                    )
                    .blur(radius: 80)
            }
        }
    }
}

// MARK: - Categories Section
struct CategoriesSection: View {
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var groupedAchievements: [String: [AchievementDetail]] {
        Dictionary(grouping: achievements) { $0.category }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements by Category")
                .font(.headline)
            
            ForEach(groupedAchievements.sorted(by: { $0.key < $1.key }), id: \.key) { category, categoryAchievements in
                AchievementCategoryCard(
                    category: category,
                    achievements: categoryAchievements,
                    paletteManager: paletteManager
                )
            }
        }
    }
}

// MARK: - Achievement Category Card
struct AchievementCategoryCard: View {
    let category: String
    let achievements: [AchievementDetail]
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var isExpanded = false
    
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }
    
    private var categoryIcon: String {
        switch category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    private var sortedAchievements: [AchievementDetail] {
        achievements.sorted { ($0.unlocked && !$1.unlocked) || ($0.unlocked == $1.unlocked && $0.name < $1.name) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Header Button (matching SolveRow expansion toggle logic)
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: categoryIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(categoryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.capitalized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("\(unlockedCount) of \(achievements.count) unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable Achievements List
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.gray.opacity(0.25))
                    
                    let sorted = sortedAchievements
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, achievement in
                        AchievementRow(achievement: achievement, paletteManager: paletteManager)
                        
                        if index < sorted.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.25))
                                .padding(.leading, 68)
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievement Row
struct AchievementRow: View {
    let achievement: AchievementDetail
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var categoryIcon: String {
        if let icon = achievement.icon, !icon.isEmpty {
            if UIImage(systemName: icon) != nil {
                return icon
            }
            switch icon.lowercased() {
            case "trophy": return "trophy.fill"
            case "flame", "fire": return "flame.fill"
            case "star": return "star.fill"
            case "bolt", "zap": return "bolt.fill"
            case "brain": return "brain.head.profile"
            case "crown": return "crown.fill"
            case "target": return "target"
            case "seal", "badge": return "checkmark.seal.fill"
            case "chart": return "chart.line.uptrend.xyaxis"
            case "sparkles": return "sparkles"
            case "award": return "award.fill"
            default: break
            }
        }
        switch achievement.category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    private var categoryColor: Color {
        guard achievement.unlocked else { return Color.gray }
        switch achievement.category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Clean Achievement Badge Icon (no blur or glow)
            ZStack {
                if achievement.unlocked {
                    Circle()
                        .fill(categoryColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(categoryColor)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(achievement.unlocked ? .white : .gray)
                    
                    if achievement.unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if achievement.unlocked, let unlockedAt = achievement.unlockedAt {
                    Text("Unlocked \(formatDate(unlockedAt))")
                        .font(.caption2)
                        .foregroundStyle(categoryColor.opacity(0.9))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(achievement.unlocked ? 1.0 : 0.65)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "recently"
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

// MARK: - Achievements View Model
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [AchievementDetail]?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadAchievements() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await NetworkService.shared.getAllAchievements()
            await MainActor.run {
                self.achievements = response.achievements
                AchievementToastManager.shared.checkNewAchievements(response.achievements)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Submission Stats Card
struct SubmissionStatsCard: View {
    let stats: SubmissionStatsData
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submission Statistics")
                .font(.headline)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(stats.total)")
                        .font(.title2)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("\(stats.accepted)")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Accepted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("\(stats.failed)")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(String(format: "%.0f", Double(stats.acceptanceRate.replacingOccurrences(of: "%", with: "")) ?? 0))
                            .font(.title2)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("%")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 8))
                    }
                    Text("Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Difficulty Pie Chart Card (NEW)
// MARK: - Solve Heatmap Card
struct SolveHeatmapCard: View {
    let solves: [Solve]
    let frozenDates: Set<String>  // YYYY-MM-DD format
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(solves: [Solve], frozenDates: Set<String> = [], paletteManager: ColorPaletteManager) {
        self.solves = solves
        self.frozenDates = frozenDates
        self.paletteManager = paletteManager
    }
    
    // Process solves into date -> difficulty data
    private var heatmapData: [Date: String] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var data: [Date: String] = [:]
        
        for solve in solves {
            guard let date = formatter.date(from: solve.solvedAt) else { continue }
            let day = Calendar.current.startOfDay(for: date)
            // Keep the hardest difficulty for each day
            if let existing = data[day] {
                data[day] = harderDifficulty(existing, solve.problem.difficulty)
            } else {
                data[day] = solve.problem.difficulty
            }
        }
        return data
    }
    
    private func harderDifficulty(_ a: String, _ b: String) -> String {
        let order = ["easy": 0, "medium": 1, "hard": 2]
        let aVal = order[a.lowercased()] ?? 0
        let bVal = order[b.lowercased()] ?? 0
        return aVal >= bVal ? a : b
    }
    
    // Generate last 7 weeks of dates
    private var weekDates: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var weeks: [[Date]] = []
        
        // Start from 8 weeks ago (9 weeks total)
        for weekOffset in (0..<7).reversed() {
            var week: [Date] = []
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                    week.append(day)
                }
            }
            weeks.append(week)
        }
        return weeks
    }
    
    private func colorForDate(_ date: Date) -> Color {
        // Check if this date was frozen (ice blue color)
        let dateString = Self.dateFormatter.string(from: date)
        if frozenDates.contains(dateString) {
            return Color(red: 0.31, green: 0.76, blue: 0.97) // Ice blue #4FC3F7
        }
        
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard let difficulty = heatmapData[normalizedDate] else {
            return Color.gray.opacity(0.15)
        }
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private var totalSolvedDays: Int {
        heatmapData.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.caption)
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Activity")
                        .font(.headline)
                }
                Spacer()
                Text("\(totalSolvedDays)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 3))
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, -16)
            
            // Heatmap grid - larger cells to fill space
            HStack(spacing: 3) {
                // Weeks
                HStack(spacing: 3) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { weekIndex, week in
                        VStack(spacing: 3) {
                            ForEach(week, id: \.self) { date in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(colorForDate(date))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            // Compact legend - dots only, centered
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    Circle().fill(paletteManager.color(at: 0)).frame(width: 8, height: 8)
                    Circle().fill(paletteManager.color(at: 1)).frame(width: 8, height: 8)
                    Circle().fill(paletteManager.color(at: 2)).frame(width: 8, height: 8)
                }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Activity Detail View (Full Screen Heatmap)
struct ActivityDetailView: View {
    let solves: [Solve]
    var frozenDates: Set<String> = []  // YYYY-MM-DD format
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // Process solves into date -> difficulty data
    private var heatmapData: [Date: (difficulty: String, count: Int)] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var data: [Date: (String, Int)] = [:]
        
        for solve in solves {
            guard let date = formatter.date(from: solve.solvedAt) else { continue }
            let day = Calendar.current.startOfDay(for: date)
            if let existing = data[day] {
                let newDifficulty = harderDifficulty(existing.0, solve.problem.difficulty)
                data[day] = (newDifficulty, existing.1 + 1)
            } else {
                data[day] = (solve.problem.difficulty, 1)
            }
        }
        return data
    }
    
    private func harderDifficulty(_ a: String, _ b: String) -> String {
        let order = ["easy": 0, "medium": 1, "hard": 2]
        let aVal = order[a.lowercased()] ?? 0
        let bVal = order[b.lowercased()] ?? 0
        return aVal >= bVal ? a : b
    }
    
    // Generate last 20 weeks of dates (fits on screen)
    private var weekDates: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var weeks: [[Date]] = []
        
        for weekOffset in (0..<20).reversed() {
            var week: [Date] = []
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                    week.append(day)
                }
            }
            weeks.append(week)
        }
        return weeks
    }
    
    private func colorForDate(_ date: Date) -> Color {
        // Check if this date is a frozen day (ice blue)
        let dateString = Self.dateFormatter.string(from: date)
        if frozenDates.contains(dateString) {
            return Color(red: 0.31, green: 0.76, blue: 0.97)
        }
        
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard let data = heatmapData[normalizedDate] else {
            return Color.gray.opacity(0.15)
        }
        switch data.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private var totalActiveDays: Int {
        heatmapData.count
    }
    
    private var totalSolves: Int {
        heatmapData.values.reduce(0) { $0 + $1.1 }
    }
    
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary stats
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalActiveDays)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 3))
                        Text("Active Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalSolves)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 0))
                        Text("Total Solves")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Heatmap card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last 20 Weeks")
                        .font(.headline)
                    
                    // Heatmap grid with day labels
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width - 40 // Account for day labels
                        let cellSize = (availableWidth - CGFloat(19 * 3)) / 20 // 20 weeks, 3pt spacing
                        
                        HStack(alignment: .top, spacing: 4) {
                            // Day labels
                            VStack(spacing: max(cellSize * 0.2, 2)) {
                                ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, day in
                                    Text(day)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, height: cellSize, alignment: .trailing)
                                }
                            }
                            
                            // Heatmap grid
                            HStack(spacing: 3) {
                                ForEach(Array(weekDates.enumerated()), id: \.offset) { _, week in
                                    VStack(spacing: 3) {
                                        ForEach(week, id: \.self) { date in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(colorForDate(date))
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 140)
                    
                    // Legend
                    HStack {
                        HStack(spacing: 8) {
                            Text("Less")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                ForEach([Color.gray.opacity(0.15), paletteManager.color(at: 0), paletteManager.color(at: 1), paletteManager.color(at: 2)], id: \.self) { color in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Text("More")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Difficulty legend
                    HStack(spacing: 16) {
                        ForEach([(paletteManager.color(at: 0), "Easy"), (paletteManager.color(at: 1), "Medium"), (paletteManager.color(at: 2), "Hard")], id: \.1) { color, label in
                            HStack(spacing: 6) {
                                Circle().fill(color).frame(width: 10, height: 10)
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
    }
}

// MARK: - Submission Breakdown Card (NEW)
struct SubmissionBreakdownCard: View {
    let stats: SubmissionStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submission Breakdown")
                .font(.headline)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 20) {
                // Stacked Bar Chart
                Chart {
                    BarMark(
                        x: .value("Count", max(stats.accepted, 1))
                    )
                    .foregroundStyle(paletteManager.color(at: 3).gradient)
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Count", max(stats.failed, 1)),
                        stacking: .standard
                    )
                    .foregroundStyle(paletteManager.color(at: 4).gradient)
                    .cornerRadius(6)
                }
                .frame(height: 60)
                .chartXScale(domain: 0...(Double(max(stats.accepted + stats.failed, 1))))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                
                // Legend with percentages
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(paletteManager.color(at: 3))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accepted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.accepted)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(stats.total > 0 ? Int((Double(stats.accepted) / Double(stats.total)) * 100) : 0)%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(paletteManager.color(at: 4))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.failed)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(stats.total > 0 ? Int((Double(stats.failed) / Double(stats.total)) * 100) : 0)%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Recent Solves Card
struct RecentSolvesCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Recent Solves")
                        .font(.headline)
                }
                Spacer()
                NavigationLink(destination: AllSolvesView(solves: solves)) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            .padding()
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Hero count
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(solves.count)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 0))
                Text("PROBLEMS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Solve list
            VStack(spacing: 0) {
                ForEach(Array(solves.prefix(5).enumerated()), id: \.element.id) { index, solve in
                    SolveRow(solve: solve, paletteManager: paletteManager)
                    if index < min(4, solves.count - 1) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - All Solves View
struct AllSolvesView: View {
    let solves: [Solve]
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var searchText = ""
    @State private var selectedTopic: String? = nil
    
    var availableTopics: [String] {
        let allTopics = solves.compactMap { $0.problem.topic }
        return Array(Set(allTopics)).filter { !$0.isEmpty }.sorted()
    }
    
    var filteredSolves: [Solve] {
        solves.filter { solve in
            let matchesSearch = searchText.isEmpty ||
                solve.problem.title.localizedCaseInsensitiveContains(searchText) ||
                solve.problem.slug.localizedCaseInsensitiveContains(searchText) ||
                (solve.problem.topic ?? "").localizedCaseInsensitiveContains(searchText) ||
                (solve.problem.subtopic ?? "").localizedCaseInsensitiveContains(searchText)
            
            let matchesTopic = selectedTopic == nil || solve.problem.topic == selectedTopic
            
            return matchesSearch && matchesTopic
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search problems, topics, subtopics...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Topic Filter ScrollView
            if !availableTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                selectedTopic = nil
                            }
                        }) {
                            Text("All Topics")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTopic == nil ? paletteManager.selectedPalette.primary : Color.white.opacity(0.1))
                                .foregroundColor(selectedTopic == nil ? .black : .white)
                                .cornerRadius(12)
                        }
                        
                        ForEach(availableTopics, id: \.self) { topic in
                            Button(action: {
                                withAnimation {
                                    if selectedTopic == topic {
                                        selectedTopic = nil
                                    } else {
                                        selectedTopic = topic
                                    }
                                }
                            }) {
                                Text(topic)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTopic == topic ? paletteManager.selectedPalette.primary : Color.white.opacity(0.1))
                                    .foregroundColor(selectedTopic == topic ? .black : .white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            
            // Solves List
            ScrollView {
                if filteredSolves.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No solves match your criteria")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSolves) { solve in
                            SolveRow(solve: solve, paletteManager: paletteManager)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("All Solves")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarScrollMinimization()
    }
}

struct SolveRow: View {
    let solve: Solve
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var isExpanded = false
    
    private var difficultyColor: Color {
        switch solve.problem.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(solve.problem.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 8) {
                            Text(solve.problem.difficulty.capitalized)
                                .font(.caption)
                                .foregroundStyle(difficultyColor)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(solve.problem.platform.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let topic = solve.problem.topic, !topic.isEmpty {
                            HStack(spacing: 6) {
                                Text(topic)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(4)
                                    .foregroundStyle(.secondary)
                                
                                if let subtopic = solve.problem.subtopic, !subtopic.isEmpty {
                                    Text(subtopic)
                                        .font(.system(size: 10, weight: .regular))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(4)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("+\(solve.xpAwarded)")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 1))
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(paletteManager.color(at: 1))
                        }
                        
                        Text(formatDate(solve.solvedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // Language
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(paletteManager.color(at: 0))
                            .font(.caption)
                        Text("Language: \(solve.submission.language.capitalized)")
                            .font(.subheadline)
                    }
                    
                    // Number of tries
                    if let tries = solve.submission.numberOfTries {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(paletteManager.color(at: 1))
                                .font(.caption)
                            Text("Attempts: \(tries)")
                                .font(.subheadline)
                        }
                    }
                    
                    // Time taken
                    if let timeTaken = solve.submission.timeTaken {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(paletteManager.color(at: 2))
                                .font(.caption)
                            Text("Time: \(formatTime(timeTaken))")
                                .font(.subheadline)
                        }
                    }
                    
                    // AI Analysis
                    if let analysis = solve.aiAnalysis ?? solve.submission.aiAnalysis, !analysis.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(paletteManager.color(at: 3))
                                    .font(.caption)
                                Text("AI Analysis")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            MarkdownText(markdown: analysis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Mistake Tags
                    if let tags = solve.mistakeTags ?? solve.submission.mistakeTags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(paletteManager.color(at: 5))
                                    .font(.caption)
                                Text("Mistake Tags")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(paletteManager.color(at: 5).opacity(0.2))
                                            .foregroundStyle(paletteManager.color(at: 5))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // Highlight
                    if let highlight = solve.highlight {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .foregroundStyle(paletteManager.color(at: 4))
                                    .font(.caption)
                                Text("Your Note")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            if !highlight.note.isEmpty {
                                MarkdownText(markdown: highlight.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !highlight.content.isEmpty && highlight.content != highlight.note {
                                Text(highlight.content)
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            
                            if !highlight.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(highlight.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundStyle(.blue)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "via Chrome"
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Performance Metrics Card (NEW - Line Chart)
struct PerformanceMetricsCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var timeData: [(String, Int)] {
        solves.compactMap { solve in
            guard let timeTaken = solve.submission.timeTaken else { return nil }
            return (solve.problem.title, timeTaken)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(paletteManager.color(at: 5))
                Text("Time Performance")
                    .font(.headline)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !timeData.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatTime(averageTime()))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(paletteManager.color(at: 5))
                            Text("Average Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatTime(fastestTime()))
                                .font(.title2)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 6))
                            Text("Fastest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Chart(Array(timeData.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Problem", index),
                            y: .value("Time", item.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [paletteManager.color(at: 5), paletteManager.color(at: 6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Problem", index),
                            y: .value("Time", item.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [paletteManager.color(at: 5).opacity(0.3), paletteManager.color(at: 6).opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        PointMark(
                            x: .value("Problem", index),
                            y: .value("Time", item.1)
                        )
                        .foregroundStyle(paletteManager.color(at: 5))
                        .symbol(Circle())
                    }
                    .frame(height: 120)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            } else {
                Text("No time data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private func averageTime() -> Int {
        let times = timeData.map { $0.1 }
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / times.count
    }
    
    private func fastestTime() -> Int {
        timeData.map { $0.1 }.min() ?? 0
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatTimeShort(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Tries Distribution Card (NEW - Point Chart)
struct TriesDistributionCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var triesData: [(String, Int, String)] {
        solves.compactMap { solve in
            guard let tries = solve.submission.numberOfTries, tries > 0 else { return nil }
            return (solve.problem.title, tries, solve.problem.difficulty)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(paletteManager.color(at: 7))
                Text("Attempts Analysis")
                    .font(.headline)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !triesData.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.1f", averageTries()))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(paletteManager.color(at: 7))
                            Text("Average Tries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(firstTryCount())")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 0))
                            Text("First Try")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Chart(Array(triesData.enumerated()), id: \.offset) { index, item in
                        PointMark(
                            x: .value("Problem", index),
                            y: .value("Tries", item.1)
                        )
                        .foregroundStyle(difficultyColor(item.2))
                        .symbol {
                            Circle()
                                .fill(difficultyColor(item.2))
                                .frame(width: item.1 == 1 ? 12 : 8, height: item.1 == 1 ? 12 : 8)
                        }
                    }
                    .frame(height: 100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    
                    // Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(paletteManager.color(at: 0)).frame(width: 8, height: 8)
                            Text("Easy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(paletteManager.color(at: 1)).frame(width: 8, height: 8)
                            Text("Medium")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(paletteManager.color(at: 2)).frame(width: 8, height: 8)
                            Text("Hard")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No attempts data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private func averageTries() -> Double {
        let tries = triesData.map { Double($0.1) }
        guard !tries.isEmpty else { return 0 }
        return tries.reduce(0, +) / Double(tries.count)
    }
    
    private func firstTryCount() -> Int {
        triesData.filter { $0.1 == 1 }.count
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

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            Text("Error")
                .font(.title2)
                .bold()
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retry) {
                Text("Retry")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var userStats: UserStats?
    @Published var submissionStats: SubmissionStats?
    @Published var solveStats: SolveStats?
    @Published var achievementStats: AchievementStats?
    @Published var recentSolves: [Solve]?
    @Published var todayRevisions: [Revision] = []
    @Published var completedRevisions: [Revision] = []  // Completed revisions for last 7 days
    @Published var frozenDates: Set<String> = []  // YYYY-MM-DD format for reliable comparison
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Load persisted data immediately if available
        if DataManager.shared.hasData {
            self.userStats = DataManager.shared.userStats
            self.submissionStats = DataManager.shared.submissionStats
            self.solveStats = DataManager.shared.solveStats
            self.achievementStats = DataManager.shared.achievementStats
            self.recentSolves = DataManager.shared.recentSolves
            self.todayRevisions = DataManager.shared.todayRevisions
            self.completedRevisions = DataManager.shared.completedRevisions
        }
    }
    
    func loadData(username: String, forceRefresh: Bool = false) async {
        // Use cache if fresh (< 2 hours), otherwise fetch from server
        
        // Always fetch freeze dates first (lightweight, important for display)
        do {
            let freezeDatesResponse = try await NetworkService.shared.getUsedFreezeDates()
            await MainActor.run {
                self.frozenDates = Set(freezeDatesResponse.freezeDates)
            }
        } catch {
            // Silent fail - freeze dates are not critical
        }
        
        // Check if we can use cached data
        if !forceRefresh && DataManager.shared.isCacheFresh {
            await MainActor.run {
                if self.userStats == nil { self.userStats = DataManager.shared.userStats }
                if self.submissionStats == nil { self.submissionStats = DataManager.shared.submissionStats }
                if self.solveStats == nil { self.solveStats = DataManager.shared.solveStats }
                if self.achievementStats == nil { self.achievementStats = DataManager.shared.achievementStats }
                if self.recentSolves == nil { self.recentSolves = DataManager.shared.recentSolves }
                if self.todayRevisions.isEmpty { self.todayRevisions = DataManager.shared.todayRevisions }
                if self.completedRevisions.isEmpty { self.completedRevisions = DataManager.shared.completedRevisions }
                isLoading = false
            }
            // Update widgets with cached data
            if let userStats = self.userStats?.stats {
                updateWidgets(userStats: userStats, recentSolve: self.recentSolves?.first, revisions: self.todayRevisions)
            }
            return
        }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let userStatsTask = NetworkService.shared.getUserStats(username: username)
            async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
            async let solveStatsTask = NetworkService.shared.getSolveStats()
            async let achievementStatsTask = NetworkService.shared.getAchievementStats()
            async let recentSolvesTask = NetworkService.shared.getSolves(limit: 200)
            // Fetch upcoming only - backend filters for incomplete revisions
            // Use revisionMode to fetch ML or normal revisions based on user setting
            let revisionType = DataManager.shared.revisionMode
            async let revisionsTask = NetworkService.shared.getRevisions(upcoming: true, limit: 50, type: revisionType)
            async let completedRevisionsTask = NetworkService.shared.getGroupedRevisions(includeCompleted: true, type: revisionType)

            let (userStats, submissionStats, solveStats, achievementStats, solvesResponse, revisionsResponse, completedRevisionsResponse) = try await (
                userStatsTask,
                submissionStatsTask,
                solveStatsTask,
                achievementStatsTask,
                recentSolvesTask,
                revisionsTask,
                completedRevisionsTask
            )
            
            // Filter for today + overdue only (upcoming includes future dates we don't want)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let todayAndOverdue = revisionsResponse.revisions.filter { revision in
                let revisionDate = calendar.startOfDay(for: revision.scheduledDate)
                return revisionDate <= today
            }

            // Extract completed revisions from last 7 days
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let recentCompletedRevisions = completedRevisionsResponse.groups.flatMap { $0.revisions }
                .filter { revision in
                    guard let completedAtString = revision.completedAt else { return false }
                    var completedDate = formatter.date(from: completedAtString)
                    if completedDate == nil {
                        formatter.formatOptions = [.withInternetDateTime]
                        completedDate = formatter.date(from: completedAtString)
                    }
                    guard let date = completedDate else { return false }
                    return date >= sevenDaysAgo
                }

            // Merge and persist solves inside DataManager, getting the merged array back
            let mergedSolves = DataManager.shared.mergeAndPersistSolves(solvesResponse.solves)

            await MainActor.run {
                self.userStats = userStats
                self.submissionStats = submissionStats
                self.solveStats = solveStats
                self.achievementStats = achievementStats
                self.recentSolves = mergedSolves
                self.todayRevisions = todayAndOverdue
                self.completedRevisions = recentCompletedRevisions
                // frozenDates already set at start of loadData
            }
            
            // Update DataManager cache
            DataManager.shared.userStats = userStats
            DataManager.shared.submissionStats = submissionStats
            DataManager.shared.solveStats = solveStats
            DataManager.shared.achievementStats = achievementStats
            DataManager.shared.todayRevisions = todayAndOverdue
            DataManager.shared.completedRevisions = recentCompletedRevisions
            
            // Update timestamp
            DataManager.shared.lastFetchTimestamp = Date()
            
            // Persist the data
            DataManager.shared.persistData()
            
            // Update widgets - send exactly what we want to display (today + overdue)
            updateWidgets(userStats: userStats.stats, recentSolve: mergedSolves.first, revisions: todayAndOverdue)

            // Check if solved today and end live activity if needed
            DataManager.shared.checkSolvedTodayAndEndActivity()
            
            // Trigger app updates & toast check
            await AchievementToastManager.shared.syncAppOpenUpdates()

        } catch let error where error is CancellationError {
            // Ignore cancellation errors - user likely released pull-to-refresh
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {
        guard let solves = recentSolves else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Create ISO8601 formatter that handles optional fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return solves.contains { solve in
            // Try with fractional seconds first, then without
            var date = formatter.date(from: solve.solvedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: solve.solvedAt)
            }
            
            if let solveDate = date {
                return calendar.isDate(solveDate, inSameDayAs: now)
            }
            return false
        }
    }
    
    private func updateWidgets(userStats: UserStatsData, recentSolve: Solve?, revisions: [Revision]) {
        // Update streak widget
        let solvedToday = hasSolvedToday(recentSolves: self.recentSolves)
        WidgetDataUpdater.shared.updateStreakStatus(
            solvedToday: solvedToday,
            currentStreak: userStats.currentStreak,
            totalXp: userStats.totalXp,
            totalSolves: userStats.totalSolves
        )
        
        // Update all widgets with complete data
        WidgetDataUpdater.shared.updateWidgetData(
            userStats: userStats,
            recentSolve: recentSolve,
            revisions: revisions,
            achievementStats: self.achievementStats?.stats,
            solvedToday: solvedToday
        )
    }
    
    func refreshWidgets() {
        // Refresh widgets with current cached data when app is opened
        guard let userStats = self.userStats?.stats else { return }
        
        // Recalculate solvedToday in case it changed
        let solvedToday = hasSolvedToday(recentSolves: self.recentSolves)
        
        WidgetDataUpdater.shared.updateStreakStatus(
            solvedToday: solvedToday,
            currentStreak: userStats.currentStreak,
            totalXp: userStats.totalXp,
            totalSolves: userStats.totalSolves
        )
        
        WidgetDataUpdater.shared.updateWidgetData(
            userStats: userStats,
            recentSolve: self.recentSolves?.first,
            revisions: self.todayRevisions,
            achievementStats: self.achievementStats?.stats,
            solvedToday: solvedToday
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}

