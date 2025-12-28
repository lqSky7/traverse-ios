//
//  StreakWidget.swift
//  TraverseWidget
//

import WidgetKit
import SwiftUI

// MARK: - Streak Widget Provider
struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7, solvedToday: true, totalXp: 450, totalSolves: 25)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry: StreakEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadStreakData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = loadStreakData()
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadStreakData() -> StreakEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let streakData = widgetData.streak {
            return StreakEntry(
                date: widgetData.lastUpdated,
                streak: streakData.currentStreak,
                solvedToday: streakData.solvedToday,
                totalXp: streakData.totalXp,
                totalSolves: streakData.totalSolves
            )
        }
        
        // No data available - return zeros
        return StreakEntry(date: Date(), streak: 0, solvedToday: false, totalXp: 0, totalSolves: 0)
    }
}

// MARK: - Streak Entry
struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let solvedToday: Bool
    let totalXp: Int
    let totalSolves: Int
}

// MARK: - Streak Widget View
struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallStreakView(entry: entry)
        case .systemMedium:
            MediumStreakView(entry: entry)
        default:
            SmallStreakView(entry: entry)
        }
    }
}

struct SmallStreakView: View {
    let entry: StreakEntry
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(entry.streak)")
                .font(.system(size: 56, weight: .thin, design: .serif))
                .foregroundColor(.primary)
            
            Text("day streak")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediumStreakView: View {
    let entry: StreakEntry
    
    private var motivationalQuote: String {
        let quotes = [
            "Keep pushing.",
            "One day at a time.",
            "Stay consistent.",
            "Progress over perfection.",
            "Build the habit."
        ]
        let index = (entry.streak + Calendar.current.component(.day, from: entry.date)) % quotes.count
        return quotes[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.streak)")
                        .font(.system(size: 48, weight: .ultraLight, design: .serif))
                        .foregroundColor(.primary)
                    
                    Text("day streak")
                        .font(.system(size: 9, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 3) {
                        Text("\(entry.totalXp)")
                            .font(.system(size: 18, weight: .light, design: .serif))
                        Text("xp")
                            .font(.system(size: 8, weight: .semibold, design: .serif))
                            .foregroundColor(.secondary)
                            .tracking(1)
                    }
                    .foregroundColor(.primary)
                    
                    HStack(spacing: 3) {
                        Text("\(entry.totalSolves)")
                            .font(.system(size: 18, weight: .light, design: .serif))
                        Text("solved")
                            .font(.system(size: 8, weight: .semibold, design: .serif))
                            .foregroundColor(.secondary)
                            .tracking(1)
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Text(motivationalQuote)
                .font(.system(size: 9, weight: .light, design: .serif))
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

// MARK: - Streak Widget
struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Streak")
        .description("Track your current coding streak")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: Date(), streak: 7, solvedToday: true, totalXp: 450, totalSolves: 25)
    StreakEntry(date: Date(), streak: 0, solvedToday: false, totalXp: 0, totalSolves: 0)
}
