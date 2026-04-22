import UIKit

/**
 * Collects device metrics (Battery, Storage, Info).
 */
class MetricsHelper {
    
    static func collectMetrics() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let storage = getStorageMetrics()
        
        return [
            "battery_percent": Int(device.batteryLevel * 100),
            "battery_state": getBatteryStateString(device.batteryState),
            "disk_used_gb": storage.used,
            "disk_total_gb": storage.total,
            "model": device.model,
            "system_version": device.systemVersion,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
    }
    
    private static func getBatteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging: return "CHARGING"
        case .full: return "FULL"
        case .unplugged: return "DISCHARGING"
        default: return "UNKNOWN"
        }
    }
    
    private static func getStorageMetrics() -> (used: Int64, total: Int64) {
        let fileManager = FileManager.default
        let path = NSHomeDirectory()
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: path)
            if let totalSize = attributes[.systemSize] as? Int64,
               let freeSize = attributes[.systemFreeSize] as? Int64 {
                let totalGB = totalSize / (1024 * 1024 * 1024)
                let freeGB = freeSize / (1024 * 1024 * 1024)
                return (used: totalGB - freeGB, total: totalGB)
            }
        } catch {
            print("MetricsHelper: Error getting storage metrics: \(error)")
        }
        
        return (used: 0, total: 0)
    }
}
