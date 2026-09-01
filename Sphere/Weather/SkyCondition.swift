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
    /// Convective available potential energy, J/kg. The actual measure of how
    /// unstable the air is, and a far better storm signal than the code.
    let cape: Double
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
    let cape: Double

    var id: Int { hour }

    /// Enough instability to build a cumulonimbus. Open-Meteo's thunderstorm
    /// code is conservative: in a year of Chicago data it flagged 8 hours,
    /// while showers coded 80 to 82 carried a median CAPE of 1260 and are
    /// physically the same cloud. Frontal rain sits near 30, so this separates
    /// convective from stratiform cleanly.
    static let convectiveCAPE: Double = 1_000

    /// A higher bar for drawing lightning than for drawing the cloud. Coded
    /// thunderstorm hours ran a median of 2090.
    static let electricCAPE: Double = 2_000

    var isConvective: Bool {
        condition == .thunderstorm || (cape >= Self.convectiveCAPE && precipitation > 0)
    }

    var hasLightning: Bool {
        condition == .thunderstorm || (cape >= Self.electricCAPE && precipitation > 0)
    }

    /// Below this a layer is not worth drawing.
    static let layerThreshold: Double = 0.12

    var hasLow: Bool { cloudLow >= Self.layerThreshold }
    var hasMid: Bool { cloudMid >= Self.layerThreshold }
    var hasHigh: Bool { cloudHigh >= Self.layerThreshold }

    /// Whether the sun or moon can be seen through what is above it.
    var bodyVisible: Bool { cloudLow < 0.75 }
}

/// Temporary. Three ways of constructing a cloud, switchable from the menu so
/// they can be compared on device. The losers and this enum come out together.
enum CloudStyle: String, CaseIterable, Identifiable {
    /// Every cloud is a cluster of overlapping circles, each one filled and
    /// stroked and drawn back to front, so the arcs where puffs overlap stay
    /// visible. This is the technique in the reference drawing.
    case puffs
    /// One clean silhouette, with the notches between lobes made shallow so it
    /// stops reading as a row of humps.
    case scallop
    /// A clean outer silhouette with a few interior arcs suggesting the puffs
    /// inside the mass.
    case hybrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .puffs: "Puffs"
        case .scallop: "Scallop"
        case .hybrid: "Hybrid"
        }
    }
}
