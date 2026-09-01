import CoreLocation
import Observation

/// The arc is the sun's elevation curve for a place, so the app needs real
/// coordinates whether or not weather is switched on. Chicago stands in until
/// a fix arrives, and permanently if permission is refused.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Access: Equatable {
        case undetermined
        case denied
        case granted
    }

    private let manager = CLLocationManager()
    private(set) var access: Access = .undetermined
    private(set) var coordinate: Coordinate = .chicago
    private(set) var placeName: String?
    private(set) var hasFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        access = Self.access(for: manager.authorizationStatus)
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: manager.requestLocation()
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
        coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        hasFix = true
        CLGeocoder().reverseGeocodeLocation(last) { [weak self] marks, _ in
            self?.placeName = marks?.first?.locality
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Chicago keeps standing in; a failed fix is not a refusal.
    }
}
