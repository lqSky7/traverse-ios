//
//  LockScreenWidgets.swift
//  TraverseWidget
//

import WidgetKit
import SwiftUI

// MARK: - Streak Lock Screen Widget

struct StreakLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakLockScreenEntry {
        StreakLockScreenEntry(date: Date(), streak: 7, solvedToday: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakLockScreenEntry) -> Void) {
        let entry: StreakLockScreenEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakLockScreenEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> StreakLockScreenEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let streakData = widgetData.streak {
            return StreakLockScreenEntry(
                date: widgetData.lastUpdated,
                streak: streakData.currentStreak,
                solvedToday: streakData.solvedToday
            )
        }
        return StreakLockScreenEntry(date: Date(), streak: 0, solvedToday: false)
    }
}

struct StreakLockScreenEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let solvedToday: Bool
}

struct StreakLockScreenWidgetView: View {
    let entry: StreakLockScreenEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 14))
                Text("\(entry.streak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
    }
}

struct StreakLockScreenWidget: Widget {
    let kind: String = "StreakLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakLockScreenProvider()) { entry in
            StreakLockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Streak")
        .description("Your current coding streak")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Achievements Lock Screen Widget

struct AchievementsLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> AchievementsLockScreenEntry {
        AchievementsLockScreenEntry(date: Date(), unlocked: 12, total: 20)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (AchievementsLockScreenEntry) -> Void) {
        let entry: AchievementsLockScreenEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<AchievementsLockScreenEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> AchievementsLockScreenEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let achievements = widgetData.achievements {
            return AchievementsLockScreenEntry(
                date: widgetData.lastUpdated,
                unlocked: achievements.unlocked,
                total: achievements.total
            )
        }
        return AchievementsLockScreenEntry(date: Date(), unlocked: 0, total: 0)
    }
}

struct AchievementsLockScreenEntry: TimelineEntry {
    let date: Date
    let unlocked: Int
    let total: Int
}

struct AchievementsLockScreenWidgetView: View {
    let entry: AchievementsLockScreenEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                Text("\(entry.unlocked)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
    }
}

struct AchievementsLockScreenWidget: Widget {
    let kind: String = "AchievementsLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AchievementsLockScreenProvider()) { entry in
            AchievementsLockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Achievements")
        .description("Your unlocked achievements")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Motivational Message Lock Screen Widget

struct MotivationalLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> MotivationalLockScreenEntry {
        MotivationalLockScreenEntry(date: Date(), streak: 7, solvedToday: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MotivationalLockScreenEntry) -> Void) {
        let entry: MotivationalLockScreenEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MotivationalLockScreenEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> MotivationalLockScreenEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData(),
           let streakData = widgetData.streak {
            return MotivationalLockScreenEntry(
                date: widgetData.lastUpdated,
                streak: streakData.currentStreak,
                solvedToday: streakData.solvedToday
            )
        }
        return MotivationalLockScreenEntry(date: Date(), streak: 0, solvedToday: false)
    }
}

struct MotivationalLockScreenEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let solvedToday: Bool
    
    var message: String {
        if solvedToday {
            return "Well done! Keep it up!"
        } else if streak == 0 {
            return "Start your streak!"
        } else {
            return "Get back to work!"
        }
    }
    
    var icon: String {
        if solvedToday {
            return "checkmark.circle.fill"
        } else if streak == 0 {
            return "flame"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
}

struct MotivationalLockScreenWidgetView: View {
    let entry: MotivationalLockScreenEntry
    
    var body: some View {
        // accessoryInline is text-only, with optional leading SF Symbol
        Label(entry.message, systemImage: entry.icon)
    }
}

struct MotivationalLockScreenWidget: Widget {
    let kind: String = "MotivationalLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MotivationalLockScreenProvider()) { entry in
            MotivationalLockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Daily Motivation")
        .description("Your daily coding reminder above the clock")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Previews

#Preview("Streak Circular", as: .accessoryCircular) {
    StreakLockScreenWidget()
} timeline: {
    StreakLockScreenEntry(date: Date(), streak: 7, solvedToday: true)
    StreakLockScreenEntry(date: Date(), streak: 0, solvedToday: false)
}

#Preview("Achievements Circular", as: .accessoryCircular) {
    AchievementsLockScreenWidget()
} timeline: {
    AchievementsLockScreenEntry(date: Date(), unlocked: 12, total: 20)
}

#Preview("Motivational Inline", as: .accessoryInline) {
    MotivationalLockScreenWidget()
} timeline: {
    MotivationalLockScreenEntry(date: Date(), streak: 7, solvedToday: true)
    MotivationalLockScreenEntry(date: Date(), streak: 5, solvedToday: false)
    MotivationalLockScreenEntry(date: Date(), streak: 0, solvedToday: false)
}
