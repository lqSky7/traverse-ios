import WidgetKit
import SwiftUI

@main
struct TraverseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        RevisionsWidget()
        TodayRevisionsWidget()
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Coding Streak")
        .description("Track your Traverse coding streak and get motivated.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RevisionsWidget: Widget {
    let kind: String = "RevisionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RevisionsProvider()) { entry in
            RevisionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Revisions Queue")
        .description("See your ML revisions scheduled for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
