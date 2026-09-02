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
        /// The last time the app was able to say where the sun was. The clock
        /// and the progress bar keep running without it; the dot does not.
        var now: Date
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
