import WidgetKit
import SwiftUI

struct TodayRevisionsEntry: TimelineEntry {
    let date: Date
    let title: String?
}

struct TodayRevisionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayRevisionsEntry {
        TodayRevisionsEntry(date: Date(), title: "Two Sum")
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayRevisionsEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayRevisionsEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> TodayRevisionsEntry {
        let cache = WidgetCacheReader.readCache()
        let title = cache?.todayRevisions?.revisions.first?.title
        return TodayRevisionsEntry(date: Date(), title: title)
    }
}

struct TodayRevisionsWidgetView: View {
    let entry: TodayRevisionsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.title ?? "No revisions today")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.16, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var fontSize: CGFloat {
        family == .systemSmall ? 16 : 20
    }

    private var lineLimit: Int {
        family == .systemSmall ? 3 : 4
    }
}

struct TodayRevisionsWidget: Widget {
    let kind: String = "TodayRevisionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayRevisionsProvider()) { entry in
            TodayRevisionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Revision")
        .description("See the next problem scheduled for revision.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
