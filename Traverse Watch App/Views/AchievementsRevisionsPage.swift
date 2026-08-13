//
//  AchievementsRevisionsPage.swift
//  Traverse Watch App
//
//  Page 2: Achievements and Revisions detail view.
//

import SwiftUI

private let cardBackground = Color(white: 0.11)
private let cardRadius: CGFloat = 14

struct AchievementsRevisionsPage: View {
    @ObservedObject var dataManager = WatchDataManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Page indicator
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text("Details")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.top, 4)
                
                // Achievements card (expanded)
                achievementsCard
                
                // Revisions section
                revisionsSection
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Achievements Card
    
    private var achievementsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("\(dataManager.achievementsUnlocked) of \(dataManager.achievementsTotal)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: dataManager.achievementsTotal > 0
                                ? geo.size.width * CGFloat(dataManager.achievementsUnlocked) / CGFloat(dataManager.achievementsTotal)
                                : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            
            // Percentage
            Text("\(Int(Double(dataManager.achievementsUnlocked) / Double(max(dataManager.achievementsTotal, 1)) * 100))% complete")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Revisions Section
    
    private var revisionsSection: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Revisions Due")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(dataManager.revisionsDueCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(dataManager.revisionsDueCount > 0 ? .blue : .secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            if dataManager.revisions.isEmpty {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    
                    Text("All caught up!")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .fill(cardBackground)
                )
            } else {
                // Revision rows
                ForEach(dataManager.revisions.prefix(5)) { revision in
                    revisionRow(revision)
                }
                
                // More indicator
                if dataManager.revisionsDueCount > 5 {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 8))
                        Text("+\(dataManager.revisionsDueCount - 5) more")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                }
            }
        }
    }
    
    // MARK: - Revision Row
    
    private func revisionRow(_ revision: WatchRevisionData) -> some View {
        HStack(spacing: 8) {
            // Difficulty indicator
            Circle()
                .fill(difficultyColor(revision.difficulty))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(revision.problemTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("Rev \(revision.revisionNumber)")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                    
                    if revision.isOverdue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .strokeBorder(
                            revision.isOverdue ? Color.red.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Helpers
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }
}

#Preview {
    AchievementsRevisionsPage()
}
