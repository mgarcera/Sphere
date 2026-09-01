import Foundation
import Observation

/// The single screen's state. `focusHour` is what the wheel moves; `realNow`
/// is what MENU returns to.
@Observable
final class DayModel {
    private(set) var day: SolarDay
    private(set) var realNow: Date

    /// Local decimal hour under the time dot, 0..24. The dot is pinned to the
    /// centre of the screen, so this is also what the arc pans to.
    var focusHour: Double

    var tasks: [DayTask] = []

    /// One full rotation of the wheel covers four hours. Crossing a whole day
    /// takes six turns, which is the intended pace.
    static let hoursPerRotation: Double = 4

    /// Width of the visible slice of the day.
    static let windowHours: Double = 3

    init(date: Date = .now, coordinate: Coordinate = .chicago, timeZone: TimeZone = .autoupdatingCurrent) {
        self.day = SolarDay(date: date, coordinate: coordinate, timeZone: timeZone)
        self.realNow = date
        self.focusHour = Self.decimalHour(of: date, in: timeZone)
    }

    var nowHour: Double {
        Self.decimalHour(of: realNow, in: .autoupdatingCurrent)
    }

    /// True when the dot is sitting on the real current time, within a minute.
    var isFocusedOnNow: Bool {
        abs(focusHour - nowHour) < 1.0 / 60
    }

    /// Turn the wheel. `rotations` is signed: positive is clockwise, later.
    func scrub(byRotations rotations: Double) {
        focusHour = (focusHour + rotations * Self.hoursPerRotation).clamped(to: 0...24)
    }

    func returnToNow() {
        focusHour = nowHour
    }

    func tick(_ date: Date = .now) {
        let wasOnNow = isFocusedOnNow
        realNow = date
        if wasOnNow { focusHour = nowHour }
    }

    private static func decimalHour(of date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0)
            + Double(parts.minute ?? 0) / 60
            + Double(parts.second ?? 0) / 3600
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
