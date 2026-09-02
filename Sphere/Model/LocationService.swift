import CoreLocation
import Observation

/// The arc is the sun's elevation curve for a place, so the app needs real
/// coordinates whether or not weather is switched on.
///
/// Three sources, in order: a place the user typed, a Core Location fix, then
/// Chicago as the last resort.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Access: Equatable {
        case undetermined
        case denied
        case granted
    }

    private let manager = CLLocationManager()
    private(set) var access: Access = .undetermined

    private(set) var fix: Coordinate?
    private(set) var fixName: String?
    private(set) var fixZone: TimeZone?
    private(set) var manual: Coordinate?
    private(set) var manualName: String?
    private(set) var manualZone: TimeZone?
    private(set) var isSearching = false

    private static let manualKey = "manualLocation"

    var coordinate: Coordinate { manual ?? fix ?? .chicago }

    /// A place's own clock, which the sun and the arc are drawn on. Falls back
    /// to the device's, which is the right answer whenever the place IS here.
    var timeZone: TimeZone {
        (manual != nil ? manualZone : fixZone) ?? .autoupdatingCurrent
    }

    var placeName: String {
        manualName ?? fixName ?? "Chicago, IL"
    }

    var isUsingFallback: Bool { manual == nil && fix == nil }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        access = Self.access(for: manager.authorizationStatus)
        restoreManual()
    }

    // MARK: - Core Location

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    private static func access(for status: CLAuthorizationStatus) -> Access {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: .granted
        case .denied, .restricted: .denied
        default: .undetermined
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        access = Self.access(for: manager.authorizationStatus)
        if access == .granted { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        fix = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(last) { [weak self] marks, _ in
            guard let mark = marks?.first else { return }
            self?.fixName = Self.displayName(for: mark)
            self?.fixZone = mark.timeZone
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Chicago keeps standing in; a failed fix is not a refusal.
    }

    // MARK: - Typed place

    /// A typed place wins over the device fix, so this also covers a refusal
    /// and covers checking another city's day.
    @discardableResult
    func search(_ query: String) async -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        isSearching = true
        defer { isSearching = false }

        guard let mark = try? await CLGeocoder().geocodeAddressString(trimmed).first,
              let where_ = mark.location else { return false }

        manual = Coordinate(latitude: where_.coordinate.latitude, longitude: where_.coordinate.longitude)
        manualName = Self.displayName(for: mark, fallback: trimmed)
        manualZone = mark.timeZone
        persistManual()
        return true
    }

    /// Adopt a place chosen from the suggestion list.
    func adopt(coordinate: Coordinate, name: String, timeZone: TimeZone?) {
        manual = coordinate
        manualName = name
        manualZone = timeZone
        persistManual()
    }

    func clearManual() {
        manual = nil
        manualName = nil
        manualZone = nil
        UserDefaults.standard.removeObject(forKey: Self.manualKey)
        request()
    }

    /// City plus its state or region, so "Chicago" reads as "Chicago, IL".
    /// Shared with place search, so a result picked from the list is named the
    /// same way a device fix is.
    static func displayName(for mark: CLPlacemark, fallback: String? = nil) -> String {
        let city = mark.locality ?? mark.name ?? fallback ?? ""
        guard let region = mark.administrativeArea, !region.isEmpty else { return city }
        return city.isEmpty ? region : "\(city), \(region)"
    }

    private func persistManual() {
        guard let manual, let manualName else { return }
        var stored: [String: Any] = ["lat": manual.latitude, "lon": manual.longitude,
                                     "name": manualName]
        // Kept with the place, since a coordinate without its clock is what put
        // a Californian sunrise on Central time.
        if let manualZone { stored["zone"] = manualZone.identifier }
        UserDefaults.standard.set(stored, forKey: Self.manualKey)
    }

    private func restoreManual() {
        guard let stored = UserDefaults.standard.dictionary(forKey: Self.manualKey),
              let lat = stored["lat"] as? Double,
              let lon = stored["lon"] as? Double,
              let name = stored["name"] as? String else { return }
        manual = Coordinate(latitude: lat, longitude: lon)
        manualName = name
        manualZone = (stored["zone"] as? String).flatMap(TimeZone.init(identifier:))
    }
}
