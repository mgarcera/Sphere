import Foundation

/// What the app hands the lock screen.
///
/// A widget runs in its own process with none of the app's services: no event
/// store, no location manager, no forecast. The sun it can work out for itself
/// from a coordinate and a clock, so only those travel and never the curve.
/// Anything it cannot compute — the next event — is written across as a result.
/// Just the span. The widget draws where an event sits on the day, not what it
/// says, so a title per event would be payload nobody reads.
struct SnapshotEvent: Codable, Hashable {
    var start: Date
    var end: Date
}

/// One day's drawn sky, with the day it belongs to.
///
/// The day travels with the hours because a widget's timeline runs eight hours
/// forward and crosses midnight, and a sky drawn for yesterday under today's
/// curve is worse than no sky. Two days are written for the same reason.
struct SnapshotSky: Codable, Equatable {
    var dayStart: Date
    var hours: [SkyHour]
}

struct SphereSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var placeName: String
    var nextEventTitle: String?
    var nextEventStart: Date?
    /// Optional so a snapshot written before this existed still decodes; a
    /// missing key on a non-optional throws and the widget would go blank
    /// until the app happened to run again.
    var events: [SnapshotEvent]?
    /// Today and tomorrow, as the app last had them. The forecast is the one
    /// thing here that cannot be computed from a coordinate and a clock, and
    /// unlike the next event it is not a single fact, so it is the only real
    /// payload in this struct: about forty-eight hours at a few hundred bytes
    /// each.
    var sky: [SnapshotSky]?
    /// When the forecast was fetched, so a widget can decline to draw one that
    /// has been sitting in the group container since the app was last opened.
    var skyFetchedAt: Date?

    /// Past this the sky is dropped rather than drawn. A forecast for the right
    /// day is still a forecast, but half a day after it was fetched it is the
    /// app's memory rather than the weather, and the widgets already have a
    /// rule for that: where there is nothing to say, say nothing.
    static let skyLifetime: TimeInterval = 12 * 3600

    /// The hours for the day `date` falls in, or none if there are none fresh
    /// enough to draw.
    func sky(on date: Date, calendar: Calendar) -> [SkyHour] {
        guard let sky, let fetched = skyFetchedAt,
              date.timeIntervalSince(fetched) < Self.skyLifetime else { return [] }
        let start = calendar.startOfDay(for: date)
        return sky.first { calendar.isDate($0.dayStart, inSameDayAs: start) }?.hours ?? []
    }

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }

    /// Both processes reach the same defaults through the group; neither can
    /// see the other's own.
    static let appGroup = "group.com.smidgecraft.Sphere"
    private static let key = "sphereSnapshot"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func write(_ snapshot: SphereSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store?.set(data, forKey: key)
    }

    static func read() -> SphereSnapshot? {
        guard let data = store?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SphereSnapshot.self, from: data)
    }
}
