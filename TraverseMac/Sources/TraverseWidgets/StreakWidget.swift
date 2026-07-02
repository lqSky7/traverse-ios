import WidgetKit
import SwiftUI

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let xp: Int
    let quote: String
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 5, xp: 2450, quote: "Consistency is the key to mastery.")
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let cache = WidgetCacheReader.readCache()
        let streak = cache?.userStats?.stats.currentStreak ?? cache?.user?.currentStreak ?? 0
        let xp = cache?.userStats?.stats.totalXp ?? cache?.user?.totalXp ?? 0
        let quote = MotivationQuotes.randomQuote()
        completion(StreakEntry(date: Date(), streak: streak, xp: xp, quote: quote))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let cache = WidgetCacheReader.readCache()
        let streak = cache?.userStats?.stats.currentStreak ?? cache?.user?.currentStreak ?? 0
        let xp = cache?.userStats?.stats.totalXp ?? cache?.user?.totalXp ?? 0
        
        var entries: [StreakEntry] = []
        let currentDate = Date()
        
        // Generate a timeline for 24 hours, picking a new quote every 2 hours
        for hourOffset in stride(from: 0, to: 24, by: 2) {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let quote = MotivationQuotes.quoteForDate(entryDate)
            let entry = StreakEntry(date: entryDate, streak: streak, xp: xp, quote: quote)
            entries.append(entry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MotivationQuotes {
    static let quotes = [
        "Consistency is the key to mastery.",
        "Make it work, make it right, make it fast.",
        "Small steps every day lead to big achievements.",
        "Code is like humor. When you have to explain it, it’s bad.",
        "First, solve the problem. Then, write the code.",
        "One day or day one. You decide.",
        "Progress, not perfection.",
        "The only way to learn a new programming language is by writing programs in it.",
        "Clean code always looks like it was written by someone who cares.",
        "Your streak is a reflection of your dedication.",
        "Don't stop when you are tired. Stop when you are done.",
        "Solve problems, write code, earn XP, level up.",
        "Keep the flame burning. Solve one revision today!",
        "Struggling is a part of learning. Keep pushing!",
        "Every error is a lesson in disguise."
    ]
    
    static func randomQuote() -> String {
        quotes.randomElement() ?? quotes[0]
    }
    
    static func quoteForDate(_ date: Date) -> String {
        let index = abs(Calendar.current.component(.hour, from: date) + Calendar.current.component(.day, from: date)) % quotes.count
        return quotes[index]
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry
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
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red, .pink], startPoint: .top, endPoint: .bottom))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.streak)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .lineLimit(1)
                    Text("DAYS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .padding(.horizontal, 4)
            
            Text(entry.quote)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.12), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .center, spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 4)
                        .frame(width: 68, height: 68)
                    
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        
                        Text("\(entry.streak)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                    }
                }
                
                Text("\(entry.xp) XP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
            .frame(width: 80)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("TRAVERSE MOTIVATION", systemImage: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Text("“\(entry.quote)”")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .italic()
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                
                Spacer()
                
                Text("Keep the streak alive!")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.12), Color.red.opacity(0.04), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
