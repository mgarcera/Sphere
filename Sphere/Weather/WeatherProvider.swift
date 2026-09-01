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
            /// Nullable in practice: the archive lags, so the oldest hours of
            /// the 92-day window come back null. Typing this as [Int] fails
            /// the whole decode and the sky stays empty with no error.
            let weather_code: [Int?]
        }
        let hourly: Hourly
    }

    func hourly(coordinate: Coordinate, from: Date, to: Date) async throws -> [WeatherHour] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(coordinate.latitude)),
            .init(name: "longitude", value: String(coordinate.longitude)),
            .init(name: "hourly", value: "weather_code"),
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

        return zip(decoded.hourly.time, decoded.hourly.weather_code).compactMap { time, code in
            guard let code, let date = formatter.date(from: time) else { return nil }
            return WeatherHour(date: date, condition: SkyCondition(wmoCode: code))
        }
    }
}
