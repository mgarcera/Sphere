import Foundation
import Observation

/// The screen's state.
///
/// Time is one unbounded axis, not a day: `focusHour` counts hours from
/// `anchor` (local midnight at launch), so turning the wheel past midnight
/// carries into the next or previous day with no clamp and no second control.
///
/// Note the grid is a flat 24 hours per day. On the two DST days a year the
/// arc will sit an hour off; the sun geometry itself stays correct because
/// each day's `SolarDay` is built from a real `Date`.
@Observable
final class DayModel {
    let anchor: Date
    let coordinate: Coordinate
    let timeZone: TimeZone

    /// Hours from `anchor`, unbounded in both directions.
    var focusHour: Double
    private(set) var realNow: Date

    private var calendar: Calendar
    private var solarDays: [Int: SolarDay] = [:]

    /// One full rotation of the wheel covers four hours.
    static let hoursPerRotation: Double = 4

    /// Width of the visible slice.
    static let windowHours: Double = 3

    init(now: Date = .now, coordinate: Coordinate = .chicago, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.anchor = calendar.startOfDay(for: now)
        self.realNow = now
        self.focusHour = now.timeIntervalSince(calendar.startOfDay(for: now)) / 3600
    }

    // MARK: - Time

    /// Which day the dot is on, counting from the anchor. Negative is the past.
    var dayIndex: Int { Int(floor(focusHour / 24)) }

    var focusDate: Date { anchor.addingTimeInterval(focusHour * 3600) }

    var nowHour: Double { realNow.timeIntervalSince(anchor) / 3600 }

    var isFocusedOnNow: Bool { abs(focusHour - nowHour) < 1.0 / 60 }

    var isFocusedOnToday: Bool { dayIndex == Int(floor(nowHour / 24)) }

    func date(forDayIndex index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: anchor) ?? anchor
    }

    /// Cached per day, since the wheel crosses a boundary far less often than
    /// it moves.
    func solarDay(_ index: Int) -> SolarDay {
        if let cached = solarDays[index] { return cached }
        let day = SolarDay(date: date(forDayIndex: index), coordinate: coordinate, timeZone: timeZone)
        solarDays[index] = day
        return day
    }

    /// Height of the curve at any absolute hour, picking the right day. This is
    /// what makes the arc read as one continuous curve across midnight — the
    /// sun's elevation genuinely is continuous there, so nothing needs a seam.
    func normalizedElevation(atAbsoluteHour hour: Double) -> Double {
        let index = Int(floor(hour / 24))
        return solarDay(index).normalizedElevation(atHour: hour - Double(index) * 24)
    }

    func scrub(byRotations rotations: Double) {
        focusHour += rotations * Self.hoursPerRotation
    }

    func returnToNow() {
        focusHour = nowHour
    }

    func tick(_ date: Date = .now) {
        let wasOnNow = isFocusedOnNow
        realNow = date
        if wasOnNow { focusHour = nowHour }
    }

    // MARK: - Events

    var events: [CalendarEvent] = []

    /// Only events with a place on the arc. All-day events have no hour and
    /// belong somewhere else on screen.
    var timedEvents: [CalendarEvent] { events.filter { !$0.isAllDay } }

    var allDayEvents: [CalendarEvent] {
        events.filter { $0.isAllDay && Int(floor($0.startHour / 24)) == dayIndex }
    }

    /// The event the dot is inside. Real calendars overlap constantly, so the
    /// shortest one wins: a standup sitting inside a focus block is what you
    /// are actually doing.
    var activeEvent: CalendarEvent? {
        timedEvents
            .filter { $0.contains(focusHour) }
            .min { $0.durationHours < $1.durationHours }
    }

    private static let jumpEpsilon: Double = 1.0 / 600

    var nextEvent: CalendarEvent? {
        timedEvents.first { $0.startHour > focusHour + Self.jumpEpsilon }
    }

    var previousEvent: CalendarEvent? {
        timedEvents.last { $0.startHour < focusHour - Self.jumpEpsilon }
    }

    func jumpToNextEvent() {
        if let next = nextEvent { focusHour = next.startHour }
    }

    func jumpToPreviousEvent() {
        if let previous = previousEvent { focusHour = previous.startHour }
    }

    /// The span the arc can currently show, a day either side of the focus so
    /// the window is never short of curve or events.
    var loadedRange: (start: Date, end: Date) {
        (date(forDayIndex: dayIndex - 1), date(forDayIndex: dayIndex + 2))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
