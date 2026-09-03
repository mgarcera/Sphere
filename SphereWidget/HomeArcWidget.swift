import SwiftUI
import WidgetKit

/// The day on the home screen, in the app's own ink rather than the lock
/// screen's vibrancy.
///
/// Same arc, same capsules, same stem. What changes with size is how much
/// context fits around it: small carries the next event, medium adds where you
/// are and when the sun comes and goes.
struct HomeArcWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HomeDayArc", provider: ArcProvider()) { entry in
            HomeArcView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Day")
        .description("The sun's arc, your events, and where you are in the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomeArcView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ArcEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            let day = SolarDay(date: entry.date,
                               coordinate: snapshot.coordinate,
                               timeZone: snapshot.timeZone)
            VStack(alignment: .leading, spacing: 0) {
                header(snapshot)

                Spacer(minLength: 10)

                HomeArc(day: day, hour: hour(snapshot.timeZone), events: spans(snapshot))
                    .frame(height: family == .systemMedium ? 62 : 48)
            }
        } else {
            Text("Open Sphere")
                .font(.footnote)
                .foregroundStyle(Theme.mutedLight)
        }
    }

    @ViewBuilder
    private func header(_ snapshot: SphereSnapshot) -> some View {
        if let title = snapshot.nextEventTitle, let start = snapshot.nextEventStart,
           start > entry.date {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mutedLight)
                Text(title)
                    .font(.display(family == .systemMedium ? 19 : 16))
                    .foregroundStyle(Theme.ink)
                    // Two lines on both now. Medium gave up the sun's times for
                    // the room, and a title that fits is worth more than a pair
                    // of readings the arc already draws.
                    .lineLimit(2)
            }
        }
        // Nothing coming, nothing said. An empty day should look empty.
    }

    private func hour(_ zone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return entry.date.timeIntervalSince(calendar.startOfDay(for: entry.date)) / 3600
    }

    private func spans(_ snapshot: SphereSnapshot) -> [ArcSpan] {
        guard let events = snapshot.events else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        let midnight = calendar.startOfDay(for: entry.date)

        return events.compactMap { event in
            let start = event.start.timeIntervalSince(midnight) / 3600
            let end = event.end.timeIntervalSince(midnight) / 3600
            guard end > 0, start < 24 else { return nil }
            let low = max(0, start)
            return ArcSpan(hours: low...min(24, max(end, low + 0.35)),
                           color: event.color?.swiftUI)
        }
    }
}

/// The lock screen's arc in the app's palette. Three tiers again: the day
/// faintest, events on it, the sun brightest and carrying the stem.
/// One event on the arc: where it sits, and the calendar it came from.
struct ArcSpan {
    let hours: ClosedRange<Double>
    /// Nil where the snapshot predates colours travelling, which is the only
    /// time the flat task colour is still used.
    let color: Color?
}

struct HomeArc: View {
    let day: SolarDay
    let hour: Double
    var events: [ArcSpan] = []
    /// Drawn at full strength while the rest of the day sits back, so an
    /// overview still says which one you are in.
    var highlight: ClosedRange<Double>?

    var body: some View {
        Canvas { context, size in
            let baseline = size.height - 1
            let peak = size.height - 3

            func y(_ h: Double) -> CGFloat {
                baseline - CGFloat(max(0, day.normalizedElevation(atHour: h))) * peak
            }
            func x(_ h: Double) -> CGFloat { size.width * CGFloat(h / 24) }

            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: baseline))
            horizon.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(horizon, with: .color(Theme.hairline), style: StrokeStyle(lineWidth: 1))

            var curve = Path()
            curve.move(to: CGPoint(x: 0, y: y(0)))
            for step in 1...96 {
                let h = Double(step) / 4
                curve.addLine(to: CGPoint(x: x(h), y: y(h)))
            }
            context.stroke(curve, with: .color(Theme.mutedLight),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

            for span in events {
                let hours = span.hours
                var capsule = Path()
                let steps = max(2, Int((hours.upperBound - hours.lowerBound) * 4))
                for step in 0...steps {
                    let h = hours.lowerBound
                        + (hours.upperBound - hours.lowerBound) * Double(step) / Double(steps)
                    let point = CGPoint(x: x(h), y: y(h))
                    if step == 0 { capsule.move(to: point) } else { capsule.addLine(to: point) }
                }
                let isCurrent = highlight.map { abs($0.lowerBound - hours.lowerBound) < 0.01 } ?? false
                // The calendar's own colour, the same as the app draws it in,
                // and at the same two strengths: full for the one you are in,
                // held back for the rest of the day.
                let tint = span.color ?? (isCurrent ? Theme.taskActive : Theme.taskInactive)
                context.stroke(capsule,
                               with: .color(tint.opacity(isCurrent ? 1 : 0.72)),
                               style: StrokeStyle(lineWidth: isCurrent ? 4 : 2.6, lineCap: .round))
            }

            let dot = CGPoint(x: x(hour), y: y(hour))
            var stem = Path()
            stem.move(to: dot)
            stem.addLine(to: CGPoint(x: dot.x, y: baseline))
            context.stroke(stem, with: .color(Theme.hairlineSoft), style: StrokeStyle(lineWidth: 1))

            context.fill(Path(ellipseIn: CGRect(x: dot.x - 3.2, y: dot.y - 3.2,
                                                width: 6.4, height: 6.4)),
                         with: .color(Theme.ink))
        }
    }
}
