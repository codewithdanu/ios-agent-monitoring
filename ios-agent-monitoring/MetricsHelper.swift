import UIKit

/**
 * Collects device metrics (Battery, Storage, Info).
 */
class MetricsHelper {
    
    static func collectMetrics() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let storage = getStorageMetrics()
        let memory = getMemoryMetrics()
        
        return [
            "battery_percent": Int(device.batteryLevel * 100),
            "battery_state": getBatteryStateString(device.batteryState),
            "cpu_percent": getCPUUsage(),
            "memory_used_mb": memory.used,
            "memory_total_mb": memory.total,
            "disk_used_gb": storage.used,
            "disk_total_gb": storage.total,
            "model": device.model,
            "system_version": device.systemVersion,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
    }
    
    private static func getMemoryMetrics() -> (used: Int, total: Int) {
        let total = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let usedBytes = UInt64(stats.active_count + stats.inactive_count + stats.wire_count) * pageSize
            return (used: Int(usedBytes / (1024 * 1024)), total: total)
        }
        return (used: 0, total: total)
    }
    
    private static func getCPUUsage() -> Double {
        var totalUsage: Double = 0.0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        if result == KERN_SUCCESS, let threads = threadList {
            for i in 0..<Int(threadCount) {
                var threadInfo = thread_basic_info()
                var count = UInt32(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                    }
                }
                
                if infoResult == KERN_SUCCESS {
                    if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                        totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                    }
                }
            }
            // Free the thread list
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.size)))
        }
        
        return min(totalUsage, 100.0)
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
