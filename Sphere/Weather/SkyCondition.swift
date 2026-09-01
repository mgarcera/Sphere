import Foundation

/// What the sky is doing in one hour, reduced to the handful of states the
/// band can actually draw. Providers map their own vocabularies onto this.
enum SkyCondition: String, Equatable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case drizzle
    case rain
    case snow
    case thunderstorm

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
}

struct WeatherHour: Equatable {
    let date: Date
    let condition: SkyCondition
}

/// One hour of sky, ready to draw: the condition plus whether the sun is up,
/// since clear day and clear night are different pictures.
struct SkyHour: Identifiable, Equatable {
    let hour: Int
    let condition: SkyCondition
    let isDaylight: Bool
    var id: Int { hour }
}
