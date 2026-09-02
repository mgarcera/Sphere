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

                if family == .systemMedium {
                    Spacer(minLength: 8)
                    sunLine(day)
                }
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
                    .lineLimit(family == .systemMedium ? 1 : 2)
            }
        } else {
            Text(snapshot.placeName)
                .font(.display(family == .systemMedium ? 19 : 16))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
    }

    /// Sunrise and sunset under the curve they belong to, so the arc is labelled
    /// rather than annotated.
    private func sunLine(_ day: SolarDay) -> some View {
        HStack {
            Text(day.sunrise.map(clock) ?? "—")
            Spacer()
            Text(day.sunset.map(clock) ?? "—")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mutedLight)
    }

    private func clock(_ hour: Double) -> String {
        let total = Int((hour * 60).rounded())
        let h24 = (total / 60) % 24
        let minute = total % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, minute, h24 < 12 ? "AM" : "PM")
    }

    private func hour(_ zone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return entry.date.timeIntervalSince(calendar.startOfDay(for: entry.date)) / 3600
    }

    private func spans(_ snapshot: SphereSnapshot) -> [ClosedRange<Double>] {
        guard let events = snapshot.events else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        let midnight = calendar.startOfDay(for: entry.date)

        return events.compactMap { event in
            let start = event.start.timeIntervalSince(midnight) / 3600
            let end = event.end.timeIntervalSince(midnight) / 3600
            guard end > 0, start < 24 else { return nil }
            let low = max(0, start)
            return low...min(24, max(end, low + 0.35))
        }
    }
}

/// The lock screen's arc in the app's palette. Three tiers again: the day
/// faintest, events on it, the sun brightest and carrying the stem.
struct HomeArc: View {
    let day: SolarDay
    let hour: Double
    var events: [ClosedRange<Double>] = []

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
                var capsule = Path()
                let steps = max(2, Int((span.upperBound - span.lowerBound) * 4))
                for step in 0...steps {
                    let h = span.lowerBound
                        + (span.upperBound - span.lowerBound) * Double(step) / Double(steps)
                    let point = CGPoint(x: x(h), y: y(h))
                    if step == 0 { capsule.move(to: point) } else { capsule.addLine(to: point) }
                }
                context.stroke(capsule, with: .color(Theme.taskActive),
                               style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
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
