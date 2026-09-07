import SwiftUI

struct RevisionGroupCard: View {
    let group: RevisionGroup
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onOpenCoach: (Revision) -> Void
    let onDelete: (Revision) async -> Void
    let onReschedule: (Revision, Int) async -> Void
    let onDeleteProblem: (Revision) async -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header - OUTSIDE the card as section header
            HStack(spacing: 8) {
                Image(systemName: dateIcon)
                    .foregroundStyle(dateColor)
                    .font(.caption)
                Text(formattedDate.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(group.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(dateColor)
            }
            .padding(.horizontal, 4)
            
            // Card with revisions
            VStack(spacing: 0) {
                ForEach(Array(group.revisions.enumerated()), id: \.element.id) { index, revision in
                    RevisionCard(
                         revision: revision,
                         useMLMode: useMLMode,
                         onComplete: onComplete,
                         onOpenCoach: onOpenCoach,
                         onDelete: onDelete,
                         onReschedule: onReschedule,
                         onDeleteProblem: onDeleteProblem
                    )
                    
                    // Add inset divider between items (not after last)
                    if index < group.revisions.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: group.displayDate)
    }
    
    private var dateIcon: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.displayDate) {
            return "calendar.badge.clock"
        } else if calendar.isDateInTomorrow(group.displayDate) {
            return "calendar.badge.plus"
        } else {
            return "calendar"
        }
    }
    
    private var dateColor: Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.displayDate) {
            return paletteManager.color(at: 2)
        } else {
            return paletteManager.color(at: 4)
        }
    }
}

struct RevisionCard: View {
    let revision: Revision
    let useMLMode: Bool
    let onComplete: (Revision) async -> Void
    let onOpenCoach: (Revision) -> Void
    let onDelete: (Revision) async -> Void
    let onReschedule: (Revision, Int) async -> Void
    let onDeleteProblem: (Revision) async -> Void
    @State private var isCompleting = false
    @State private var isDeleting = false
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    private var difficultyColor: Color {
        switch revision.problem.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(difficultyColor)
                .frame(width: 4)
                .cornerRadius(4)
            
            Button(action: { onOpenCoach(revision) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(revision.problem.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(revision.problem.platform.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("Revision #\(revision.revisionNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // AI Coach Button
            Button(action: { onOpenCoach(revision) }) {
                Image(systemName: "sparkles")
                    .foregroundStyle(paletteManager.color(at: 3))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(6)
                    .background(paletteManager.color(at: 3).opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            if !useMLMode {
                if revision.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(paletteManager.color(at: 1))
                        .font(.title2)
                } else {
                    Button(action: {
                        Task {
                            isCompleting = true
                            await onComplete(revision)
                            isCompleting = false
                        }
                    }) {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .font(.title2)
                        }
                    }
                    .disabled(isCompleting)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .opacity(revision.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            Button {
                onOpenCoach(revision)
            } label: {
                Label("AI Revision Coach & Hints", systemImage: "sparkles")
            }
            if !revision.isCompleted {
                Button {
                    Task {
                        await onReschedule(revision, 7)
                    }
                } label: {
                    Label("Reschedule 7 Days Later", systemImage: "calendar.badge.plus")
                }
                
                Button {
                    Task {
                        await onReschedule(revision, 14)
                    }
                } label: {
                    Label("Reschedule 14 Days Later", systemImage: "calendar.badge.plus")
                }
                
                Button(role: .destructive) {
                    Task {
                        await onDeleteProblem(revision)
                    }
                } label: {
                    Label("Remove from Revision List", systemImage: "trash")
                }
                
                if useMLMode {
                    Divider()
                    Button(role: .destructive) {
                        Task {
                            isDeleting = true
                            await onDelete(revision)
                            isDeleting = false
                        }
                    } label: {
                        Label("Delete Single ML Revision", systemImage: "minus.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Stat Badge for Floating Toolbar
struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Daily Review Limit Card
