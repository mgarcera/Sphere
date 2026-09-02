import ActivityKit
import SwiftUI
import WidgetKit

/// The event you are in, on the lock screen and in the Dynamic Island.
///
/// The arc is static for the length of the activity, which is correct: the day
/// does not change while one event runs. What moves is the countdown and the
/// bar, both of which the system runs itself from a date range with no updates
/// at all. The dot moves only when the app is there to push it.
struct DayActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.title)
                        .font(.display(17))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.start...context.attributes.end,
                         countsDown: true)
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.mutedLight)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityArc(context: context)
                        .frame(height: 44)
                }
            } compactLeading: {
                // The whole app at its smallest: one dot, at the height the
                // sun actually is.
                ActivityDot(context: context)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(timerInterval: context.attributes.start...context.attributes.end,
                     countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                ActivityDot(context: context)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<DayActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.title)
                    .font(.display(19))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(timerInterval: context.attributes.start...context.attributes.end,
                     countsDown: true)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mutedLight)
                    .frame(width: 62, alignment: .trailing)
            }
            ActivityArc(context: context)
                .frame(height: 46)
        }
        .padding(16)
    }
}

/// The day, with this event's stretch of it picked out.
struct ActivityArc: View {
    let context: ActivityViewContext<DayActivityAttributes>

    var body: some View {
        let attributes = context.attributes
        let day = SolarDay(date: attributes.start,
                           coordinate: attributes.coordinate,
                           timeZone: attributes.timeZone)
        HomeArc(day: day,
                hour: hourOfDay(context.state.now),
                events: [span(day)])
    }

    private func hourOfDay(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.attributes.timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    private func span(_ day: SolarDay) -> ClosedRange<Double> {
        let low = max(0, hourOfDay(context.attributes.start))
        let high = min(24, max(hourOfDay(context.attributes.end), low + 0.35))
        return low...high
    }
}

/// One dot, at the sun's height. Small enough for the minimal presentation and
/// still saying something: how high the mark sits is how high the sun is.
struct ActivityDot: View {
    let context: ActivityViewContext<DayActivityAttributes>

    var body: some View {
        let attributes = context.attributes
        let day = SolarDay(date: attributes.start,
                           coordinate: attributes.coordinate,
                           timeZone: attributes.timeZone)
        Canvas { drawing, size in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = attributes.timeZone
            let midnight = calendar.startOfDay(for: context.state.now)
            let hour = context.state.now.timeIntervalSince(midnight) / 3600
            let elevation = max(0, day.normalizedElevation(atHour: hour))

            let radius: CGFloat = 3
            let travel = size.height - radius * 2 - 1
            let y = size.height - radius - 0.5 - travel * CGFloat(elevation)
            drawing.fill(Path(ellipseIn: CGRect(x: size.width / 2 - radius, y: y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(Theme.ink))
        }
    }
}
