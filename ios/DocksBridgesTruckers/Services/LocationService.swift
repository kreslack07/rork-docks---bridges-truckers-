import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var userLocation: CLLocation?
    var hasReceivedFirstLocation: Bool = false
    private var isNavigationMode: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        manager.allowsBackgroundLocationUpdates = false
    }

    func requestWhenInUseAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        guard !isNavigationMode else { return }
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func startNavigationMode() {
        isNavigationMode = true
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 10
        manager.activityType = .automotiveNavigation
        manager.startUpdatingLocation()
    }

    func stopNavigationMode() {
        isNavigationMode = false
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.activityType = .other
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 500 else { return }
        Task { @MainActor in
            self.userLocation = location
            if !self.hasReceivedFirstLocation {
                self.hasReceivedFirstLocation = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
