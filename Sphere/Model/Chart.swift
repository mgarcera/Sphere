import Foundation

// PARKED, WHOLLY UNREFERENCED. Nothing outside this file reads `BirthData`, `NatalChart`,
// `NatalPlacement` or `TransitAspect`, and `Planet` is referenced only from inside here, which
// makes it dead by the same route. It compiles and ships as bytes nobody reaches.
//
// Kept because it is the one surviving piece of the personal-mode direction the app was going to
// take, which `DECISIONS.md` records and `AppStore/metadata.md` lists among the things the copy
// deliberately does not claim. It carried no reason of its own until 2026-10-13, unlike
// `Planet.callToAction`, which is why it is written here: a file with neither a reference nor a
// recorded reason reads as drift rather than as a decision.

/// Personal-mode inputs. UTC offset is entered by hand — there is no timezone
/// or DST lookup yet, and a wrong offset silently produces a wrong chart.
struct BirthData {
    var date: Date
    var utcOffsetHours: Double
    var latitude: Double
    var longitude: Double
    var place: String
}

struct NatalPlacement {
    var longitude: Double
    var sign: String
    var degree: Double
    var house: Int
}

struct NatalChart {
    var planets: [Planet: NatalPlacement]
    var ascendant: NatalPlacement
    var midheaven: NatalPlacement
    /// 12 cusps, Equal House system.
    var houseCusps: [Double]
}

struct TransitAspect: Identifiable {
    enum Aspect: String {
        case conjunction, opposition, trine, square, sextile
    }

    let id = UUID()
    var transitingBody: Planet
    var natalBody: Planet
    var aspect: Aspect
    var orb: Double
}
