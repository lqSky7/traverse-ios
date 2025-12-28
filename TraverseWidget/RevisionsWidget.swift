//
//  RevisionsWidget.swift
//  TraverseWidget
//

import WidgetKit
import SwiftUI

// MARK: - Revisions Provider
struct RevisionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RevisionsEntry {
        RevisionsEntry(
            date: Date(),
            revisions: [
                RevisionData(id: 1, problemTitle: "Binary Search", platform: "leetcode", difficulty: "easy", revisionNumber: 2, scheduledFor: ISO8601DateFormatter().string(from: Date()), isOverdue: false),
                RevisionData(id: 2, problemTitle: "Merge Sort", platform: "leetcode", difficulty: "medium", revisionNumber: 1, scheduledFor: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)), isOverdue: false)
            ],
            totalDueToday: 2
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RevisionsEntry) -> Void) {
        let entry: RevisionsEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = loadRevisionsData()
        }
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RevisionsEntry>) -> Void) {
        let entry = loadRevisionsData()
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadRevisionsData() -> RevisionsEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData() {
            // Use the pre-calculated count - no date parsing needed
            let count = widgetData.revisionsDueCount
            let revisions = widgetData.revisions ?? []
            
            return RevisionsEntry(
                date: widgetData.lastUpdated,
                revisions: Array(revisions.prefix(3)),
                totalDueToday: count
            )
        }
        
        // No data available
        return RevisionsEntry(date: Date(), revisions: [], totalDueToday: 0)
    }
}

// MARK: - Revisions Entry
struct RevisionsEntry: TimelineEntry {
    let date: Date
    let revisions: [RevisionData]
    let totalDueToday: Int
    
    var hasRevisions: Bool {
        !revisions.isEmpty
    }
}

// MARK: - Revisions Widget View
struct RevisionsWidgetView: View {
    let entry: RevisionsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallRevisionsView(entry: entry)
        case .systemMedium:
            MediumRevisionsView(entry: entry)
        default:
            SmallRevisionsView(entry: entry)
        }
    }
}

struct SmallRevisionsView: View {
    let entry: RevisionsEntry
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(entry.totalDueToday)")
                .font(.system(size: 56, weight: .thin, design: .serif))
                .foregroundColor(.primary)
            
            Text("due today")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediumRevisionsView: View {
    let entry: RevisionsEntry
    
    private var motivationalQuote: String {
        let quotes = [
            "Repetition is mastery.",
            "Review to remember.",
            "Practice makes permanent.",
            "Strengthen your foundation.",
            "Revisit to reinforce."
        ]
        let index = (entry.totalDueToday + Calendar.current.component(.day, from: entry.date)) % quotes.count
        return quotes[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text("due today")
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                
                Spacer()
                
                Text("\(entry.totalDueToday)")
                    .font(.system(size: 18, weight: .thin, design: .serif))
                    .foregroundColor(.primary)
            }
            
            if entry.hasRevisions {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.revisions.prefix(3)) { revision in
                        HStack(alignment: .firstTextBaseline) {
                            Text(revision.problemTitle)
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("#\(revision.revisionNumber)")
                                .font(.system(size: 9, weight: .light, design: .serif))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if entry.totalDueToday > 3 {
                        Text("+\(entry.totalDueToday - 3) more")
                            .font(.system(size: 9, weight: .light, design: .serif))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Text(motivationalQuote)
                    .font(.system(size: 9, weight: .light, design: .serif))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 4)
            } else {
                Spacer()
                VStack(spacing: 4) {
                    Text("—")
                        .font(.system(size: 24, weight: .ultraLight, design: .serif))
                        .foregroundColor(.secondary)
                    
                    Text(motivationalQuote)
                        .font(.system(size: 9, weight: .light, design: .serif))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

// MARK: - Revisions Widget
struct RevisionsWidget: Widget {
    let kind: String = "RevisionsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RevisionsProvider()) { entry in
            RevisionsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Revisions")
        .description("Track problems scheduled for revision today")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    RevisionsWidget()
} timeline: {
    RevisionsEntry(
        date: Date(),
        revisions: [
            RevisionData(id: 1, problemTitle: "Binary Search", platform: "leetcode", difficulty: "easy", revisionNumber: 2, scheduledFor: ISO8601DateFormatter().string(from: Date()), isOverdue: false),
            RevisionData(id: 2, problemTitle: "Merge Two Sorted Lists", platform: "leetcode", difficulty: "medium", revisionNumber: 1, scheduledFor: ISO8601DateFormatter().string(from: Date()), isOverdue: true),
            RevisionData(id: 3, problemTitle: "Valid Parentheses", platform: "leetcode", difficulty: "easy", revisionNumber: 3, scheduledFor: ISO8601DateFormatter().string(from: Date()), isOverdue: false)
        ],
        totalDueToday: 5
    )
    RevisionsEntry(date: Date(), revisions: [], totalDueToday: 0)
}
