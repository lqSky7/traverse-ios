import SwiftUI
import Charts

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
