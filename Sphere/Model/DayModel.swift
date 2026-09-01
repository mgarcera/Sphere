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

    /// A task names the title only while the dot is this close to it. There is
    /// deliberately no "next upcoming task" fallback — the title is driven by
    /// proximity, not by the schedule.
    static let proximityWindowHours: Double = 15.0 / 60

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

    // MARK: - Tasks

    /// The task under the dot, if the dot is within fifteen minutes of one.
    /// Nearest wins when two are in range.
    var activeTask: DayTask? {
        tasks
            .filter { abs($0.hour - focusHour) <= Self.proximityWindowHours }
            .min { abs($0.hour - focusHour) < abs($1.hour - focusHour) }
    }

    @discardableResult
    func addTask(label: String) -> DayTask? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = DayTask(hour: focusHour, label: trimmed)
        tasks.append(task)
        tasks.sort { $0.hour < $1.hour }
        return task
    }

    /// A few seconds of slack, so tapping next while parked on a task moves to
    /// the one after it rather than re-selecting where you already are.
    private static let jumpEpsilon: Double = 1.0 / 600

    var nextTask: DayTask? {
        tasks.first { $0.hour > focusHour + Self.jumpEpsilon }
    }

    var previousTask: DayTask? {
        tasks.last { $0.hour < focusHour - Self.jumpEpsilon }
    }

    /// Both jumps land on the task's hour exactly. They do nothing at the ends
    /// of the list rather than wrapping around.
    func jumpToNextTask() {
        if let next = nextTask { focusHour = next.hour }
    }

    func jumpToPreviousTask() {
        if let previous = previousTask { focusHour = previous.hour }
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
