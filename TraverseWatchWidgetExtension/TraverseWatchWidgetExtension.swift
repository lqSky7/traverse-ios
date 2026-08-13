import WidgetKit
import SwiftUI

@main
struct TraverseWatchWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WatchStreakComplication()
        WatchRevisionsComplication()
        WatchProgressComplication()
    }
}
