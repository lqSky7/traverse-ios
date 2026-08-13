import WidgetKit
import SwiftUI

struct TraverseWatchWidgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WatchStreakComplication()
        WatchRevisionsComplication()
        WatchProgressComplication()
    }
}
