import UIKit
import CoreLocation

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. Initialize services (this also sets up background tracking observers)
        setupServices()
        
        return true
    }

    private func setupServices() {
        // Initialize managers early to catch background events
        _ = LocationManager.shared
        
        // Start tracking and connection if deviceId is already set
        if !SocketManager.shared.deviceId.isEmpty {
            LocationManager.shared.startTracking()
            SocketManager.shared.connect()
        }
        
        // Start periodic metrics update
        Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            self.pushMetrics()
        }
    }
    
    private func pushMetrics() {
        let metrics = MetricsHelper.collectMetrics()
        var data = metrics
        data["deviceId"] = SocketManager.shared.deviceId
        
        SocketManager.shared.emit(event: "METRICS_UPDATE", data: data)
    }

    // MARK: UISceneSession Lifecycle (For modern iOS apps)
    // In a production app, you'd also handle SceneDelegate.
}
