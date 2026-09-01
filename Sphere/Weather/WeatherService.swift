import Observation
import Foundation

/// Holds one fetch and answers per-hour questions against it.
@Observable
final class WeatherService {
    private let provider: WeatherProvider
    private var byHour: [Date: WeatherHour] = [:]
    private var fetchedFor: Coordinate?

    init(provider: WeatherProvider = OpenMeteoProvider()) {
        self.provider = provider
    }

    func load(coordinate: Coordinate) async {
        guard fetchedFor != coordinate else { return }
        do {
            let hours = try await provider.hourly(coordinate: coordinate, from: .now, to: .now)
            byHour = Dictionary(hours.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
            fetchedFor = coordinate
        } catch {
            // A failed fetch leaves the sky empty, which reads the same as out
            // of range: we do not know, so we do not draw.
            byHour = [:]
        }
    }

    /// Conditions on the hour containing `date`, or nil when it is outside the
    /// forecast window.
    func hour(at date: Date) -> WeatherHour? {
        let hour = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        return byHour[hour]
    }

    var isLoaded: Bool { !byHour.isEmpty }
}
