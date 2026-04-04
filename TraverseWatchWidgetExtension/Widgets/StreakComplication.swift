import WidgetKit
import SwiftUI

struct WatchStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchStreakEntry {
        WatchStreakEntry(date: Date(), streak: 7, solvedToday: true, totalXp: 1200, totalSolves: 48)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStreakEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadData() -> WatchStreakEntry {
        if let data = WatchWidgetDataProvider.shared.loadWidgetData(),
           let streak = data.streak {
            return WatchStreakEntry(
                date: data.lastUpdated,
                streak: streak.currentStreak,
                solvedToday: streak.solvedToday,
                totalXp: streak.totalXp,
                totalSolves: streak.totalSolves
            )
        }

        return WatchStreakEntry(date: Date(), streak: 0, solvedToday: false, totalXp: 0, totalSolves: 0)
    }
}

struct WatchStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let solvedToday: Bool
    let totalXp: Int
    let totalSolves: Int
}

struct WatchStreakComplicationView: View {
    let entry: WatchStreakEntry
    @Environment(\.widgetFamily) private var family

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

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)

                Text("\(entry.streak)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var cornerView: some View {
        Text("\(entry.streak)")
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .widgetCurvesContent()
            .widgetLabel {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
            }
    }

    private var inlineView: some View {
        Label {
            Text("\(entry.streak) day streak")
        } icon: {
            Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 12))
                    Text("\(entry.streak) day streak")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("\(entry.totalXp) xp")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                        Text("\(entry.totalSolves) solved")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: entry.solvedToday ? "checkmark.seal.fill" : "xmark.seal")
                        .font(.system(size: 9))
                        .foregroundStyle(entry.solvedToday ? .green : .secondary)

                    Text(entry.solvedToday ? "Solved today" : "Not yet solved")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(entry.solvedToday ? .primary : .secondary)
                }
            }

            Spacer()
        }
    }
}

struct WatchStreakComplication: Widget {
    let kind = "WatchStreakComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStreakProvider()) { entry in
            WatchStreakComplicationView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Streak")
        .description("Your current coding streak")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}
