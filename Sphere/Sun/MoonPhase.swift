import Foundation

/// Where the moon is in its cycle, from the mean synodic month. Accurate to a
/// few hours, which is far finer than a drawn shape can show.
struct MoonPhase: Equatable {
    /// 0 is new, 0.5 is full, wrapping at 1.
    let fraction: Double

    /// 0 is dark, 1 is fully lit.
    var illuminated: Double { (1 - cos(2 * .pi * fraction)) / 2 }

    /// Waxing moons are lit on the right in the northern hemisphere.
    var isWaxing: Bool { fraction < 0.5 }

    private static let synodicMonth = 29.530588853
    /// Julian day of the new moon at 2000-01-06 18:14 UTC. The widely copied
    /// 2451550.1 is that date at 14:24, which throws the quarters out by
    /// roughly two percent of a cycle.
    private static let referenceNewMoon = 2451550.2597

    init(date: Date) {
        let julianDay = date.timeIntervalSince1970 / 86400 + 2440587.5
        var f = ((julianDay - Self.referenceNewMoon) / Self.synodicMonth)
            .truncatingRemainder(dividingBy: 1)
        if f < 0 { f += 1 }
        fraction = f
    }

    var name: String {
        switch fraction {
        case ..<0.03, 0.97...: "New moon"
        case ..<0.22: "Waxing crescent"
        case ..<0.28: "First quarter"
        case ..<0.47: "Waxing gibbous"
        case ..<0.53: "Full moon"
        case ..<0.72: "Waning gibbous"
        case ..<0.78: "Last quarter"
        default: "Waning crescent"
        }
    }
}
