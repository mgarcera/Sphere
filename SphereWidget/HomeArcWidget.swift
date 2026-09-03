import SwiftUI
import WidgetKit

/// The day on the home screen, in the app's own ink rather than the lock
/// screen's vibrancy.
///
/// Same arc, same capsules, same stem. What changes with size is how much
/// context fits around it: small carries the next event, medium adds when the
/// sun comes and goes, and large is the only one with room for the sky.
struct HomeArcWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HomeDayArc", provider: ArcProvider()) { entry in
            HomeArcView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Day")
        .description("The sun's arc, your events, and where you are in the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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

                if family == .systemLarge {
                    SkyArc(day: day,
                           hour: hour(snapshot.timeZone),
                           events: spans(snapshot),
                           sky: sky(snapshot),
                           daySeed: daySeed)
                } else {
                    HomeArc(day: day, hour: hour(snapshot.timeZone), events: spans(snapshot))
                        .frame(height: family == .systemMedium ? 62 : 48)
                }

                if family != .systemSmall {
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
                    .font(.display(family == .systemSmall ? 16 : 19))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(family == .systemSmall ? 2 : 1)
            }
        }
        // Nothing coming, nothing said. An empty day should look empty.
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

    /// The day's hours, or none: past its lifetime, or on a day the app never
    /// wrote, the sky is left out rather than guessed at.
    private func sky(_ snapshot: SphereSnapshot) -> [SkyHour] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        return snapshot.sky(on: entry.date, calendar: calendar)
    }

    /// Stable per day, so the clouds are in the same places at 9am and at 3pm
    /// and only a new day redraws them somewhere else.
    private var daySeed: Int {
        Int(entry.date.timeIntervalSince1970 / 86_400)
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
                var capsule = Path()
                let steps = max(2, Int((span.upperBound - span.lowerBound) * 4))
                for step in 0...steps {
                    let h = span.lowerBound
                        + (span.upperBound - span.lowerBound) * Double(step) / Double(steps)
                    let point = CGPoint(x: x(h), y: y(h))
                    if step == 0 { capsule.move(to: point) } else { capsule.addLine(to: point) }
                }
                let isCurrent = highlight.map { abs($0.lowerBound - span.lowerBound) < 0.01 } ?? false
                context.stroke(capsule,
                               with: .color(isCurrent ? Theme.taskActive : Theme.taskInactive),
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

/// The large tile: the same arc with the day's sky standing over it.
///
/// The sky is the whole reason the large family exists. Everything else the
/// tile shows fits in a medium, and the decks need vertical room that medium
/// does not have.
struct SkyArc: View {
    let day: SolarDay
    let hour: Double
    let events: [ClosedRange<Double>]
    let sky: [SkyHour]
    let daySeed: Int

    /// Room above the curve for the three decks, and the arc's own box under
    /// it. `SkyScale.widget` is what makes these numbers enough: the decks come
    /// in to a third of the app's standoff and the lobes get wider in hours,
    /// because 24 hours across a widget is 14 points an hour.
    static let room: CGFloat = 76
    static let arcHeight: CGFloat = 72
    static var blockHeight: CGFloat { room + arcHeight }

    /// `HomeArc` puts its baseline a point off the bottom of its box and gives
    /// the curve the rest, so the sky is drawn against a box shaped the same
    /// way — the full height at peak, over `arcHeight - 3`. Anything else and
    /// the clouds follow a curve the visible arc never takes.
    private var geometry: ArcGeometry {
        ArcGeometry(peakFraction: 1, skyGutter: Self.room, labelGutter: 0)
    }

    private var curveHeight: CGFloat { Self.arcHeight - 3 }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    // Declaration order is draw order, furthest deck first, and
                    // the clear sky sits behind the clouds of its own deck so a
                    // cloud filling with the background covers the stars in it.
                    ForEach(SkyContinuous.Deck.allCases) { deck in
                        ClearSky(day: day,
                                 width: proxy.size.width,
                                 height: curveHeight,
                                 hours: sky,
                                 daySeed: daySeed,
                                 deck: deck,
                                 scale: .widget,
                                 geometry: geometry,
                                 blinkStep: 0)

                        SkyContinuous(day: day,
                                      width: proxy.size.width,
                                      height: curveHeight,
                                      hours: sky,
                                      daySeed: daySeed,
                                      deck: deck,
                                      scale: .widget,
                                      geometry: geometry)
                    }
                }
                .frame(width: proxy.size.width,
                       height: geometry.totalHeight(curveHeight),
                       alignment: .topLeading)
                // The sky's baseline is its own bottom edge; the arc's sits a
                // point above its box's, so the two are lined up here rather
                // than left to coincide.
                .padding(.bottom, 1)

                HomeArc(day: day, hour: hour, events: events)
                    .frame(height: Self.arcHeight)
            }
            .frame(width: proxy.size.width, height: Self.blockHeight, alignment: .bottom)
        }
        .frame(height: SkyArc.blockHeight)
    }
}
