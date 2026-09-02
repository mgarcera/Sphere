import MapKit
import Observation

/// Live place suggestions as the query is typed.
///
/// `CLGeocoder` cannot do this: Apple documents it as rate limited and says not
/// to call it repeatedly, so it only ever suited a one-shot resolve on submit.
/// `MKLocalSearchCompleter` is the API built for the incremental case, and it
/// understands whatever Maps does — a city, a city and state, a postal code, a
/// full street address.
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let completion: MKLocalSearchCompletion

        static func == (a: Suggestion, b: Suggestion) -> Bool { a.id == b.id }
    }

    private(set) var suggestions: [Suggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        // Addresses only. `.pointOfInterest` would start offering coffee shops,
        // which is not what a "where am I" field is for.
        completer.resultTypes = [.address]
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
        completer.queryFragment = ""
    }

    /// Resolve a chosen suggestion to real coordinates and a display name.
    func resolve(_ suggestion: Suggestion) async -> (coordinate: Coordinate, name: String)? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
            return nil
        }
        let where_ = item.placemark.coordinate
        return (
            Coordinate(latitude: where_.latitude, longitude: where_.longitude),
            LocationService.displayName(for: item.placemark, fallback: suggestion.title)
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(5).map {
            Suggestion(id: "\($0.title)|\($0.subtitle)", title: $0.title,
                       subtitle: $0.subtitle, completion: $0)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
