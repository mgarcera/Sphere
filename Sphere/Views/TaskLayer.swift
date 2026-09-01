import SwiftUI

/// Task dots, in the blue reserved for them so they never read as part of the
/// planetary palette. Kept out of `ArcContent` because active/inactive depends
/// on `focusHour`: a handful of circles can afford to re-render every frame,
/// the 288-point arc path cannot.
struct TaskLayer: View {
    let tasks: [DayTask]
    let day: SolarDay
    let width: CGFloat
    let height: CGFloat
    let activeTaskID: DayTask.ID?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(tasks) { task in
                let isActive = task.id == activeTaskID
                let point = DayArcShape.point(
                    forHour: task.hour,
                    day: day,
                    in: CGRect(x: 0, y: 0, width: width, height: height)
                )

                Circle()
                    .fill(isActive ? Theme.taskActive : Theme.taskInactive)
                    .frame(width: isActive ? 11 : 7, height: isActive ? 11 : 7)
                    .position(point)
            }
        }
        .frame(width: width, height: height + ArcContent.labelGutter, alignment: .topLeading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeTaskID)
    }
}
