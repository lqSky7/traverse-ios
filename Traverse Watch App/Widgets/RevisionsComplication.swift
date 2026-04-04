//
//  RevisionsComplication.swift
//  Traverse Watch App
//
//  Watch complication showing revisions due count.
//  Supports: accessoryCircular, accessoryCorner, accessoryInline, accessoryRectangular
//

import WidgetKit
import SwiftUI

// MARK: - Provider

struct WatchRevisionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchRevisionsEntry {
        WatchRevisionsEntry(
            date: Date(),
            dueCount: 3,
            revisions: [
                WatchSnapshotRevision(id: 1, problemTitle: "Binary Search", platform: "leetcode", difficulty: "easy", revisionNumber: 2, scheduledFor: "", isOverdue: false),
                WatchSnapshotRevision(id: 2, problemTitle: "Merge Sort", platform: "leetcode", difficulty: "medium", revisionNumber: 1, scheduledFor: "", isOverdue: true)
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WatchRevisionsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(loadData())
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchRevisionsEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func loadData() -> WatchRevisionsEntry {
        if let data = WatchWidgetDataProvider.shared.loadWidgetData() {
            return WatchRevisionsEntry(
                date: data.lastUpdated,
                dueCount: data.revisionsDueCount,
                revisions: data.revisions ?? []
            )
        }
        return WatchRevisionsEntry(date: Date(), dueCount: 0, revisions: [])
    }
}

// MARK: - Entry

struct WatchRevisionsEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let revisions: [WatchSnapshotRevision]
}

// MARK: - Views

struct WatchRevisionsComplicationView: View {
    let entry: WatchRevisionsEntry
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
    
    // MARK: Circular - Due count with progress ring
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 1) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(entry.dueCount > 0 ? .blue : .secondary)
                
                Text("\(entry.dueCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
        }
    }
    
    // MARK: Corner
    private var cornerView: some View {
        Text("\(entry.dueCount)")
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .widgetCurvesContent()
            .widgetLabel {
                Text("due")
            }
    }
    
    // MARK: Inline
    private var inlineView: some View {
        Label {
            Text(entry.dueCount == 0 ? "No revisions due" : "\(entry.dueCount) revisions due")
        } icon: {
            Image(systemName: "clock.arrow.circlepath")
        }
    }
    
    // MARK: Rectangular - Shows first 2 problems
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Revisions Due")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                
                Spacer()
                
                Text("\(entry.dueCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            if entry.revisions.isEmpty {
                Text("All caught up")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.revisions.prefix(2)) { revision in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(difficultyColor(revision.difficulty))
                            .frame(width: 4, height: 4)
                        
                        Text(revision.problemTitle)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if revision.isOverdue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.red)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                if entry.dueCount > 2 {
                    Text("+\(entry.dueCount - 2) more")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }
}

// MARK: - Widget

struct WatchRevisionsComplication: Widget {
    let kind = "WatchRevisionsComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchRevisionsProvider()) { entry in
            WatchRevisionsComplicationView(entry: entry)
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Revisions")
        .description("Problems due for revision today")
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
    WatchRevisionsComplication()
} timeline: {
    WatchRevisionsEntry(
        date: Date(),
        dueCount: 5,
        revisions: [
            WatchSnapshotRevision(id: 1, problemTitle: "Binary Search", platform: "leetcode", difficulty: "easy", revisionNumber: 2, scheduledFor: "", isOverdue: false),
            WatchSnapshotRevision(id: 2, problemTitle: "Merge Two Sorted Lists", platform: "leetcode", difficulty: "medium", revisionNumber: 1, scheduledFor: "", isOverdue: true)
        ]
    )
    WatchRevisionsEntry(date: Date(), dueCount: 0, revisions: [])
}
