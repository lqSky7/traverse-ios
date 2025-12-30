import SwiftUI
import Charts
import Combine
import WidgetKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var navigationTitle = "Welcome back,"
    @State private var titleIndex = 0
    @State private var titleOpacity: Double = 1.0
    @State private var titleBlur: CGFloat = 0
    
    private let titles = [
        "Welcome back,",
        "Ready to code?",
        "Let's solve some problems!",
        "Keep pushing forward!",
        "You're doing great!",
        "Time to level up!",
        "Code like a boss!",
        "One problem at a time!",
        "Stay curious, keep coding!",
        "Your journey continues..."
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error, retry: {
                            Task {
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "", forceRefresh: true)
                            }
                        })
                    } else {
                        // Streak Card
                        if let userStats = viewModel.userStats {
                            StreakCard(streak: userStats.stats.currentStreak, solvedToday: hasSolvedToday(recentSolves: viewModel.recentSolves), paletteManager: paletteManager)
                        }
                        
                        // Main Stats Cards
                        if let solveStats = viewModel.solveStats {
                            MainStatsCard(stats: solveStats.stats, paletteManager: paletteManager)
                        }
                        
                        // Charts Section
                        VStack(spacing: 16) {
                            if let achievementStats = viewModel.achievementStats {
                                AchievementStatsCard(stats: achievementStats.stats, paletteManager: paletteManager)
                            }
                            
                            if let solveStats = viewModel.solveStats {
                                HStack(spacing: 16) {
                                    DifficultyChartCard(stats: solveStats.stats, paletteManager: paletteManager)
                                    PlatformChartCard(stats: solveStats.stats, paletteManager: paletteManager)
                                }
                            }
                            
                            if let submissionStats = viewModel.submissionStats {
                                SubmissionStatsCard(stats: submissionStats.stats)
                            }
                            
                            // New Charts
                            if let solveStats = viewModel.solveStats {
                                DifficultyPieChartCard(stats: solveStats.stats, paletteManager: paletteManager)
                            }
                            
                            if let submissionStats = viewModel.submissionStats {
                                SubmissionBreakdownCard(stats: submissionStats.stats, paletteManager: paletteManager)
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                RecentSolvesCard(solves: solves, paletteManager: paletteManager)
                                
                                // New Performance Charts
                                PerformanceMetricsCard(solves: solves, paletteManager: paletteManager)
                                
                                TriesDistributionCard(solves: solves, paletteManager: paletteManager)
                            }
                            
                            // Intelligence Summary Card (iOS 18.2+)
                            if #available(iOS 18.2, *) {
                                if let userStats = viewModel.userStats,
                                   let recentSolves = viewModel.recentSolves,
                                   let solveStats = viewModel.solveStats {
                                    IntelligenceSummaryCard(
                                        streak: userStats.stats.currentStreak,
                                        solvedToday: hasSolvedToday(recentSolves: viewModel.recentSolves),
                                        totalSolves: userStats.stats.totalSolves,
                                        recentSolves: recentSolves,
                                        difficulty: solveStats.stats.byDifficulty,
                                        paletteManager: paletteManager
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)
                        .blur(radius: titleBlur)
                }
            }
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
                Task {
                    // Always load to update widgets, even if data is cached
                    await viewModel.loadData(username: username)
                }
            }
            
            // Start title animation cycle
            startTitleAnimation()
        }
        .onChange(of: authViewModel.currentUser?.username) { oldUsername, newUsername in
            if let username = newUsername, viewModel.solveStats == nil {
                Task {
                    await viewModel.loadData(username: username)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func hasSolvedToday(recentSolves: [Solve]?) -> Bool {
        guard let solves = recentSolves else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return solves.contains { solve in
            // Parse the solvedAt date string
            let formatter = ISO8601DateFormatter()
            guard let solveDate = formatter.date(from: solve.solvedAt) else { return false }
            let solveDay = calendar.startOfDay(for: solveDate)
            return solveDay == today
        }
    }
    
    private func startTitleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { _ in
            // Fade out and blur
            withAnimation(.easeIn(duration: 0.5)) {
                titleOpacity = 0
                titleBlur = 10
            }
            
            // Change title in the middle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                titleIndex = (titleIndex + 1) % titles.count
                navigationTitle = titles[titleIndex]
                
                // Fade in and remove blur
                withAnimation(.easeOut(duration: 0.5)) {
                    titleOpacity = 1.0
                    titleBlur = 0
                }
            }
        }
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    let streak: Int
    let solvedToday: Bool
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var gradientOffset: CGFloat = -1
    
    private var gradientColors: [Color] {
        paletteManager.streakGradientColors(for: streak)
    }
    
    private var displayNumber: String {
        streak == 0 ? "0" : "\(streak)"
    }
    
    private var streakMessage: String {
        if solvedToday {
            return "Well done! Keep it up!"
        } else if streak == 0 {
            return "Start your streak!"
        } else {
            return "Get back to work!"
        }
    }
    
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: streak == 0 ? "flame" : "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayNumber)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(streakMessage)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            if streak > 0 {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            AnimatedGradient(colors: gradientColors, offset: gradientOffset)
                .overlay(.ultraThinMaterial.opacity(0.2))
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                gradientOffset = 1
            }
        }
    }
}

// MARK: - Animated Gradient View
struct AnimatedGradient: View {
    let colors: [Color]
    let offset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: 0.5 + offset * 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5 - offset * 0.5, y: 1)
            )
        }
    }
}


// MARK: - Main Stats Card
struct MainStatsCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Progress")
                    .font(.headline)
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
        .background(.ultraThinMaterial)
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Difficulty Chart Card
struct DifficultyChartCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var chartData: [(String, Int, Color)] {
        [
            ("Easy", stats.byDifficulty.easy, paletteManager.color(at: 0)),
            ("Medium", stats.byDifficulty.medium, paletteManager.color(at: 1)),
            ("Hard", stats.byDifficulty.hard, paletteManager.color(at: 2))
        ]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Difficulty")
                .font(.headline)
                .foregroundStyle(.white)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Chart(chartData, id: \.0) { item in
                BarMark(
                    x: .value("Difficulty", item.0),
                    y: .value("Count", item.1)
                )
                .foregroundStyle(item.2.gradient)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text("\(item.1)")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(item.2)
                }
            }
            .frame(height: 140)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
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
    
    private var totalPlatforms: Int {
        chartData.reduce(0) { $0 + $1.1 }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Platforms")
                .font(.headline)
                .foregroundStyle(.white)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !chartData.isEmpty {
                ZStack {
                    ForEach(Array(chartData.enumerated()), id: \.element.0) { index, _ in
                        let ringSize = 120 - (CGFloat(index) * 20)
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: ringSize, height: ringSize)
                    }
                    
                    ForEach(Array(chartData.enumerated()), id: \.element.0) { index, item in
                        let percentage = Double(item.1) / Double(totalPlatforms)
                        let ringSize = 120 - (CGFloat(index) * 20)
                        
                        Circle()
                            .trim(from: 0, to: percentage)
                            .stroke(
                                platformColor(for: item.0),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(chartData.count)")
                            .font(.title3)
                            .bold()
                        Text("Platforms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 140)
                
                VStack(spacing: 6) {
                    ForEach(Array(chartData.prefix(3)), id: \.0) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(platformColor(for: item.0))
                                .frame(width: 8, height: 8)
                            Text("\(item.0): \(item.1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No platform data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 140)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private func platformColor(for platform: String) -> Color {
        let colors = paletteManager.selectedPalette.chartColors
        let hash = platform.hashValue
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Achievement Stats Card
struct AchievementStatsCard: View {
    let stats: AchievementStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AllAchievementsView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(stats.unlocked) / CGFloat(max(stats.total, 1)))
                        .stroke(
                            LinearGradient(
                                colors: [paletteManager.color(at: 3), paletteManager.color(at: 4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(stats.unlocked)")
                            .font(.title)
                            .bold()
                        Text("of \(stats.total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Vertical divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(stats.percentage)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 3))
                        Text("Complete")
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(stats.byCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                            HStack {
                                Image(systemName: getCategoryIcon(category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(category.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .bold()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "solve": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "submission": return "arrow.up.doc.fill"
        default: return "sparkles"
        }
    }
}

// MARK: - All Achievements View
struct AllAchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var expandedCategories: Set<String> = []
    @State private var gradientPhase: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background gradient
            MeshGradientBackground(paletteManager: paletteManager, phase: gradientPhase)
                .ignoresSafeArea()
            
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
                    } else if let achievements = viewModel.achievements {
                        // Spacer for sticky card
                        Color.clear
                            .frame(height: 130)
                        
                        // Categories with expandable achievements
                        CategoriesSection(achievements: achievements, expandedCategories: $expandedCategories, paletteManager: paletteManager)
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
        .onAppear {
            if viewModel.achievements == nil {
                Task {
                    await viewModel.loadAchievements()
                }
            }
            // Start gradient animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                gradientPhase = 1
            }
        }
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
    @Binding var expandedCategories: Set<String>
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
                    isExpanded: expandedCategories.contains(category),
                    paletteManager: paletteManager,
                    onToggle: {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Achievement Category Card
struct AchievementCategoryCard: View {
    let category: String
    let achievements: [AchievementDetail]
    let isExpanded: Bool
    @ObservedObject var paletteManager: ColorPaletteManager
    let onToggle: () -> Void
    
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }
    
    private var categoryIcon: String {
        switch category.lowercased() {
        case "solve": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        default: return "sparkles"
        }
    }
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case "solve": return paletteManager.color(at: 0)
        case "streak": return paletteManager.color(at: 1)
        case "social": return paletteManager.color(at: 2)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            Button(action: onToggle) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: categoryIcon)
                            .font(.title2)
                            .foregroundStyle(categoryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.capitalized)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(unlockedCount) of \(achievements.count) unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable Achievements List
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                    
                    ForEach(achievements.sorted(by: { $0.unlocked && !$1.unlocked }), id: \.id) { achievement in
                        AchievementRow(achievement: achievement, paletteManager: paletteManager)
                        
                        if achievement.id != achievements.last?.id {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Achievement Row
struct AchievementRow: View {
    let achievement: AchievementDetail
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(achievement.unlocked ? paletteManager.color(at: 3).opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if achievement.unlocked {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .foregroundStyle(paletteManager.color(at: 3))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(achievement.unlocked ? .white : .gray)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if achievement.unlocked, let unlockedAt = achievement.unlockedAt {
                    Text("Unlocked \(formatDate(unlockedAt))")
                        .font(.caption2)
                        .foregroundStyle(paletteManager.color(at: 3))
                }
            }
            
            Spacer()
            
            if let icon = achievement.icon {
                Text(icon)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .opacity(achievement.unlocked ? 1.0 : 0.6)
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Difficulty Pie Chart Card (NEW)
struct DifficultyPieChartCard: View {
    let stats: SolveStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var chartData: [(String, Int, Color)] {
        [
            ("Easy", stats.byDifficulty.easy, paletteManager.color(at: 0)),
            ("Medium", stats.byDifficulty.medium, paletteManager.color(at: 1)),
            ("Hard", stats.byDifficulty.hard, paletteManager.color(at: 2))
        ].filter { $0.1 > 0 }
    }
    
    private var total: Int {
        stats.byDifficulty.easy + stats.byDifficulty.medium + stats.byDifficulty.hard
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Problem Distribution")
                .font(.headline)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if !chartData.isEmpty {
                HStack(spacing: 30) {
                    Chart(chartData, id: \.0) { item in
                        SectorMark(
                            angle: .value("Count", item.1),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(item.2.gradient)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(total)")
                                .font(.title2)
                                .bold()
                            Text("Problems")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(chartData, id: \.0) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.2)
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(item.1) (\(Int((Double(item.1) / Double(total)) * 100))%)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } else {
                Text("No difficulty data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
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
                        x: .value("Count", stats.accepted)
                    )
                    .foregroundStyle(paletteManager.color(at: 3).gradient)
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Count", stats.failed),
                        stacking: .standard
                    )
                    .foregroundStyle(paletteManager.color(at: 4).gradient)
                    .cornerRadius(6)
                }
                .frame(height: 60)
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Recent Solves Card
struct RecentSolvesCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Solves")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AllSolvesView(solves: solves)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                ForEach(solves.prefix(5)) { solve in
                    SolveRow(solve: solve, paletteManager: paletteManager)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - All Solves View
struct AllSolvesView: View {
    let solves: [Solve]
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(solves) { solve in
                    SolveRow(solve: solve, paletteManager: paletteManager)
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("All Solves")
        .navigationBarTitleDisplayMode(.large)
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
                            .lineLimit(1)
                        
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
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // Language
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Language: \(solve.submission.language.capitalized)")
                            .font(.subheadline)
                    }
                    
                    // Number of tries
                    if let tries = solve.submission.numberOfTries {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.purple)
                                .font(.caption)
                            Text("Attempts: \(tries)")
                                .font(.subheadline)
                        }
                    }
                    
                    // Time taken
                    if let timeTaken = solve.submission.timeTaken {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.blue)
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
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("AI Analysis")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text(analysis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Highlight
                    if let highlight = solve.highlight {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Your Note")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text(highlight.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
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
        .background(.ultraThinMaterial)
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Average Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTime(averageTime()))
                                .font(.title3)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 5))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Fastest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTime(fastestTime()))
                                .font(.title3)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 6))
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
                    .frame(height: 160)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel {
                                if let seconds = value.as(Int.self) {
                                    Text(formatTimeShort(seconds))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No time data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Average Tries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", averageTries()))
                                .font(.title3)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 7))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Best (1st try)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(firstTryCount())")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 0))
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
                        
                        if item.1 > 3 {
                            RuleMark(y: .value("Tries", item.1))
                                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(difficultyColor(item.2).opacity(0.3))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
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
        .background(.ultraThinMaterial)
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
        }
    }
    
    func loadData(username: String, forceRefresh: Bool = false) async {
        // Always fetch fresh data for widgets - don't use cache for initial load
        // Cache is only used within the same app session after first load
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let userStatsTask = NetworkService.shared.getUserStats(username: username)
            async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
            async let solveStatsTask = NetworkService.shared.getSolveStats()
            async let achievementStatsTask = NetworkService.shared.getAchievementStats()
            async let recentSolvesTask = NetworkService.shared.getSolves(limit: 10)
            // Fetch upcoming only - backend filters for incomplete revisions
            async let revisionsTask = NetworkService.shared.getRevisions(upcoming: true, limit: 50)
            
            let (userStats, submissionStats, solveStats, achievementStats, solvesResponse, revisionsResponse) = try await (
                userStatsTask,
                submissionStatsTask,
                solveStatsTask,
                achievementStatsTask,
                recentSolvesTask,
                revisionsTask
            )
            
            // Filter for today + overdue only (upcoming includes future dates we don't want)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            let todayAndOverdue = revisionsResponse.revisions.filter { revision in
                let revisionDate = calendar.startOfDay(for: revision.scheduledDate)
                return revisionDate <= today
            }
            
            print("🔥 WIDGET UPDATE: Passing \(todayAndOverdue.count) revisions to widget")
            
            await MainActor.run {
                self.userStats = userStats
                self.submissionStats = submissionStats
                self.solveStats = solveStats
                self.achievementStats = achievementStats
                self.recentSolves = solvesResponse.solves
                self.todayRevisions = todayAndOverdue
            }
            
            // Update DataManager cache
            DataManager.shared.userStats = userStats
            DataManager.shared.submissionStats = submissionStats
            DataManager.shared.solveStats = solveStats
            DataManager.shared.achievementStats = achievementStats
            DataManager.shared.recentSolves = solvesResponse.solves
            
            // Persist the data
            DataManager.shared.persistData()
            
            // Update widgets - send exactly what we want to display (today + overdue)
            updateWidgets(userStats: userStats.stats, recentSolve: solvesResponse.solves.first, revisions: todayAndOverdue)
            
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
        let today = calendar.startOfDay(for: Date())
        
        return solves.contains { solve in
            let formatter = ISO8601DateFormatter()
            guard let solveDate = formatter.date(from: solve.solvedAt) else { return false }
            let solveDay = calendar.startOfDay(for: solveDate)
            return solveDay == today
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
            revisions: revisions
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
            revisions: self.todayRevisions
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
