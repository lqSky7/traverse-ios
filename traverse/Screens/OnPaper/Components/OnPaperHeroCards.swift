import SwiftUI
import Charts

struct StreakHeroCard: View {
    let streak: Int
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var displayNumber: String {
        "\(streak)"
    }
    
    private var daysText: String {
        streak == 1 ? "DAY" : "DAYS"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: streak == 0 ? "flame" : "flame.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(streak == 0 ? .white.opacity(0.5) : .orange)
                
                Spacer()
                
                Text("STREAK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayNumber)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(daysText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            ZStack {
                Color(UIColor.systemGray6)
                if streak > 0 {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.20), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Daily Goal Hero Card (Half Width)
struct DailyGoalHeroCard: View {
    let isComplete: Bool
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isComplete ? .green : paletteManager.selectedPalette.primary)
                
                Spacer()
                
                Text("DAILY GOAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isComplete ? "Completed" : "Incomplete")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isComplete ? .green : .white)
                Text(isComplete ? "Target Met Today" : "Review unit to qualify")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .leading)
        .background(
            ZStack {
                Color(UIColor.systemGray6)
                if isComplete {
                    LinearGradient(
                        colors: [Color.green.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Progress Multi-Metric Card (Inspired by RevisionOverviewCard)
struct OnPaperProgressMetricsCard: View {
    let summary: OnPaperProgressSummary?
    let sessionsCount: Int
    let dueCount: Int
    let mistakes: [OnPaperMistake]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var totalSessions: Int {
        summary?.totalSessions ?? sessionsCount
    }
    
    private var activeMistakes: Int {
        summary?.activeMistakesCount ?? mistakes.filter { $0.status != "resolved" }.count
    }
    
    private var resolvedMistakes: Int {
        summary?.resolvedMistakesCount ?? mistakes.filter { $0.status == "resolved" }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(paletteManager.color(at: 0))
                Text("Curriculum Readiness")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalSessions)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dueCount)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 1))
                    Text("Due Cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(resolvedMistakes)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Resolved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Spaced Revisions Quick Banner
