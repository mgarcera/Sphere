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

    /// One of the user's calendars, reduced to what the picker needs.
    struct Source: Identifiable, Equatable {
        let id: String
        let title: String
        let color: Color
    }

    let store = EKEventStore()
    private(set) var access: Access
    private(set) var events: [CalendarEvent] = []
    private(set) var sources: [Source] = []

    /// The real `EKEvent` behind each occurrence, kept from the fetch.
    ///
    /// This has to be the occurrence, not a lookup by identifier:
    /// `event(withIdentifier:)` hands back the first occurrence of a recurring
    /// series no matter which one you asked about, so editing or deleting from
    /// it silently acts on the wrong day.
    private var occurrences: [String: EKEvent] = [:]

    /// Which calendars the arc leaves out. Persisted, since a filter that
    /// resets every launch is no filter.
    private(set) var hiddenSourceIDs: Set<String>

    private static let hiddenKey = "hiddenCalendarIdentifiers"

    init() {
        access = Self.currentAccess()
        hiddenSourceIDs = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    func isVisible(_ source: Source) -> Bool { !hiddenSourceIDs.contains(source.id) }

    func setVisible(_ visible: Bool, for source: Source) {
        if visible { hiddenSourceIDs.remove(source.id) } else { hiddenSourceIDs.insert(source.id) }
        UserDefaults.standard.set(Array(hiddenSourceIDs), forKey: Self.hiddenKey)
    }

    func refreshSources() {
        guard access == .granted else { sources = []; return }
        sources = store.calendars(for: .event)
            .map { Source(id: $0.calendarIdentifier, title: $0.title, color: Color(cgColor: $0.cgColor)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var visibleCalendars: [EKCalendar]? {
        let calendars = store.calendars(for: .event).filter { !hiddenSourceIDs.contains($0.calendarIdentifier) }
        // nil means every calendar; an empty array would mean every calendar
        // too, which is the opposite of what hiding them all should do.
        return hiddenSourceIDs.isEmpty ? nil : calendars
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
    /// After an edit the store's cache still holds the old picture, so a
    /// straight re-read reports the same events it did before — a saved event
    /// went 10 to 10 in the trace. Resetting first is what makes a write
    /// visible.
    func reloadAfterEdit(from start: Date, to end: Date, anchor: Date) {
        store.reset()
        load(from: start, to: end, anchor: anchor)
    }

    func load(from start: Date, to end: Date, anchor: Date) {
        guard access == .granted else {
            events = []
            occurrences = [:]
            return
        }

        if hiddenSourceIDs.isEmpty == false, visibleCalendars?.isEmpty == true {
            events = []
            occurrences = [:]
            return
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: visibleCalendars)
        var found: [String: EKEvent] = [:]

        events = store.events(matching: predicate).map { event in
            let startHour = event.startDate.timeIntervalSince(anchor) / 3600
            let endHour = event.endDate.timeIntervalSince(anchor) / 3600
            let id = "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)"
            found[id] = event
            return CalendarEvent(
                id: id,
                eventIdentifier: event.eventIdentifier ?? "",
                title: event.title ?? "Untitled",
                startHour: startHour,
                endHour: max(endHour, startHour),
                isAllDay: event.isAllDay,
                color: Self.color(for: event)
            )
        }
        .sorted { $0.startHour < $1.startHour }

        occurrences = found
    }

    /// The nearest timed event outside the drawn window.
    ///
    /// The arc only loads a day either side, so the chevrons could not see an
    /// event further out than that — and because a failed jump leaves the focus
    /// where it is, nothing then triggered a reload either. It was a dead end
    /// with no way back.
    func nearestTimedEvent(_ direction: Direction, from date: Date, withinDays days: Int = 45) -> EKEvent? {
        guard access == .granted else { return nil }
        let span = Double(days) * 86_400
        let window = direction == .forward
            ? (date, date.addingTimeInterval(span))
            : (date.addingTimeInterval(-span), date)

        let predicate = store.predicateForEvents(withStart: window.0, end: window.1,
                                                 calendars: visibleCalendars)
        let found = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { direction == .forward ? $0.startDate > date : $0.startDate < date }
            .sorted { $0.startDate < $1.startDate }

        return direction == .forward ? found.first : found.last
    }

    enum Direction { case forward, back }

    /// The exact occurrence the arc is showing, so an edit or a delete lands on
    /// the day you are looking at.
    func occurrence(for id: CalendarEvent.ID) -> EKEvent? { occurrences[id] }

    private static func color(for event: EKEvent) -> Color {
        guard let cgColor = event.calendar?.cgColor else { return Theme.taskActive }
        return Color(cgColor: cgColor)
    }
}
