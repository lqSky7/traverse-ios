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
