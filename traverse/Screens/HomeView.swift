import SwiftUI
import Charts
import Combine

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    
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
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "")
                            }
                        })
                    } else {
                        // Header Section
                        HeaderSection(user: authViewModel.currentUser) {
                            Task {
                                await viewModel.loadData(username: authViewModel.currentUser?.username ?? "")
                            }
                        }
                        
                        // Streak Card
                        if let solveStats = viewModel.solveStats {
                            StreakCard(streak: solveStats.stats.totalStreakDays)
                        }
                        
                        // Main Stats Cards
                        if let solveStats = viewModel.solveStats {
                            MainStatsCard(stats: solveStats.stats)
                        }
                        
                        // Charts Section
                        VStack(spacing: 16) {
                            if let achievementStats = viewModel.achievementStats {
                                AchievementStatsCard(stats: achievementStats.stats)
                            }
                            
                            if let solveStats = viewModel.solveStats {
                                HStack(spacing: 16) {
                                    DifficultyChartCard(stats: solveStats.stats)
                                    PlatformChartCard(stats: solveStats.stats)
                                }
                            }
                            
                            if let submissionStats = viewModel.submissionStats {
                                SubmissionStatsCard(stats: submissionStats.stats)
                            }
                            
                            // New Charts
                            if let solveStats = viewModel.solveStats {
                                DifficultyPieChartCard(stats: solveStats.stats)
                            }
                            
                            if let submissionStats = viewModel.submissionStats {
                                SubmissionBreakdownCard(stats: submissionStats.stats)
                            }
                            
                            if let solves = viewModel.recentSolves, !solves.isEmpty {
                                RecentSolvesCard(solves: solves)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Home")
        }
        .onAppear {
            if viewModel.solveStats == nil, let username = authViewModel.currentUser?.username {
                Task {
                    await viewModel.loadData(username: username)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    let user: User?
    let onRefresh: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(user?.username ?? "User")
                    .font(.title)
                    .bold()
            }
            Spacer()
            
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    let streak: Int
    
    private var gradientColors: [Color] {
        if streak == 0 {
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
        
        // Define the color progression milestones
        let colorStops: [(day: Int, color: Color)] = [
            (1, .gray),
            (25, .orange),
            (60, .yellow),
            (100, .red)
        ]
        
        // Find which two color stops we're between
        var startStop = colorStops[0]
        var endStop = colorStops[1]
        
        for i in 0..<colorStops.count - 1 {
            if streak >= colorStops[i].day && streak <= colorStops[i + 1].day {
                startStop = colorStops[i]
                endStop = colorStops[i + 1]
                break
            }
        }
        
        // If streak is beyond the last milestone, use the last color
        if streak > colorStops.last!.day {
            return [.red, .red.opacity(0.8), .orange]
        }
        
        // Calculate progress between the two stops (0.0 to 1.0)
        let dayRange = endStop.day - startStop.day
        let progress = Double(streak - startStop.day) / Double(dayRange)
        
        // Interpolate the colors
        let startColor = startStop.color
        let endColor = endStop.color
        let interpolatedColor = lerpColor(from: startColor, to: endColor, progress: progress)
        
        // Create gradient with interpolated colors
        return [startColor, interpolatedColor, endColor]
    }
    
    // Linear interpolation between two colors
    private func lerpColor(from startColor: Color, to endColor: Color, progress: Double) -> Color {
        let clampedProgress = max(0, min(1, progress))
        
        let start = UIColor(startColor)
        let end = UIColor(endColor)
        
        var startRed: CGFloat = 0, startGreen: CGFloat = 0, startBlue: CGFloat = 0, startAlpha: CGFloat = 0
        var endRed: CGFloat = 0, endGreen: CGFloat = 0, endBlue: CGFloat = 0, endAlpha: CGFloat = 0
        
        start.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)
        end.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)
        
        // Lerp each color component
        let red = startRed + (endRed - startRed) * clampedProgress
        let green = startGreen + (endGreen - startGreen) * clampedProgress
        let blue = startBlue + (endBlue - startBlue) * clampedProgress
        let alpha = startAlpha + (endAlpha - startAlpha) * clampedProgress
        
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    private var displayNumber: String {
        streak == 0 ? "0" : "\(streak)"
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
                Text(streak == 0 ? "Start your streak!" : "\(streak) day streak")
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
            LinearGradient(
                colors: gradientColors,
                startPoint: .leading,
                endPoint: .trailing
            )
            .overlay(.ultraThinMaterial.opacity(0.2))
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}


// MARK: - Main Stats Card
struct MainStatsCard: View {
    let stats: SolveStatsData
    
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
                    color: .green
                )
                
                Divider()
                    .frame(height: 60)
                
                StatItem(
                    title: "Total XP",
                    value: "\(stats.totalXp)",
                    icon: "sparkles",
                    color: .yellow
                )
                
                Divider()
                    .frame(height: 60)
                
                StatItem(
                    title: "Streak",
                    value: "\(stats.totalStreakDays)",
                    icon: "flame.fill",
                    color: .orange
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
    
    private var chartData: [(String, Int, Color)] {
        [
            ("Easy", stats.byDifficulty.easy, .green),
            ("Medium", stats.byDifficulty.medium, .orange),
            ("Hard", stats.byDifficulty.hard, .red)
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
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .cyan]
        let hash = platform.hashValue
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Achievement Stats Card
struct AchievementStatsCard: View {
    let stats: AchievementStatsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AllAchievementsView(stats: stats)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
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
                                colors: [.yellow, .orange],
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
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(stats.percentage)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.yellow)
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
    let stats: AchievementStatsData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stats.unlocked)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.yellow)
                            Text("Achievements Unlocked")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Divider()
                    
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("\(stats.total)")
                                .font(.title)
                                .bold()
                            Text("Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text(stats.percentage)
                                .font(.title)
                                .bold()
                                .foregroundStyle(.yellow)
                            Text("Progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(stats.total - stats.unlocked)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.gray)
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                // Category Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("By Category")
                        .font(.headline)
                    
                    ForEach(stats.byCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                        HStack {
                            Image(systemName: getCategoryIcon(category))
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.capitalized)
                                    .font(.headline)
                                Text("\(count) achievements")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("All Achievements")
        .navigationBarTitleDisplayMode(.large)
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

// MARK: - Submission Stats Card
struct SubmissionStatsCard: View {
    let stats: SubmissionStatsData
    
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
                        .foregroundStyle(.green)
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
                        .foregroundStyle(.red)
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
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("%")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.blue)
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
    
    private var chartData: [(String, Int, Color)] {
        [
            ("Easy", stats.byDifficulty.easy, .green),
            ("Medium", stats.byDifficulty.medium, .orange),
            ("Hard", stats.byDifficulty.hard, .red)
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
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Count", stats.failed),
                        stacking: .standard
                    )
                    .foregroundStyle(Color.red.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 60)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                
                // Legend with percentages
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accepted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.accepted)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(Int((Double(stats.accepted) / Double(stats.total)) * 100))%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.failed)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(Int((Double(stats.failed) / Double(stats.total)) * 100))%)")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Solves")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AllSolvesView(solves: solves)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                ForEach(solves.prefix(5)) { solve in
                    SolveRow(solve: solve)
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(solves) { solve in
                    SolveRow(solve: solve)
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
    
    private var difficultyColor: Color {
        switch solve.problem.difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }
    
    var body: some View {
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
                    
                    Text(solve.submission.language.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
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
                        .foregroundStyle(.yellow)
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                
                Text(formatDate(solve.solvedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadData(username: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let userStatsTask = NetworkService.shared.getUserStats(username: username)
            async let submissionStatsTask = NetworkService.shared.getSubmissionStats()
            async let solveStatsTask = NetworkService.shared.getSolveStats()
            async let achievementStatsTask = NetworkService.shared.getAchievementStats()
            async let recentSolvesTask = NetworkService.shared.getSolves(limit: 10)
            
            let (userStats, submissionStats, solveStats, achievementStats, solvesResponse) = try await (
                userStatsTask,
                submissionStatsTask,
                solveStatsTask,
                achievementStatsTask,
                recentSolvesTask
            )
            
            self.userStats = userStats
            self.submissionStats = submissionStats
            self.solveStats = solveStats
            self.achievementStats = achievementStats
            self.recentSolves = solvesResponse.solves
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
