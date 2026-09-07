import SwiftUI
import Charts

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
