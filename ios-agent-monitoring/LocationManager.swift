import CoreLocation
import UIKit
import Combine

/**
 * Handles location tracking and background relaunching.
 */
class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManager()
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100 // Update every 100 meters
        
        // Safety check to prevent crash if background capability is missing
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           backgroundModes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            print("LocationManager: Background location updates enabled successfully.")
        } else {
            print("LocationManager WARNING: 'location' background mode missing from Info.plist. Background updates will not work.")
        }
        
        // This is key for reboot survival
        manager.startMonitoringSignificantLocationChanges()
    }
    
    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        manager.startUpdatingLocation()
    }
    
    func stopTracking() {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.lastLocation = location
        }
        
        print("LocationManager: Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Send to server via SocketManager
        sendLocationToServer(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            self.startTracking()
        }
    }
    
    private func sendLocationToServer(_ location: CLLocation) {
        let data: [String: Any] = [
            "deviceId": SocketManager.shared.deviceId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy_meters": location.horizontalAccuracy,
            "altitude": location.altitude,
            "recorded_at": ISO8601DateFormatter().string(from: location.timestamp)
        ]
        
        SocketManager.shared.emit(event: "agent:location", data: data)
    }
}
