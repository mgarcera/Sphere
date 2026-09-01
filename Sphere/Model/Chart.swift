import Foundation

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
