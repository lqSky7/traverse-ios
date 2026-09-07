import SwiftUI

struct OnPaperProjectCard: View {
    let project: OnPaperProject
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(project.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(project.curriculumStatus.capitalized)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(paletteManager.selectedPalette.primary.opacity(0.2), in: Capsule())
                    .foregroundStyle(paletteManager.selectedPalette.primary)
            }
            
            Text("Project ID: \(project.projectId)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack {
                HStack(spacing: 4) {
                    ForEach(project.primaryLanguages, id: \.self) { lang in
                        Text(lang)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: project.gitAvailable ? "arrow.triangle.branch" : "folder")
                        .font(.caption2)
                    Text(project.gitAvailable ? "Git Synced" : "Standard")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Session Card
struct OnPaperSessionCard: View {
    let session: OnPaperSession
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session \(session.sessionId.prefix(8))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(session.state.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(session.state.contains("complete") ? .green : paletteManager.selectedPalette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (session.state.contains("complete") ? Color.green : paletteManager.selectedPalette.primary).opacity(0.15),
                        in: Capsule()
                    )
            }
            
            if let summary = session.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Text("Started: \(session.startedAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.durationSeconds > 0 {
                    Text("\(session.durationSeconds / 60) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Card Row
struct OnPaperCardRow: View {
    let card: OnPaperFSRSCard
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.prompt ?? card.conceptId ?? card.mistakeId ?? "Concept Card: \(card.cardId.prefix(8))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Text("\(card.reps) reps")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(paletteManager.selectedPalette.primary.opacity(0.12), in: Capsule())
            }
            
            if let userAns = card.userAnswer, !userAns.isEmpty {
                Text("Your answer: \"\(userAns)\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .italic()
            }
            
            HStack(spacing: 8) {
                Text("Due: \(card.dueAt)")
                Text("•")
                Text("Stability: \(String(format: "%.1f", card.stability))d")
                if let concept = card.conceptId {
                    Text("•")
                    Text(concept)
                        .foregroundStyle(paletteManager.color(at: 1))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mistake Card
struct OnPaperMistakeCard: View {
    let mistake: OnPaperMistake
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private var severityColor: Color {
        switch mistake.severity.lowercased() {
        case "critical", "high":
            return .red
        case "medium", "warning":
            return .orange
        default:
            return paletteManager.selectedPalette.primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mistake.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(mistake.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(mistake.status == "resolved" ? .green : severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((mistake.status == "resolved" ? Color.green : severityColor).opacity(0.15), in: Capsule())
            }
            
            HStack(spacing: 6) {
                Text("Category: \(mistake.category.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Severity: \(mistake.severity.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(severityColor)
            }
            
            HStack {
                Text("Occurrences: \(mistake.occurrenceCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Resolved: \(mistake.resolvedCount)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Info Sheet (Matches Traverse AnalyticsInfoSheet 1:1)
