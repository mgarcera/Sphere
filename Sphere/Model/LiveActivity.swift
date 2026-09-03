import ActivityKit
import Foundation

/// Runs one activity for the event you are inside.
///
/// Started when an event contains the real now and ended when it stops doing
/// so, which is the only bound an activity can have here: the system ends one
/// after about eight hours regardless, and an event has its own end anyway.
@MainActor
enum LiveActivity {
    private static var current: Activity<DayActivityAttributes>?

    static func sync(event: CalendarEvent?, day: [CalendarEvent], anchor: Date, now: Date,
                     coordinate: Coordinate, timeZone: TimeZone) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let spans = day.map {
            SnapshotEvent(start: anchor.addingTimeInterval($0.startHour * 3600),
                          end: anchor.addingTimeInterval($0.endHour * 3600),
                          color: $0.snapshotColor)
        }

        guard let event else { return end() }
        let start = anchor.addingTimeInterval(event.startHour * 3600)
        let end = anchor.addingTimeInterval(event.endHour * 3600)
        guard start <= now, now < end else { return Self.end() }

        // Already running for this event: move the dot and leave it alone.
        if let current, current.attributes.title == event.title,
           abs(current.attributes.start.timeIntervalSince(start)) < 1 {
            Task {
                await current.update(.init(state: .init(now: now, events: spans), staleDate: nil))
            }
            return
        }

        Self.end()
        current = try? Activity.request(
            attributes: DayActivityAttributes(
                title: event.title,
                start: start,
                end: end,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZoneIdentifier: timeZone.identifier
            ),
            content: .init(state: .init(now: now, events: spans), staleDate: nil)
        )
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
