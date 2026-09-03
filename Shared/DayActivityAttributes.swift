import ActivityKit
import Foundation

/// An event, while it is happening.
///
/// The static half is everything the arc needs, since none of it changes for
/// the length of one event: where you are, which clock, and the span the event
/// occupies. Only `now` moves, and it moves only when the app is running to
/// push it — a Live Activity cannot animate a drawn mark on its own.
struct DayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The last time the app was able to say where the sun was. Nothing
        /// else in the activity moves, so this holding still is the whole
        /// consequence of not being pushed.
        var now: Date
        /// The rest of the day, so the activity is an overview rather than a
        /// report on one event. In the state and not the attributes, since the
        /// day can gain an event while this one is still running.
        var events: [SnapshotEvent]
    }

    var title: String
    var start: Date
    var end: Date
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String

    var coordinate: Coordinate { Coordinate(latitude: latitude, longitude: longitude) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent }
}
