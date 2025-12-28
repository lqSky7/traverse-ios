//
//  RecentSolveWidget.swift
//  TraverseWidget
//

import WidgetKit
import SwiftUI

// MARK: - Recent Solve Provider
struct RecentSolveProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentSolveEntry {
        RecentSolveEntry(
            date: Date(),
            problemTitle: "Two Sum",
            platform: "leetcode",
            difficulty: "easy",
            xpAwarded: 10,
            language: "Swift",
            solvedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RecentSolveEntry) -> Void) {
        let entry: RecentSolveEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadRecentSolveData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentSolveEntry>) -> Void) {
        let entry = loadRecentSolveData()
        
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadRecentSolveData() -> RecentSolveEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let recentSolve = widgetData.recentSolve {
            return RecentSolveEntry(
                date: widgetData.lastUpdated,
                problemTitle: recentSolve.problemTitle,
                platform: recentSolve.platform,
                difficulty: recentSolve.difficulty,
                xpAwarded: recentSolve.xpAwarded,
                language: recentSolve.language,
                solvedAt: recentSolve.solvedAt
            )
        }
        
        // Default placeholder
        return RecentSolveEntry(
            date: Date(),
            problemTitle: "No recent solves",
            platform: "",
            difficulty: "",
            xpAwarded: 0,
            language: "",
            solvedAt: ""
        )
    }
}

// MARK: - Recent Solve Entry
struct RecentSolveEntry: TimelineEntry {
    let date: Date
    let problemTitle: String
    let platform: String
    let difficulty: String
    let xpAwarded: Int
    let language: String
    let solvedAt: String
    
    var hasData: Bool {
        !platform.isEmpty
    }
    
    var solvedDate: Date? {
        ISO8601DateFormatter().date(from: solvedAt)
    }
    
    var timeAgo: String {
        guard let solved = solvedDate else { return "" }
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: solved, to: Date())
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        }
        return "Just now"
    }
}

// MARK: - Recent Solve Widget View
struct RecentSolveWidgetView: View {
    let entry: RecentSolveEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallRecentSolveView(entry: entry)
        case .systemMedium:
            MediumRecentSolveView(entry: entry)
        default:
            SmallRecentSolveView(entry: entry)
        }
    }
}

struct SmallRecentSolveView: View {
    let entry: RecentSolveEntry
    
    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.problemTitle)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(entry.difficulty)
                            .font(.system(size: 8, weight: .semibold, design: .serif))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)
                        
                        Text("·")
                            .font(.system(size: 8, weight: .light, design: .serif))
                            .foregroundColor(.secondary)
                        
                        Text(entry.timeAgo)
                            .font(.system(size: 8, weight: .light, design: .serif))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("+\(entry.xpAwarded)")
                        .font(.system(size: 20, weight: .thin, design: .serif))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        } else {
            VStack {
                Text("—")
                    .font(.system(size: 32, weight: .ultraLight, design: .serif))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct MediumRecentSolveView: View {
    let entry: RecentSolveEntry
    
    private var motivationalQuote: String {
        let quotes = [
            "Every solve is progress.",
            "Learning never stops.",
            "Momentum builds mastery.",
            "Small wins add up.",
            "Code. Learn. Repeat."
        ]
        let index = abs(entry.problemTitle.hashValue) % quotes.count
        return quotes[index]
    }
    
    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("latest solve")
                        .font(.system(size: 8, weight: .semibold, design: .serif))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(2)
                    
                    Spacer()
                    
                    Text(entry.timeAgo)
                        .font(.system(size: 8, weight: .light, design: .serif))
                        .foregroundColor(.secondary)
                }
                
                Text(entry.problemTitle)
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(entry.difficulty)
                                .font(.system(size: 8, weight: .semibold, design: .serif))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            Text("·")
                                .font(.system(size: 8, weight: .light, design: .serif))
                                .foregroundColor(.secondary)
                            
                            Text(entry.language)
                                .font(.system(size: 8, weight: .light, design: .serif))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("+\(entry.xpAwarded)")
                            .font(.system(size: 24, weight: .thin, design: .serif))
                            .foregroundColor(.primary)
                    }
                    
                    Text(motivationalQuote)
                        .font(.system(size: 9, weight: .light, design: .serif))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        } else {
            VStack {
                Text("—")
                    .font(.system(size: 40, weight: .ultraLight, design: .serif))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Recent Solve Widget
struct RecentSolveWidget: Widget {
    let kind: String = "RecentSolveWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentSolveProvider()) { entry in
            RecentSolveWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Recent Solve")
        .description("See your most recently solved problem")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    RecentSolveWidget()
} timeline: {
    RecentSolveEntry(
        date: Date(),
        problemTitle: "Two Sum",
        platform: "leetcode",
        difficulty: "easy",
        xpAwarded: 10,
        language: "Swift",
        solvedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
    )
}
