import Foundation

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
    /// Fetched in celsius and localised at the point of display, so the unit
    /// follows the reader rather than the request.
    let celsius: Double?
}
