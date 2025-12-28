import ActivityKit
import WidgetKit
import SwiftUI

struct StreakReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreakReminderAttributes.self) { context in
            // Lock screen/banner UI
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Streak at Risk!")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Text("\(context.state.hoursRemaining)h left to solve")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Current streak: \(context.state.currentStreak) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(context.state.hoursRemaining)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.orange)
                    Text("hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(context.state.currentStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Text("\(context.state.hoursRemaining)h")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Solve a problem to keep your \(context.state.currentStreak)-day streak alive!")
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text("\(context.state.hoursRemaining)h")
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}
