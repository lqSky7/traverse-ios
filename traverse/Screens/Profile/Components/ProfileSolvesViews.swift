import SwiftUI

struct SolvesListView: View {
    let solves: [UserSolve]
    let canLoadMore: Bool
    let onLoadMore: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if solves.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No solves to display")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(solves.enumerated()), id: \.element.id) { index, solve in
                        ProfileSolveRow(solve: solve)
                        if index < solves.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                if canLoadMore {
                    Button {
                        onLoadMore()
                    } label: {
                        Text("Load More")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
        }
        .padding(.vertical)
    }
}

struct SolveCard: View {
    let solve: UserSolve
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(solve.problem.title)
                    .font(.headline)
                
                Spacer()
                
                DifficultyTag(difficulty: solve.problem.difficulty)
            }
            
            HStack(spacing: 12) {
                Label(solve.problem.platform.capitalized, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(solve.xpAwarded) XP", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(paletteManager.selectedPalette.secondary)
                
                if let submission = solve.submission {
                    Label(submission.language, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            
            Text(formatSolveDate(solve.solvedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .applyProfileCardBackground()
        .cornerRadius(12)
    }
    
    private func formatSolveDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return "Solved on \(displayFormatter.string(from: date))"
    }
}

struct DifficultyTag: View {
    let difficulty: String
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var color: Color {
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 1)
        case "medium": return paletteManager.color(at: 2)
        case "hard": return paletteManager.color(at: 0)
        default: return .gray
        }
    }
    
    var body: some View {
        Text(difficulty.capitalized)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(6)
    }
}

// MARK: - Row Components for List Style
struct ProfileSolveRow: View {
    let solve: UserSolve
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(solve.problem.title)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                DifficultyTag(difficulty: solve.problem.difficulty)
            }
            
            HStack(spacing: 12) {
                Label(solve.problem.platform.capitalized, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(solve.xpAwarded) XP", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(paletteManager.selectedPalette.secondary)
                
                Spacer()
                
                Text(formatSolveDate(solve.solvedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func formatSolveDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }
}

