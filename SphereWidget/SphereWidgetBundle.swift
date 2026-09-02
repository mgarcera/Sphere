import SwiftUI
import WidgetKit

@main
struct SphereWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayArcWidget()
        HomeArcWidget()
        DayActivityWidget()
    }
}
