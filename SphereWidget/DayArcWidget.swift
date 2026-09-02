import SwiftUI
import WidgetKit

struct ArcEntry: TimelineEntry {
    let date: Date
    let snapshot: SphereSnapshot?
}

/// Where the sun is, on the lock screen.
///
/// Almost nothing here needs refreshing. A widget gets a few dozen reloads a
/// day, but the sun's position is arithmetic, so the whole afternoon can be
/// handed over in one timeline and the system flips through it for free. Only
/// the next event goes stale, and the app reloads the timeline when it changes.
struct ArcProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcEntry {
        ArcEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArcEntry) -> Void) {
        completion(ArcEntry(date: .now, snapshot: SphereSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArcEntry>) -> Void) {
        let snapshot = SphereSnapshot.read()
        let now = Date()
        let entries = stride(from: 0, through: 60 * 8, by: 10).map { minutes in
            ArcEntry(date: now.addingTimeInterval(Double(minutes) * 60), snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DayArcWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayArc", provider: ArcProvider()) { entry in
            DayArcView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Day arc")
        .description("Where the sun is, and what is next.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct DayArcView: View {
    let entry: ArcEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            let day = SolarDay(date: entry.date,
                               coordinate: snapshot.coordinate,
                               timeZone: snapshot.timeZone)
            VStack(alignment: .leading, spacing: 3) {
                LockArc(day: day, hour: hourOfDay(snapshot.timeZone))
                    .frame(height: 26)
                Text(caption(snapshot))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
        } else {
            Text("Open Sphere")
                .font(.system(size: 13, weight: .medium))
        }
    }

    /// On the place's clock, the same as the app: a coordinate without its
    /// timezone is what once put a Californian sunrise on Central time.
    private func hourOfDay(_ zone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let midnight = calendar.startOfDay(for: entry.date)
        return entry.date.timeIntervalSince(midnight) / 3600
    }

    /// The name alone. The time is already on the lock screen, and where the
    /// dot sits against the event says when better than repeating a clock does.
    private func caption(_ snapshot: SphereSnapshot) -> String {
        guard let title = snapshot.nextEventTitle, let start = snapshot.nextEventStart,
              start > entry.date else { return snapshot.placeName }
        return title
    }
}

/// The day as one hill, with the dot where the sun is.
///
/// Not the app's arc shrunk. That one is 24 hours across eight screen widths
/// and reads nearly flat; squeezed into a lock-screen accessory the same day
/// becomes a proper curve, which is the only reason it is legible this small.
struct LockArc: View {
    let day: SolarDay
    let hour: Double

    var body: some View {
        Canvas { context, size in
            let baseline = size.height - 1
            let peak = size.height - 2

            func y(_ h: Double) -> CGFloat {
                baseline - CGFloat(max(0, day.normalizedElevation(atHour: h))) * peak
            }
            func x(_ h: Double) -> CGFloat { size.width * CGFloat(h / 24) }

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y(0)))
            for step in 1...96 {
                let h = Double(step) / 4
                path.addLine(to: CGPoint(x: x(h), y: y(h)))
            }
            context.stroke(path, with: .color(.white.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: baseline))
            ground.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(ground, with: .color(.white.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round))

            let dot = CGPoint(x: x(hour), y: y(hour))
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 2.6, y: dot.y - 2.6,
                                                width: 5.2, height: 5.2)),
                         with: .color(.white))
        }
    }
}
