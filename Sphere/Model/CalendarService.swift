import EventKit
import Observation
import SwiftUI

/// Reads the user's calendar and hands the arc a flat list of occurrences.
///
/// Everything on the arc is a real `EKEvent`, so without full access the app
/// shows the brief's Universal mode: the sun curve and its markers, and nothing
/// of the user's.
@Observable
final class CalendarService {
    enum Access: Equatable {
        case undetermined
        case denied
        case granted
    }

    let store = EKEventStore()
    private(set) var access: Access
    private(set) var events: [CalendarEvent] = []

    init() {
        access = Self.currentAccess()
    }

    static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        // Write-only lets us add events but never read them back, which is not
        // enough for an arc whose whole job is showing what is already there.
        case .denied, .restricted, .writeOnly: .denied
        default: .undetermined
        }
    }

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // A thrown request is a refusal as far as the UI is concerned.
        }
        access = Self.currentAccess()
    }

    /// Loads every occurrence between two dates. Querying by predicate is what
    /// expands recurring events for us — matching by identifier would return
    /// the series once and lose every repeat.
    func load(from start: Date, to end: Date, anchor: Date) {
        guard access == .granted else {
            events = []
            return
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).map { event in
            let startHour = event.startDate.timeIntervalSince(anchor) / 3600
            let endHour = event.endDate.timeIntervalSince(anchor) / 3600
            return CalendarEvent(
                id: "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)",
                eventIdentifier: event.eventIdentifier ?? "",
                title: event.title ?? "Untitled",
                startHour: startHour,
                endHour: max(endHour, startHour),
                isAllDay: event.isAllDay,
                color: Self.color(for: event)
            )
        }
        .sorted { $0.startHour < $1.startHour }
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        store.event(withIdentifier: identifier)
    }

    private static func color(for event: EKEvent) -> Color {
        guard let cgColor = event.calendar?.cgColor else { return Theme.taskActive }
        return Color(cgColor: cgColor)
    }
}
