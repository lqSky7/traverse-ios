//
//  ProgressComplication.swift
//  Traverse Watch App
//
//  Watch complication showing daily progress — solved today status and XP.
//  Supports: accessoryCircular, accessoryCorner, accessoryInline, accessoryRectangular
//

import WidgetKit
import SwiftUI

// MARK: - Provider

struct WatchProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchProgressEntry {
        WatchProgressEntry(
            date: Date(),
            solvedToday: true,
            totalXp: 1200,
            streak: 14,
            achievementsUnlocked: 12,
            achievementsTotal: 20
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WatchProgressEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(loadData())
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchProgressEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func loadData() -> WatchProgressEntry {
        if let data = WatchWidgetDataProvider.shared.loadWidgetData() {
            return WatchProgressEntry(
                date: data.lastUpdated,
                solvedToday: data.streak?.solvedToday ?? false,
                totalXp: data.streak?.totalXp ?? 0,
                streak: data.streak?.currentStreak ?? 0,
                achievementsUnlocked: data.achievements?.unlocked ?? 0,
                achievementsTotal: data.achievements?.total ?? 0
            )
        }
        return WatchProgressEntry(
            date: Date(),
            solvedToday: false,
            totalXp: 0,
            streak: 0,
            achievementsUnlocked: 0,
            achievementsTotal: 0
        )
    }
}

// MARK: - Entry

struct WatchProgressEntry: TimelineEntry {
    let date: Date
    let solvedToday: Bool
    let totalXp: Int
    let streak: Int
    let achievementsUnlocked: Int
    let achievementsTotal: Int
    
    var statusMessage: String {
        if solvedToday {
            return "Great work today"
        } else if streak > 0 {
            return "Keep your streak alive"
        } else {
            return "Start solving today"
        }
    }
    
    var statusIcon: String {
        if solvedToday {
            return "checkmark.seal.fill"
        } else if streak > 0 {
            return "exclamationmark.triangle"
        } else {
            return "arrow.right.circle"
        }
    }
}

// MARK: - Views

struct WatchProgressComplicationView: View {
    let entry: WatchProgressEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }
    
    // MARK: Circular
    private var circularView: some View {
        ZStack {
            // Progress ring based on achievements
            let progress = entry.achievementsTotal > 0
                ? Double(entry.achievementsUnlocked) / Double(entry.achievementsTotal)
                : 0.0
            
            Gauge(value: progress) {
                Image(systemName: entry.solvedToday ? "checkmark.seal.fill" : "xmark.seal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(entry.solvedToday ? .green : .secondary)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.solvedToday ? .green : .blue)
        }
    }
    
    // MARK: Corner
    private var cornerView: some View {
        Image(systemName: entry.statusIcon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(entry.solvedToday ? .green : .secondary)
            .widgetCurvesContent()
            .widgetLabel {
                Text(entry.solvedToday ? "Done" : "Solve")
            }
    }
    
    // MARK: Inline
    private var inlineView: some View {
        Label {
            Text(entry.statusMessage)
        } icon: {
            Image(systemName: entry.statusIcon)
        }
    }
    
    // MARK: Rectangular
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Status
            HStack(spacing: 4) {
                Image(systemName: entry.statusIcon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(entry.solvedToday ? .green : .secondary)
                
                Text(entry.statusMessage)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            
            // Quick stats row
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                    Text("\(entry.streak)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.orange)
                
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text("\(entry.totalXp)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.yellow)
                
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 8))
                    Text("\(entry.achievementsUnlocked)/\(entry.achievementsTotal)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.purple)
            }
            .foregroundStyle(.secondary)
            
            // Progress bar
            GeometryReader { geo in
                let progress = entry.achievementsTotal > 0
                    ? CGFloat(entry.achievementsUnlocked) / CGFloat(entry.achievementsTotal)
                    : 0.0
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.purple)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Widget

struct WatchProgressComplication: Widget {
    let kind = "WatchProgressComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProgressProvider()) { entry in
            WatchProgressComplicationView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Progress")
        .description("Your daily coding progress and achievements")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    WatchProgressComplication()
} timeline: {
    WatchProgressEntry(date: Date(), solvedToday: true, totalXp: 1200, streak: 14, achievementsUnlocked: 12, achievementsTotal: 20)
    WatchProgressEntry(date: Date(), solvedToday: false, totalXp: 450, streak: 3, achievementsUnlocked: 5, achievementsTotal: 20)
}
