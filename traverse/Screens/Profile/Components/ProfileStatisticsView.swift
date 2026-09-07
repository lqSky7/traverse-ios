import SwiftUI

struct StatisticsView: View {
    let statistics: UserStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                StatRow(label: "Total Submissions", value: "\(statistics.totalSubmissions)")
                StatRow(label: "Total Streak Days", value: "\(statistics.totalStreakDays)")
                
                Divider()
                
                Text("Problems by Difficulty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    DifficultyBadge(difficulty: "Easy", count: statistics.problemsByDifficulty.easy, color: .green)
                    DifficultyBadge(difficulty: "Medium", count: statistics.problemsByDifficulty.medium, color: .orange)
                    DifficultyBadge(difficulty: "Hard", count: statistics.problemsByDifficulty.hard, color: .red)
                }
            }
            .padding()
            .applyProfileCardBackground()
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: String
    let count: Int
    let color: Color
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var badgeColor: Color {
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 1)
        case "medium": return paletteManager.color(at: 2)
        case "hard": return paletteManager.color(at: 0)
        default: return color
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .bold()
                .foregroundStyle(badgeColor)
            Text(difficulty)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(8)
    }
}

