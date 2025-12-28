# Traverse Widgets Setup Instructions

## What's Been Created

I've created three widgets for your Traverse app:

1. **Streak Widget** - Shows current streak, solved today status, total XP and solves
2. **Recent Solve Widget** - Displays the most recently solved problem with details
3. **Revisions Widget** - Lists problems scheduled for revision today

## Files Created

### Widget Extension Files
- `/TraverseWidget/TraverseWidget.swift` - Widget bundle entry point
- `/TraverseWidget/StreakWidget.swift` - Streak widget implementation
- `/TraverseWidget/RecentSolveWidget.swift` - Recent solve widget implementation
- `/TraverseWidget/RevisionsWidget.swift` - Revisions widget implementation
- `/TraverseWidget/WidgetDataModels.swift` - Shared data models
- `/TraverseWidget/Info.plist` - Widget extension configuration
- `/TraverseWidget/Assets.xcassets/` - Widget assets

### Main App Files
- `/traverse/Services/WidgetDataUpdater.swift` - Helper to update widget data from app

## Setup Steps in Xcode

### 1. Add Widget Extension Target

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension**
3. Name it **TraverseWidget**
4. Product Name: `TraverseWidget`
5. Include Configuration Intent: **No**
6. Click **Finish**
7. When prompted about scheme activation, click **Activate**

### 2. Configure App Groups

Both the main app and widget need to share data via App Groups.

#### Enable App Groups for Main App:
1. Select the **traverse** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and create: `group.com.traverse.app`

#### Enable App Groups for Widget:
1. Select the **TraverseWidget** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Select the same group: `group.com.traverse.app`

### 3. Add Widget Files to Target

1. In Xcode's file navigator, find the `TraverseWidget` folder
2. Delete the auto-generated files (keep only what we created)
3. Drag the created widget files into the project
4. Make sure they're added to the **TraverseWidget** target

### 4. Link Shared Models

The widget needs access to these models from the main app. Add them to both targets:

1. Select these files in the main app:
   - `WidgetDataModels.swift` (already in TraverseWidget)
   
2. In File Inspector, check both:
   - ✅ traverse
   - ✅ TraverseWidget

### 5. Update HomeView to Feed Widget Data

Add this code to your `HomeView.swift` where data is loaded:

```swift
// Add import at top
import WidgetKit

// In the loadData function or where you have data loaded, add:
private func updateWidgets() {
    // Update streak widget
    if let userStats = viewModel.userStats?.stats {
        let solvedToday = hasSolvedToday(recentSolves: viewModel.recentSolves)
        WidgetDataUpdater.shared.updateStreakStatus(
            solvedToday: solvedToday,
            currentStreak: userStats.currentStreak,
            totalXp: userStats.totalXp,
            totalSolves: userStats.totalSolves
        )
    }
    
    // Update all widgets with complete data
    WidgetDataUpdater.shared.updateWidgetData(
        userStats: viewModel.userStats?.stats,
        recentSolve: viewModel.recentSolves?.first,
        revisions: viewModel.todayRevisions // Add this to your view model if needed
    )
}
```

Call `updateWidgets()` after successfully loading data.

### 6. Fetch Revision Data in HomeView

If you don't already have today's revisions in HomeView, add this to your HomeViewModel:

```swift
@Published var todayRevisions: [Revision] = []

func loadRevisions() async {
    do {
        let response = try await NetworkService.shared.getRevisions(upcoming: true, limit: 10)
        let today = response.revisions.filter { Calendar.current.isDateInToday($0.scheduledDate) }
        await MainActor.run {
            self.todayRevisions = today
        }
    } catch {
        print("Failed to load revisions: \\(error)")
    }
}
```

### 7. Build and Run

1. Select the **TraverseWidget** scheme
2. Build and run on a device or simulator
3. Long press on home screen
4. Tap **+** to add widgets
5. Search for **Traverse**
6. Add your desired widgets!

## Widget Features

### Streak Widget
- **Small**: Shows streak count, flame icon, and status
- **Medium**: Adds XP and total solves stats

### Recent Solve Widget  
- **Small**: Problem title, difficulty, XP, and time ago
- **Medium**: Adds platform, language, and more details

### Revisions Widget
- **Small**: Count of revisions due today + first problem preview
- **Medium**: List of up to 3 revisions with full details

## Widget Updates

Widgets automatically refresh:
- Streak Widget: Every 15 minutes
- Recent Solve Widget: Every 30 minutes
- Revisions Widget: Every hour

Manual refresh happens when:
- App updates widget data via `WidgetDataUpdater`
- User explicitly refreshes from widget

## Troubleshooting

**Widgets show placeholder data:**
- Make sure App Groups are configured correctly on both targets
- Verify the group name is exactly `group.com.traverse.app`
- Check that `updateWidgets()` is being called in the main app

**Build errors:**
- Ensure all widget files are added to the TraverseWidget target
- Check that imports are correct
- Verify iOS deployment target matches (iOS 16+)

**Widgets not appearing:**
- Build the widget extension scheme first
- Check widget extension is included in the main app bundle
- Try deleting and reinstalling the app

## Next Steps

1. Customize widget colors to match your app's theme
2. Add widget configuration for user preferences
3. Implement deep links to open specific screens from widgets
4. Consider adding a large widget size with more information
