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
            SocketManager.shared.onConnected = { [weak self] in
                print("AppDelegate: Connection verified, pushing initial telemetry.")
                self?.pushMetrics()
                LocationManager.shared.startTracking()
            }
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
        
        SocketManager.shared.emit(event: "agent:metrics", data: data)
    }

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("AppDelegate: App entered background. Starting background task.")
        
        // Request extra time to keep the socket alive
        backgroundTask = application.beginBackgroundTask(withName: "SocketKeepAlive") {
            print("AppDelegate: Background task expired.")
            self.endBackgroundTask()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("AppDelegate: App returning to foreground.")
        endBackgroundTask()
        
        // Re-verify connection
        if !SocketManager.shared.isConnected {
            SocketManager.shared.connect()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
