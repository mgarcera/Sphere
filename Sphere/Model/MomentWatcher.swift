import Foundation
import os

/// Decides when the day's bells ring, and keeps that decision out of the view.
///
/// Three rules, in the order they matter:
///
/// 1. **A crossing is the event.** The bell belongs to a place on the day, not
///    to the gesture, so it rings when `focusHour` passes the hour of sunrise,
///    solar noon, sunset, or the leading edge of weather. A whole day scrubbed
///    end to end therefore contains at most four bells, which is the real
///    reason this cannot become obnoxious. The rate gate below is a refinement,
///    not the mechanism.
///
/// 2. **Re-arm by distance, not by time.** Rocking the wheel across sunrise
///    would otherwise ring it on every pass. After a bell, that moment stays
///    silent until the focus has moved `rearmHours` away from it. A time-based
///    lockout was the alternative and is worse: a slow deliberate re-cross
///    inside the window would go silent, which reads as broken rather than as
///    restrained.
///
/// 3. **Suppress a fling.** A bell you have already scrolled past is noise. The
///    threshold is in hours of day per second of wall clock.
@MainActor
struct MomentWatcher {
    /// How far the focus must travel from a moment before that moment can ring
    /// again. Half an hour of day: far enough that a wobbling thumb is silent,
    /// near enough that a deliberate second look rings.
    static let rearmHours: Double = 0.5

    /// PROVISIONAL — not yet measured on a real thumb, which is the whole point
    /// of `logRate`. Above this many hours of day per second, a crossing is
    /// treated as a fling and stays silent. Replace with a value read from the
    /// gap between the two distributions rather than guessed at.
    static var maxRate: Double = 8

    /// Tagged so a scrub session can be grepped out of the device console:
    ///   log stream --predicate 'subsystem == "com.smidgecraft.Sphere"' | grep MOMENT
    private static let log = Logger(subsystem: "com.smidgecraft.Sphere", category: "MOMENT")

    private var lastHour: Double?
    private var lastSampledAt: Date?
    private var lastWeather = false
    private var armed: Set<Sounds.Moment> = Set(Sounds.Moment.allCases)

    /// Re-sync without ringing. Every way of moving the dot a long way at once —
    /// a chevron, the arc tapped to return to now, a day picked — lands here
    /// first, so a jump across the whole day does not ring everything it passed.
    mutating func resync(to hour: Double, weatherPresent: Bool) {
        lastHour = hour
        lastSampledAt = nil
        lastWeather = weatherPresent
        armed = Set(Sounds.Moment.allCases)
    }

    /// - Parameters:
    ///   - solarHours: absolute hour of each solar moment, already offset by the day.
    ///   - weatherPresent: whether the focus hour sits inside weather.
    /// - Returns: the moments to ring, usually none.
    mutating func crossings(movingTo hour: Double,
                            at now: Date,
                            solarHours: [Sounds.Moment: Double],
                            weatherPresent: Bool) -> [Sounds.Moment] {
        defer {
            lastHour = hour
            lastSampledAt = now
            lastWeather = weatherPresent
        }
        guard let previous = lastHour else { return [] }

        // No elapsed time means no rate to judge, which happens on the first
        // sample after a resync. Let it through rather than guessing.
        let rate: Double
        if let at = lastSampledAt, now.timeIntervalSince(at) > 0 {
            rate = abs(hour - previous) / now.timeIntervalSince(at)
        } else {
            rate = 0
        }

        var ringing: [Sounds.Moment] = []

        for (moment, eventHour) in solarHours {
            // Re-arm first, so a moment left behind this sample can ring on the
            // next pass rather than waiting an extra one.
            if abs(hour - eventHour) > Self.rearmHours { armed.insert(moment) }
            let crossed = (previous < eventHour && hour >= eventHour)
                       || (previous > eventHour && hour <= eventHour)
            guard crossed, armed.contains(moment) else { continue }
            Self.log.info("crossed \(moment.rawValue, privacy: .public) rate=\(rate, format: .fixed(precision: 2)) fired=\(rate <= Self.maxRate, privacy: .public)")
            guard rate <= Self.maxRate else { continue }
            armed.remove(moment)
            ringing.append(moment)
        }

        // Weather is a region, not an instant, so its crossing is the leading
        // edge: dry on the last sample and wet on this one. Leaving re-arms it.
        if !weatherPresent { armed.insert(.weather) }
        if weatherPresent, !lastWeather, armed.contains(.weather) {
            Self.log.info("crossed weather rate=\(rate, format: .fixed(precision: 2)) fired=\(rate <= Self.maxRate, privacy: .public)")
            if rate <= Self.maxRate {
                armed.remove(.weather)
                ringing.append(.weather)
            }
        }

        return ringing
    }

    /// Every scrub sample, whether or not anything was crossed — this is the
    /// distribution `maxRate` has to be picked from, and only a real thumb
    /// produces it. Remove once the threshold is set.
    static func logRate(_ hoursPerSecond: Double) {
        log.info("rate=\(hoursPerSecond, format: .fixed(precision: 2))")
    }
}
