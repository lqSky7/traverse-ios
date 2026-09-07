import SwiftUI

struct ProfileAchievementRow: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 24))
                .foregroundStyle(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.body)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct AchievementsListView: View {
    let achievements: [Achievement]
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if achievements.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(paletteManager.color(at: 1).opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "trophy")
                            .font(.system(size: 36))
                            .foregroundStyle(paletteManager.color(at: 1))
                    }
                    Text("No achievements unlocked yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Complete challenges to earn achievements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 2-column grid of achievement cards
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(achievements) { achievement in
                        AchievementBadgeCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
                
                // Summary text
                Text("\(achievements.count) achievement\(achievements.count == 1 ? "" : "s") unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Achievement Badge Card (Card Style for Vertical Grid)
struct AchievementBadgeCard: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var glowPhase: CGFloat = 0
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve", "solves": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        case "revision", "revisions", "ml": return "brain.head.profile"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve", "solves": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        case "revision", "revisions", "ml": return paletteManager.color(at: 4)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var glowOpacity: Double {
        0.3 + 0.2 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Clean Achievement Badge Icon (no blur or glow)
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.18))
                    .frame(width: 64, height: 64)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }
            
            // Achievement Name
            Text(achievement.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Description
            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Unlocked date
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(formatDate(achievement.unlockedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.1), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var categoryIcon: String {
        switch achievement.category.lowercased() {
        case "solve": return "checkmark.circle.fill"
        case "streak": return "flame.fill"
        case "social": return "person.2.fill"
        default: return "trophy.fill"
        }
    }
    
    var categoryColor: Color {
        switch achievement.category.lowercased() {
        case "solve": return paletteManager.color(at: 1)
        case "streak": return paletteManager.color(at: 0)
        case "social": return paletteManager.color(at: 2)
        default: return paletteManager.color(at: 3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 32))
                .foregroundStyle(categoryColor)
                .frame(width: 50, height: 50)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Unlocked \(formatDate(achievement.unlockedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .applyProfileCardBackground()
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - View Extension for Glass Button Styles
