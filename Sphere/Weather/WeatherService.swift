import Observation
import Foundation

/// Holds one fetch and answers per-hour questions against it.
@Observable
final class WeatherService {
    private let provider: WeatherProvider
    private var byHour: [Date: WeatherHour] = [:]
    private var fetchedFor: Coordinate?
    /// When the store was last filled, so the widgets can tell a forecast from
    /// a memory of one.
    private(set) var fetchedAt: Date?
    private var requestID = 0

    init(provider: WeatherProvider = OpenMeteoProvider()) {
        self.provider = provider
    }

    /// Two rules here, both learned the hard way.
    ///
    /// A failure NEVER clears what we already have. The first version emptied
    /// the store on any error, so one transient hiccup wiped a good fetch and
    /// the sky stayed blank until something else happened to change.
    ///
    /// And loads race: the launch fetch runs against the fallback coordinate
    /// while a location fix immediately starts a second one. Only the newest
    /// request may write, or a slow early reply lands on top of a fresh one.
    func load(coordinate: Coordinate) async {
        guard fetchedFor != coordinate else { return }

        requestID += 1
        let id = requestID

        for attempt in 0..<3 {
            do {
                let hours = try await provider.hourly(coordinate: coordinate, from: .now, to: .now)
                guard id == requestID else { return }
                byHour = Dictionary(hours.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
                fetchedFor = coordinate
                fetchedAt = .now
                return
            } catch {
                guard id == requestID else { return }
                if attempt == 2 { return }
                try? await Task.sleep(for: .seconds(Double(attempt) + 1))
            }
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
