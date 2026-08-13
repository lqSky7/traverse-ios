import WidgetKit
import SwiftUI

struct RevisionsEntry: TimelineEntry {
    let date: Date
    let totalDue: Int
    let overdue: Int
    let revisions: [WidgetRevision]
}

struct RevisionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RevisionsEntry {
        RevisionsEntry(
            date: Date(),
            totalDue: 4,
            overdue: 1,
            revisions: [
                WidgetRevision(id: 1, revisionNumber: 1, scheduledFor: "2026-05-25", problem: WidgetProblem(platform: "LeetCode", title: "Two Sum", difficulty: "Easy")),
                WidgetRevision(id: 2, revisionNumber: 2, scheduledFor: "2026-05-25", problem: WidgetProblem(platform: "HackerRank", title: "Array Manipulation", difficulty: "Hard"))
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RevisionsEntry) -> Void) {
        let cache = WidgetCacheReader.readCache()
        let today = cache?.todayRevisions
        let total = today?.total ?? 0
        let overdue = today?.overdue ?? 0
        let revisions = today?.revisions ?? []
        completion(RevisionsEntry(date: Date(), totalDue: total, overdue: overdue, revisions: revisions))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RevisionsEntry>) -> Void) {
        let cache = WidgetCacheReader.readCache()
        let today = cache?.todayRevisions
        let total = today?.total ?? 0
        let overdue = today?.overdue ?? 0
        let revisions = today?.revisions ?? []
        
        let entry = RevisionsEntry(date: Date(), totalDue: total, overdue: overdue, revisions: revisions)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RevisionsWidgetView: View {
    let entry: RevisionsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        default:
            mediumWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.headspace")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Spacer()
                if entry.overdue > 0 {
                    Text("\(entry.overdue) Overdue")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                }
            }
            
            Spacer()
            
            Text("\(entry.totalDue)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text("Revisions Due Today")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("REVISIONS", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(entry.totalDue)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.purple)
                
                Text("Due Today")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if entry.overdue > 0 {
                    Label("\(entry.overdue) overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                
                Spacer()
            }
            .frame(width: 90, alignment: .leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if entry.revisions.isEmpty {
                    VStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        Text("All caught up!")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Next Up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    
                    ForEach(entry.revisions.prefix(3)) { revision in
                        HStack(spacing: 8) {
                            Text(revision.platform.prefix(2).uppercased())
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(platformColor(revision.platform), in: RoundedRectangle(cornerRadius: 4))
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(revision.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Text("Review #\(revision.revisionNumber) • \(revision.difficulty)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if entry.totalDue > 3 {
                        Text("+ \(entry.totalDue - 3) more reviews")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.purple)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "leetcode": return .orange
        case "hackerrank": return .green
        case "codeforces": return .red
        default: return .blue
        }
    }
}
