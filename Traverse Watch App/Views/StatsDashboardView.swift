//
//  StatsDashboardView.swift
//  Traverse Watch App
//
//  Main stats dashboard — Apple Watch native design.
//

import SwiftUI

// MARK: - Card Background (consistent watchOS-native dark card)

private let cardBackground = Color(white: 0.11)
private let cardRadius: CGFloat = 14

struct StatsDashboardView: View {
    @ObservedObject var dataManager = WatchDataManager.shared
    
    var body: some View {
        Group {
            if dataManager.data == nil && !dataManager.isLoading {
                emptyState
            } else {
                dashboard
            }
        }
        .navigationTitle("Traverse")
        .onAppear {
            dataManager.loadData()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 10)
                
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.blue)
                
                Text("Open Traverse")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                Text("Open the app on your iPhone to sync your coding data.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                
                Button(action: { dataManager.refresh() }) {
                    HStack(spacing: 6) {
                        if dataManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text(dataManager.isLoading ? "Syncing…" : "Retry")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(dataManager.isLoading)
                
                Text(dataManager.syncStatus.displayText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Dashboard
    
    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Streak hero
                streakCard
                
                // XP + Solved row
                HStack(spacing: 6) {
                    miniStatCard(
                        icon: "star.fill",
                        value: formatNumber(dataManager.totalXp),
                        label: "XP",
                        tint: .yellow
                    )
                    miniStatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(dataManager.totalSolves)",
                        label: "Solved",
                        tint: .green
                    )
                }
                
                // Revisions
                revisionsSummaryCard
                
                // Achievements
                achievementsCard
                
                // Recent solve
                if let solve = dataManager.recentSolve {
                    recentSolveCard(solve)
                }
                
                // Sync footer
                syncFooter
            }
            .padding(.horizontal, 0)
        }
        .refreshable {
            dataManager.refresh()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: dataManager.streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 14))
                    .foregroundStyle(dataManager.streak > 0 ? .orange : .secondary)
                
                Text("\(dataManager.streak)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: dataManager.solvedToday ? "checkmark.seal.fill" : "xmark.seal")
                        .font(.system(size: 16))
                        .foregroundStyle(dataManager.solvedToday ? .green : .secondary)
                    
                    Text(dataManager.solvedToday ? "Done" : "Pending")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(dataManager.solvedToday ? .green : .secondary)
                        .textCase(.uppercase)
                }
            }
            
            HStack {
                Text("day streak")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Mini Stat Card
    
    private func miniStatCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Revisions Summary Card
    
    private var revisionsSummaryCard: some View {
        NavigationLink(destination: RevisionsListView()) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(dataManager.revisionsDueCount > 0 ? .blue : .secondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revisions")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("\(dataManager.revisionsDueCount) due today")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Achievements Card
    
    private var achievementsCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievements")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("\(dataManager.achievementsUnlocked)/\(dataManager.achievementsTotal) unlocked")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 3)
                
                Circle()
                    .trim(
                        from: 0,
                        to: dataManager.achievementsTotal > 0
                        ? CGFloat(dataManager.achievementsUnlocked) / CGFloat(dataManager.achievementsTotal)
                        : 0
                    )
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Recent Solve Card
    
    private func recentSolveCard(_ solve: WatchRecentSolveData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.diamond.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                
                Text("Last Solved")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            
            Text(solve.problemTitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            HStack(spacing: 6) {
                Text(solve.difficulty.capitalized)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(difficultyColor(solve.difficulty))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(difficultyColor(solve.difficulty).opacity(0.2))
                    )
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                    Text("+\(solve.xpAwarded)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.yellow)
                
                Spacer()
                
                Text(solve.language.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Sync Footer
    
    private var syncFooter: some View {
        Button(action: { dataManager.refresh() }) {
            HStack(spacing: 4) {
                if dataManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                }
                Text(dataManager.syncStatus.displayText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
    
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
    NavigationStack {
        StatsDashboardView()
    }
}
