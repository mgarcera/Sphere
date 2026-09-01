import Foundation

/// Deliberately thin. Open-Meteo ships first because it needs no App ID, no
/// attribution mark and no key, and it reaches 92 days into the past, which
/// the wheel can now reach too. WeatherKit becomes a second conformer the day
/// Sphere needs a provider licensed for commercial use.
protocol WeatherProvider: Sendable {
    func hourly(coordinate: Coordinate, from: Date, to: Date) async throws -> [WeatherHour]
}

struct OpenMeteoProvider: WeatherProvider {
    /// How far the free forecast reaches. Anything outside comes back empty
    /// rather than guessed, so a bare sky always means "not known".
    static let forecastDays = 16
    static let pastDays = 92

    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            /// Every series is nullable in practice: the archive lags, so the
            /// oldest hours of the 92-day window come back null. Typing any of
            /// these non-optional fails the whole decode and the sky stays
            /// empty with no error and no crash.
            let weather_code: [Int?]
            let cloud_cover_low: [Double?]
            let cloud_cover_mid: [Double?]
            let cloud_cover_high: [Double?]
            let precipitation: [Double?]
            let wind_speed_10m: [Double?]
            let cape: [Double?]
        }
        let hourly: Hourly
    }

    func hourly(coordinate: Coordinate, from: Date, to: Date) async throws -> [WeatherHour] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(coordinate.latitude)),
            .init(name: "longitude", value: String(coordinate.longitude)),
            .init(name: "hourly", value: "weather_code,cloud_cover_low,cloud_cover_mid,cloud_cover_high,precipitation,wind_speed_10m,cape"),
            .init(name: "timezone", value: "UTC"),
            .init(name: "past_days", value: String(Self.pastDays)),
            .init(name: "forecast_days", value: String(Self.forecastDays)),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(Response.self, from: data)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let hourly = decoded.hourly
        return hourly.time.indices.compactMap { index in
            guard let code = hourly.weather_code[index],
                  let date = formatter.date(from: hourly.time[index]) else { return nil }
            func percent(_ series: [Double?]) -> Double {
                (series.indices.contains(index) ? series[index] ?? 0 : 0) / 100
            }
            return WeatherHour(
                date: date,
                condition: SkyCondition(wmoCode: code),
                cloudLow: percent(hourly.cloud_cover_low),
                cloudMid: percent(hourly.cloud_cover_mid),
                cloudHigh: percent(hourly.cloud_cover_high),
                precipitation: hourly.precipitation.indices.contains(index) ? hourly.precipitation[index] ?? 0 : 0,
                wind: hourly.wind_speed_10m.indices.contains(index) ? hourly.wind_speed_10m[index] ?? 0 : 0,
                cape: hourly.cape.indices.contains(index) ? hourly.cape[index] ?? 0 : 0
            )
        }
    }
}
