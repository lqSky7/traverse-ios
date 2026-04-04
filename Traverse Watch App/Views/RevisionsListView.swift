//
//  RevisionsListView.swift
//  Traverse Watch App
//
//  Today's revision problems — Apple Watch native design.
//

import SwiftUI

private let cardBackground = Color(white: 0.11)
private let cardRadius: CGFloat = 14

struct RevisionsListView: View {
    @ObservedObject var dataManager = WatchDataManager.shared
    
    var body: some View {
        Group {
            if dataManager.revisions.isEmpty {
                emptyState
            } else {
                revisionsList
            }
        }
        .navigationTitle("Revisions")
        .onAppear {
            dataManager.loadData()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.green)
            
            Text("All Clear")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            
            Text("No revisions due today.\nGreat work staying on top of it.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding()
    }
    
    // MARK: - Revisions List
    
    private var revisionsList: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Header
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                    
                    Text("Due Today")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(dataManager.revisionsDueCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
                
                // Revision rows
                ForEach(dataManager.revisions) { revision in
                    revisionRow(revision)
                }
                
                // Overflow indicator
                if dataManager.revisionsDueCount > dataManager.revisions.count {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                        Text("+\(dataManager.revisionsDueCount - dataManager.revisions.count) more on iPhone")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Revision Row
    
    private func revisionRow(_ revision: WatchRevisionData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(revision.problemTitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            HStack(spacing: 6) {
                // Difficulty pill
                Text(revision.difficulty.capitalized)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(difficultyColor(revision.difficulty))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(difficultyColor(revision.difficulty).opacity(0.2))
                    )
                
                // Revision number
                HStack(spacing: 2) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Rev \(revision.revisionNumber)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Platform icon
                Image(systemName: revision.platformIcon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                
                // Overdue indicator
                if revision.isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
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
    NavigationStack {
        RevisionsListView()
    }
}
