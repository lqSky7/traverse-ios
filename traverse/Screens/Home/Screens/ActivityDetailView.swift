import SwiftUI
import Charts

struct ActivityDetailView: View {
    let solves: [Solve]
    var frozenDates: Set<String> = []  // YYYY-MM-DD format
    @ObservedObject var paletteManager: ColorPaletteManager
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // Process solves into date -> difficulty data
    private var heatmapData: [Date: (difficulty: String, count: Int)] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var data: [Date: (String, Int)] = [:]
        
        for solve in solves {
            guard let date = formatter.date(from: solve.solvedAt) else { continue }
            let day = Calendar.current.startOfDay(for: date)
            if let existing = data[day] {
                let newDifficulty = harderDifficulty(existing.0, solve.problem.difficulty)
                data[day] = (newDifficulty, existing.1 + 1)
            } else {
                data[day] = (solve.problem.difficulty, 1)
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
    
    // Generate last 20 weeks of dates (fits on screen)
    private var weekDates: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var weeks: [[Date]] = []
        
        for weekOffset in (0..<20).reversed() {
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
        // Check if this date is a frozen day (ice blue)
        let dateString = Self.dateFormatter.string(from: date)
        if frozenDates.contains(dateString) {
            return Color(red: 0.31, green: 0.76, blue: 0.97)
        }
        
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard let data = heatmapData[normalizedDate] else {
            return Color.gray.opacity(0.15)
        }
        switch data.difficulty.lowercased() {
        case "easy": return paletteManager.color(at: 0)
        case "medium": return paletteManager.color(at: 1)
        case "hard": return paletteManager.color(at: 2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private var totalActiveDays: Int {
        heatmapData.count
    }
    
    private var totalSolves: Int {
        heatmapData.values.reduce(0) { $0 + $1.1 }
    }
    
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary stats
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalActiveDays)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 3))
                        Text("Active Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalSolves)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 0))
                        Text("Total Solves")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Heatmap card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last 20 Weeks")
                        .font(.headline)
                    
                    // Heatmap grid with day labels
                    GeometryReader { geometry in
                        let availableWidth = geometry.size.width - 40 // Account for day labels
                        let cellSize = (availableWidth - CGFloat(19 * 3)) / 20 // 20 weeks, 3pt spacing
                        
                        HStack(alignment: .top, spacing: 4) {
                            // Day labels
                            VStack(spacing: max(cellSize * 0.2, 2)) {
                                ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, day in
                                    Text(day)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32, height: cellSize, alignment: .trailing)
                                }
                            }
                            
                            // Heatmap grid
                            HStack(spacing: 3) {
                                ForEach(Array(weekDates.enumerated()), id: \.offset) { _, week in
                                    VStack(spacing: 3) {
                                        ForEach(week, id: \.self) { date in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(colorForDate(date))
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 140)
                    
                    // Legend
                    HStack {
                        HStack(spacing: 8) {
                            Text("Less")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                ForEach([Color.gray.opacity(0.15), paletteManager.color(at: 0), paletteManager.color(at: 1), paletteManager.color(at: 2)], id: \.self) { color in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Text("More")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Difficulty legend
                    HStack(spacing: 16) {
                        ForEach([(paletteManager.color(at: 0), "Easy"), (paletteManager.color(at: 1), "Medium"), (paletteManager.color(at: 2), "Hard")], id: \.1) { color, label in
                            HStack(spacing: 6) {
                                Circle().fill(color).frame(width: 10, height: 10)
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
    }
}

// MARK: - Submission Breakdown Card (NEW)
