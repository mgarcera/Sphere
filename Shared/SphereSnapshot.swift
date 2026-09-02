import Foundation

/// What the app hands the lock screen.
///
/// A widget runs in its own process with none of the app's services: no event
/// store, no location manager, no forecast. The sun it can work out for itself
/// from a coordinate and a clock, so only those travel and never the curve.
/// Anything it cannot compute — the next event — is written across as a result.
struct SphereSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var placeName: String
    var nextEventTitle: String?
    var nextEventStart: Date?

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
