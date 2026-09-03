import ActivityKit
import SwiftUI
import WidgetKit

/// The event you are in, on the lock screen and in the Dynamic Island.
///
/// An overview of the day, not a report on one event. A countdown was tried
/// and removed: a number falling towards zero is the one thing that turns a
/// calm surface into a deadline, and nothing else in this app ticks.
///
/// So it shows the whole arc with every event on it and the current one picked
/// out. That is also honest about what a Live Activity can do — it redraws only
/// when a new state is pushed, so anything that had to move on its own would
/// have to be the system's own timer, which is exactly the ticking thing.
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
                    Text(span(context))
                        .font(.system(size: 13))
                        .monospacedDigit()
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
                Text(context.attributes.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(maxWidth: 76)
            } minimal: {
                ActivityDot(context: context)
            }
        }
    }

    /// When it runs, not how long is left. The same two clock times the header
    /// shows, which state the fact without counting down to it.
    private func span(_ context: ActivityViewContext<DayActivityAttributes>) -> String {
        let zone = context.attributes.timeZone
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = zone
        return "\(context.attributes.start.formatted(style)) – \(context.attributes.end.formatted(style))"
    }

    private func lockScreen(_ context: ActivityViewContext<DayActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.title)
                    .font(.display(19))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(span(context))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mutedLight)
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
                events: spans(),
                highlight: current())
    }

    private func hourOfDay(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.attributes.timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    /// Every event of the day, so the activity is the day rather than the one
    /// event that happens to be running.
    private func spans() -> [ClosedRange<Double>] {
        context.state.events.compactMap { event in
            let start = hourOfDay(event.start)
            let end = hourOfDay(event.end)
            guard end > 0, start < 24 else { return nil }
            let low = max(0, start)
            return low...min(24, max(end, low + 0.35))
        }
    }

    private func current() -> ClosedRange<Double> {
        let low = max(0, hourOfDay(context.attributes.start))
        return low...min(24, max(hourOfDay(context.attributes.end), low + 0.35))
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
