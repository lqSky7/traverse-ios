import SwiftUI
import Charts

struct SubmissionStatsCard: View {
    let stats: SubmissionStatsData
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submission Statistics")
                .font(.headline)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(stats.total)")
                        .font(.title2)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("\(stats.accepted)")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Accepted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("\(stats.failed)")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(paletteManager.color(at: 4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(String(format: "%.0f", Double(stats.acceptanceRate.replacingOccurrences(of: "%", with: "")) ?? 0))
                            .font(.title2)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("%")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(paletteManager.color(at: 8))
                    }
                    Text("Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Solve Heatmap Card
struct SolveHeatmapCard: View {
    let solves: [Solve]
    let frozenDates: Set<String>  // YYYY-MM-DD format
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(solves: [Solve], frozenDates: Set<String> = [], paletteManager: ColorPaletteManager) {
        self.solves = solves
        self.frozenDates = frozenDates
        self.paletteManager = paletteManager
    }
    
    /// How many weeks of history the card shows. It used to be 7, which was
    /// sized to a half-width card. The Difficulty card that shared that row is
    /// gone, so the heatmap is full width now — 14 weeks of adaptive cells fills
    /// the row without making the card taller than it was.
    private static let weeksToShow = 14

    /// Process solves into date -> difficulty data.
    ///
    /// Bucketed on `activityAt`, not `solvedAt`: a day you spent revising is a
    /// day you worked, and `solvedAt` never moves off the first acceptance.
    private var heatmapData: [Date: String] {
        var data: [Date: String] = [:]

        for solve in solves {
            guard let date = ActivityTimestamp.date(from: solve.activityAt) else { continue }
            let day = Calendar.current.startOfDay(for: date)
            // Keep the hardest difficulty for each day
            if let existing = data[day] {
                data[day] = harderDifficulty(existing, solve.problem.difficulty)
            } else {
                data[day] = solve.problem.difficulty
            }
        }
        return data
    }
    
    private func harderDifficulty(_ a: String, _ b: String) -> String {
        let order = ["easy": 0, "medium": 1, "hard": 2]
        let aVal = order[a.lowercased()] ?? 0
        let bVal = order[b.lowercased()] ?? 0
        return aVal >= bVal ? a : b
    }
    
    private var weekDates: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var weeks: [[Date]] = []
        
        for weekOffset in (0..<Self.weeksToShow).reversed() {
            var week: [Date] = []
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                    week.append(day)
                }
            }
            weeks.append(week)
        }
        return weeks
    }
    
    private func colorForDate(_ date: Date) -> Color {
        // Check if this date was frozen (ice blue color)
        let dateString = Self.dateFormatter.string(from: date)
        if frozenDates.contains(dateString) {
            return Color(red: 0.31, green: 0.76, blue: 0.97) // Ice blue #4FC3F7
        }
        
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard let difficulty = heatmapData[normalizedDate] else {
            return Color.gray.opacity(0.15)
        }
        switch difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private var totalSolvedDays: Int {
        heatmapData.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.caption)
                        .foregroundStyle(paletteManager.color(at: 3))
                    Text("Activity")
                        .font(.headline)
                }
                Spacer()
                Text("\(totalSolvedDays)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 3))
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, -16)
            
            // Heatmap grid. Cells are sized from whichever of width or height
            // is the tighter constraint, so the grid always fills the card
            // exactly — no fixed 16pt cells leaving a strip of dead space in
            // the middle of a full-width card.
            GeometryReader { geometry in
                let spacing: CGFloat = 3
                let columns = CGFloat(max(weekDates.count, 1))
                let widthCell = (geometry.size.width - spacing * (columns - 1)) / columns
                let heightCell = (geometry.size.height - spacing * 6) / 7
                let cell = max(min(widthCell, heightCell), 4)
                let corner = max(cell * 0.22, 2)
                
                HStack(spacing: spacing) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: spacing) {
                            ForEach(week, id: \.self) { date in
                                RoundedRectangle(cornerRadius: corner)
                                    .fill(colorForDate(date))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 156)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            // Compact legend - dots only, centered
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    Circle().fill(paletteManager.color(at: 0)).frame(width: 8, height: 8)
                    Circle().fill(paletteManager.color(at: 1)).frame(width: 8, height: 8)
                    Circle().fill(paletteManager.color(at: 2)).frame(width: 8, height: 8)
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Activity Detail View (Full Screen Heatmap)

struct SubmissionBreakdownCard: View {
    let stats: SubmissionStatsData
    @ObservedObject var paletteManager: ColorPaletteManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submission Breakdown")
                .font(.headline)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 20) {
                // Stacked Bar Chart
                Chart {
                    BarMark(
                        x: .value("Count", max(stats.accepted, 1))
                    )
                    .foregroundStyle(paletteManager.color(at: 3).gradient)
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Count", max(stats.failed, 1)),
                        stacking: .standard
                    )
                    .foregroundStyle(paletteManager.color(at: 4).gradient)
                    .cornerRadius(6)
                }
                .frame(height: 60)
                .chartXScale(domain: 0...(Double(max(stats.accepted + stats.failed, 1))))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                
                // Legend with percentages
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(paletteManager.color(at: 3))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accepted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.accepted)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(stats.total > 0 ? Int((Double(stats.accepted) / Double(stats.total)) * 100) : 0)%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(paletteManager.color(at: 4))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(stats.failed)")
                                    .font(.headline)
                                    .bold()
                                Text("(\(stats.total > 0 ? Int((Double(stats.failed) / Double(stats.total)) * 100) : 0)%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - All Solves View

struct SolveRow: View {
    let solve: Solve
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var isExpanded = false
    
    private var difficultyColor: Color {
        switch solve.problem.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(solve.problem.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 8) {
                            Text(solve.problem.difficulty.capitalized)
                                .font(.caption)
                                .foregroundStyle(difficultyColor)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(solve.problem.platform.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let topic = solve.problem.topic, !topic.isEmpty {
                            HStack(spacing: 6) {
                                Text(solve.problem.displayTopic ?? topic)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(4)
                                    .foregroundStyle(.secondary)
                                
                                if let subtopic = solve.problem.subtopic, !subtopic.isEmpty {
                                    Text(subtopic)
                                        .font(.system(size: 10, weight: .regular))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(4)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("+\(solve.xpAwarded)")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(paletteManager.color(at: 1))
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(paletteManager.color(at: 1))
                        }
                        
                        Text(formatDate(solve.activityAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // Language
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(paletteManager.color(at: 0))
                            .font(.caption)
                        Text("Language: \(solve.submission.language.capitalized)")
                            .font(.subheadline)
                    }
                    
                    // Number of tries
                    if let tries = solve.submission.numberOfTries {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(paletteManager.color(at: 1))
                                .font(.caption)
                            Text("Attempts: \(tries)")
                                .font(.subheadline)
                        }
                    }
                    
                    // Time taken
                    if let timeTaken = solve.submission.timeTaken {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(paletteManager.color(at: 2))
                                .font(.caption)
                            Text("Time: \(formatTime(timeTaken))")
                                .font(.subheadline)
                        }
                    }
                    
                    // AI Analysis
                    if let analysis = solve.aiAnalysis ?? solve.submission.aiAnalysis, !analysis.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(paletteManager.color(at: 3))
                                    .font(.caption)
                                Text("AI Analysis")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            MarkdownText(markdown: analysis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Mistake Tags
                    if let tags = solve.mistakeTags ?? solve.submission.mistakeTags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(paletteManager.color(at: 5))
                                    .font(.caption)
                                Text("Mistake Tags")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(paletteManager.color(at: 5).opacity(0.2))
                                            .foregroundStyle(paletteManager.color(at: 5))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // Highlight
                    //
                    // `note` and `content` arrive as `nil` when the viewer is not
                    // a friend (the server redacts private notes), so the block is
                    // rendered only when there is actually something to show —
                    // otherwise a stranger's solve would carry an empty "Note"
                    // heading with nothing under it.
                    if let highlight = solve.highlight,
                       highlight.hasContent {
                        let note = highlight.note ?? ""
                        let content = highlight.content ?? ""

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .foregroundStyle(paletteManager.color(at: 4))
                                    .font(.caption)
                                Text("Note")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            if !note.isEmpty {
                                MarkdownText(markdown: note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !content.isEmpty && content != note {
                                Text(content)
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            
                            if !highlight.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(highlight.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundStyle(.blue)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Re-solves and revisions move `lastActivityAt`, not `solvedAt`, so the
        // "3d ago" badge has to read the activity stamp or a problem you worked
        // on this morning still claims to be a week old.
        guard let date = ActivityTimestamp.date(from: dateString) else {
            return "via Chrome"
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Performance Metrics Card (NEW - Line Chart)
