import Foundation

struct Coordinate {
    var latitude: Double
    var longitude: Double

    /// v1 hardcodes Chicago. Replacing this with Core Location or a city
    /// picker is an open item in the brief.
    static let chicago = Coordinate(latitude: 41.8781, longitude: -87.6298)
}

/// One calendar day of sun geometry for one place.
///
/// The math is the NOAA Solar Calculator's published set of formulas — the same
/// low-precision approach the React prototype used, ported directly. Declination
/// and the equation of time are evaluated once for the day; both drift by far
/// less than the arc can render over 24 hours.
struct SolarDay {
    let coordinate: Coordinate
    /// Offset from UTC in hours, for the day being drawn.
    let utcOffsetHours: Double

    private let declination: Double      // degrees
    private let equationOfTime: Double   // minutes

    /// Local decimal hours, 0..24. Nil above the polar circles when the sun
    /// neither rises nor sets.
    let sunrise: Double?
    let sunset: Double?
    let solarNoon: Double

    init(date: Date, coordinate: Coordinate = .chicago, timeZone: TimeZone = .autoupdatingCurrent) {
        self.coordinate = coordinate
        self.utcOffsetHours = Double(timeZone.secondsFromGMT(for: date)) / 3600

        let t = Self.julianCentury(for: date)

        let l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).wrapped360
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let center = sinDeg(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sinDeg(2 * m) * (0.019993 - 0.000101 * t)
            + sinDeg(3 * m) * 0.000289

        let trueLongitude = l0 + center
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sinDeg(125.04 - 1934.136 * t)

        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cosDeg(125.04 - 1934.136 * t)

        self.declination = asinDeg(sinDeg(obliquity) * sinDeg(apparentLongitude))

        let y = pow(tanDeg(obliquity / 2), 2)
        self.equationOfTime = 4 * (
            y * sinDeg(2 * l0)
            - 2 * e * sinDeg(m)
            + 4 * e * y * sinDeg(m) * cosDeg(2 * l0)
            - 0.5 * y * y * sinDeg(4 * l0)
            - 1.25 * e * e * sinDeg(2 * m)
        ).inDegrees

        // 90.833° accounts for refraction plus the sun's apparent radius.
        let noonMinutes = 720 - 4 * coordinate.longitude - equationOfTime + utcOffsetHours * 60
        self.solarNoon = noonMinutes / 60

        let hourAngleArgument = cosDeg(90.833) / (cosDeg(coordinate.latitude) * cosDeg(declination))
            - tanDeg(coordinate.latitude) * tanDeg(declination)

        if hourAngleArgument >= -1, hourAngleArgument <= 1 {
            let hourAngle = acosDeg(hourAngleArgument)
            self.sunrise = (noonMinutes - 4 * hourAngle) / 60
            self.sunset = (noonMinutes + 4 * hourAngle) / 60
        } else {
            self.sunrise = nil
            self.sunset = nil
        }
    }

    /// Sun elevation in degrees at a local decimal hour. Negative at night.
    func elevation(atHour hour: Double) -> Double {
        let minutes = hour * 60
        var trueSolarTime = (minutes + equationOfTime + 4 * coordinate.longitude - utcOffsetHours * 60)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }

        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        let cosZenith = sinDeg(coordinate.latitude) * sinDeg(declination)
            + cosDeg(coordinate.latitude) * cosDeg(declination) * cosDeg(hourAngle)
        return 90 - acosDeg(min(max(cosZenith, -1), 1))
    }

    /// The sun's noon elevation at this latitude on the summer solstice.
    /// Using it as the divisor is what makes the hill taller in June than in
    /// December — normalising against each day's own peak would flatten that out.
    var seasonalCeiling: Double {
        max(10, 90 - abs(coordinate.latitude) + 23.44)
    }

    /// 0 at the horizon and below, 1 at the yearly peak. This is the shape the
    /// arc draws.
    func normalizedElevation(atHour hour: Double) -> Double {
        min(max(elevation(atHour: hour), 0) / seasonalCeiling, 1)
    }

    var dayLengthHours: Double {
        guard let sunrise, let sunset else { return 0 }
        return sunset - sunrise
    }

    private static func julianCentury(for date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86400 + 2440587.5
        return (julianDay - 2451545) / 36525
    }
}

// MARK: - Degree trigonometry

private let degreesToRadians = Double.pi / 180

func sinDeg(_ d: Double) -> Double { sin(d * degreesToRadians) }
func cosDeg(_ d: Double) -> Double { cos(d * degreesToRadians) }
func tanDeg(_ d: Double) -> Double { tan(d * degreesToRadians) }
func asinDeg(_ x: Double) -> Double { asin(x) / degreesToRadians }
func acosDeg(_ x: Double) -> Double { acos(x) / degreesToRadians }

private extension Double {
    var wrapped360: Double {
        let r = truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// The equation of time is assembled in radians before being scaled to minutes.
    var inDegrees: Double { self / degreesToRadians }
}
