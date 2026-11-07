import Foundation
import CoreLocation

/// Coordinates and locality information.
public struct UserLocation: Equatable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var locality: String
    public var isManual: Bool

    public init(latitude: Double, longitude: Double, locality: String = "", isManual: Bool = false) {
        self.latitude = latitude
        self.longitude = longitude
        self.locality = locality
        self.isManual = isManual
    }

    /// Default fallback location (New York City).
    public static let fallback = UserLocation(
        latitude: 40.7128,
        longitude: -74.0060,
        locality: "New York, USA",
        isManual: false
    )
}

/// Manages automatic CoreLocation coordinate updates with manual override fallback.
@MainActor
public final class LocationManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    public static let shared = LocationManager()

    private let clManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    public private(set) var currentLocation: UserLocation = .fallback
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    public var onLocationChanged: (@MainActor @Sendable (UserLocation) -> Void)?

    override private init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = clManager.authorizationStatus
    }

    /// Requests system location access if not already granted.
    public func requestAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    /// Starts monitoring significant location changes.
    public func startUpdating() {
        guard !currentLocation.isManual else { return }
        clManager.startUpdatingLocation()
    }

    public func stopUpdating() {
        clManager.stopUpdatingLocation()
    }

    /// Sets manual coordinates and city override.
    public func setManualLocation(latitude: Double, longitude: Double, locality: String) {
        let manual = UserLocation(
            latitude: latitude,
            longitude: longitude,
            locality: locality,
            isManual: true
        )
        currentLocation = manual
        onLocationChanged?(manual)
    }

    /// Restores automatic CoreLocation updates.
    public func enableAutomaticLocation() {
        currentLocation.isManual = false
        requestAuthorization()
        clManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        #if os(macOS)
        if authorizationStatus == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
        #else
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            clManager.startUpdatingLocation()
        }
        #endif
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !currentLocation.isManual, let location = locations.last else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Reverse geocode to find friendly city name
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.currentLocation.isManual else { return }

                var cityName = ""
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? placemark.administrativeArea ?? ""
                    let country = placemark.country ?? ""
                    cityName = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
                }

                let newLoc = UserLocation(
                    latitude: lat,
                    longitude: lon,
                    locality: cityName.isEmpty ? "Local Area" : cityName,
                    isManual: false
                )
                self.currentLocation = newLoc
                self.onLocationChanged?(newLoc)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Retain fallback or current location on error
    }
}
