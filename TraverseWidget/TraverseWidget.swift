//
//  TraverseWidget.swift
//  TraverseWidget
//

import WidgetKit
import SwiftUI

@main
struct TraverseWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        RecentSolveWidget()
        RevisionsWidget()
        StreakReminderLiveActivity()
    }
}
