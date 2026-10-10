import SwiftUI

/// The fictional days the App Store captures are set on.
///
/// Sphere draws from a real calendar, a real place and a real forecast, so the three scenes the
/// store set is built from cannot be reached by waiting: a storm at 11:54 on a Monday in July is
/// not something a capture run can ask the sky for. This supplies all three inputs instead, and
/// the app above it is the shipping app — same views, same layout, same drawing.
///
/// Fil does this with `-FilScreenshotMode` and a `DemoLibrary`; this is the same pattern, and the
/// reason for the pattern is the same: a capture harness that renders a SEPARATE view drifts from
/// the app it is advertising, one release at a time.
///
/// ```
/// xcrun simctl launch <device> com.smidgecraft.Sphere -SphereScreenshotScene morning
/// ```
enum DemoDay {
    static let launchArgument = "-SphereScreenshotMode"
    static let sceneArgument = "-SphereScreenshotScene"

    static var isEnabled: Bool { scene != nil }

    /// The scene named on the command line, if it names one. `-SphereScreenshotScene morning`
    /// arrives as two arguments, so the value is the one after the flag.
    static var scene: Scene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: sceneArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return Scene.named(arguments[index + 1])
    }

    struct Scene {
        let id: String
        /// Local time in Chicago. Sets the day the arc draws AND where the dot sits on it.
        let instant: Date
        let condition: SkyCondition
        /// Shown through the reader's own units, so these are the celsius behind 74°F, 68°F, 84°F.
        let celsius: Double
        let events: [DemoEvent]
        /// How overcast each deck is, which is what the clouds are drawn from.
        let cloud: (low: Double, mid: Double, high: Double)
        let precipitation: Double
        let cape: Double

        static func named(_ name: String) -> Scene? { all.first { $0.id == name } }

        static let all = [morning, night, storm]

        /// Shot one: inside an event, clear, with an all-day event in the header.
        static let morning = Scene(
            id: "morning",
            instant: at(2026, 8, 3, 10, 45),
            condition: .clear,
            celsius: 23.3,
            events: [
                DemoEvent(title: "Coffee with Asher", start: at(2026, 8, 3, 10, 30),
                          end: at(2026, 8, 3, 11, 30), isAllDay: false),
                DemoEvent(title: "Asher in town", start: at(2026, 8, 3, 0, 0),
                          end: at(2026, 8, 3, 0, 0), isAllDay: true),
            ],
            cloud: (0.22, 0.14, 0),
            precipitation: 0,
            cape: 0
        )

        /// Shot two: after midnight, so the sky is the night one and the moon is on the line.
        static let night = Scene(
            id: "night",
            instant: at(2026, 8, 19, 0, 12),
            condition: .partlyCloudy,
            celsius: 20,
            events: [],
            cloud: (0.38, 0.30, 0.10),
            precipitation: 0,
            cape: 0
        )

        /// Shot three: midday under a storm, which is the only one of the three that has to be
        /// invented — a real forecast will not hold still for a capture run.
        static let storm = Scene(
            id: "storm",
            instant: at(2026, 7, 27, 11, 54),
            condition: .thunderstorm,
            celsius: 28.9,
            events: [],
            cloud: (0.85, 0.75, 0.40),
            precipitation: 4.2,
            cape: 2_400
        )
    }

    struct DemoEvent {
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
    }

    static let timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
    static let coordinate = Coordinate.chicago

    private static func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                  hour: hour, minute: minute)) ?? .now
    }

    /// The model a capture run draws with. Outside a capture run this is the ordinary one.
    static func model() -> DayModel {
        guard let scene else { return DayModel() }
        return DayModel(now: scene.instant, coordinate: coordinate, timeZone: timeZone)
    }

    /// Fills in everything the live services would have fetched. Called instead of the launch
    /// loads, never alongside them, or the real forecast lands on top of the invented one.
    @MainActor
    static func apply(to model: DayModel, weather: WeatherService) -> Int {
        guard let scene else { return 0 }

        // Three days of sky, because the arc draws the day before and the day after as well.
        for offset in -1...1 {
            model.applySky(hours(for: scene, in: model, dayIndex: model.dayIndex + offset),
                           forDayIndex: model.dayIndex + offset)
        }

        weather.adopt(readings(for: scene))

        model.events = scene.events.map { event in
            CalendarEvent(
                id: "demo-\(event.title)",
                eventIdentifier: "demo-\(event.title)",
                title: event.title,
                startHour: event.start.timeIntervalSince(model.anchor) / 3600,
                endHour: max(event.end.timeIntervalSince(model.anchor) / 3600,
                             event.start.timeIntervalSince(model.anchor) / 3600),
                isAllDay: event.isAllDay,
                // The capsule green of the store set, which is a calendar colour rather than one
                // of the app's own: every event on the arc wears the colour of the calendar it
                // came from.
                color: Color(red: 0.36, green: 0.84, blue: 0.62)
            )
        }
        return scene.events.filter(\.isAllDay).count
    }

    private static func hours(for scene: Scene, in model: DayModel, dayIndex: Int) -> [SkyHour] {
        let day = model.solarDay(dayIndex)
        return (0..<24).map { hour in
            SkyHour(
                hour: hour,
                condition: scene.condition,
                isDaylight: day.elevation(atHour: Double(hour) + 0.5) >= 0,
                cloudLow: scene.cloud.low,
                cloudMid: scene.cloud.mid,
                cloudHigh: scene.cloud.high,
                precipitation: scene.precipitation,
                wind: 0,
                cape: scene.cape
            )
        }
    }

    /// Readings on the hour, for the three days the arc can reach.
    private static func readings(for scene: Scene) -> [WeatherHour] {
        let start = Date(timeIntervalSince1970:
                            (scene.instant.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        return (-48...48).map { offset in
            WeatherHour(
                date: start.addingTimeInterval(Double(offset) * 3600),
                condition: scene.condition,
                cloudLow: scene.cloud.low,
                cloudMid: scene.cloud.mid,
                cloudHigh: scene.cloud.high,
                precipitation: scene.precipitation,
                wind: 0,
                cape: scene.cape,
                celsius: scene.celsius
            )
        }
    }
}
