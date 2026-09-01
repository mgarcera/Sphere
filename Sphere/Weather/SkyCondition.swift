import Foundation

/// What the sky is doing in one hour, reduced to the handful of states the
/// band can name. Providers map their own vocabularies onto this.
enum SkyCondition: String, Equatable, CaseIterable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunderstorm

    /// WMO 4677, which is what Open-Meteo reports.
    init(wmoCode code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: self = .rain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    var isFrozen: Bool { self == .snow }
    var isWet: Bool { self == .drizzle || self == .rain || self == .snow || self == .thunderstorm }
}

/// One hour as the provider reports it. Coverage is split by altitude because
/// that is what lets two overcast hours look different: cirrus and cumulus are
/// not the same sky.
struct WeatherHour: Equatable {
    let date: Date
    let condition: SkyCondition
    let cloudLow: Double
    let cloudMid: Double
    let cloudHigh: Double
    /// Millimetres in the hour.
    let precipitation: Double
    /// km/h at 10m.
    let wind: Double
}

/// One hour of sky, ready to draw.
struct SkyHour: Identifiable, Equatable {
    let hour: Int
    let condition: SkyCondition
    let isDaylight: Bool
    let cloudLow: Double
    let cloudMid: Double
    let cloudHigh: Double
    let precipitation: Double
    let wind: Double

    var id: Int { hour }

    /// Below this a layer is not worth drawing.
    static let layerThreshold: Double = 0.12

    var hasLow: Bool { cloudLow >= Self.layerThreshold }
    var hasMid: Bool { cloudMid >= Self.layerThreshold }
    var hasHigh: Bool { cloudHigh >= Self.layerThreshold }

    /// Whether the sun or moon can be seen through what is above it.
    var bodyVisible: Bool { cloudLow < 0.75 }
}

/// Temporary. Two ways of drawing the same data, switchable from the menu so
/// they can be compared on device. The loser and this enum both come out.
enum SkyStyle: String, CaseIterable, Identifiable {
    case layered
    case continuous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layered: "Layered"
        case .continuous: "Continuous"
        }
    }
}
