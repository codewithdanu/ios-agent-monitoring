# iOS Tracking Agent

This is a lightweight background tracking agent for iOS devices. It monitors location and system metrics (Battery, Storage) and survival reboots using "Significant Location Changes".

## Xcode Setup Instructions

1.  **Create Project**: Create a new iOS App project in Xcode using **Swift** and **SwiftUI** (or UIKit).
2.  **Add Files**: Drag the `.swift` files from this directory into your Xcode project.
3.  **Signing & Capabilities**:
    *   Select your App Target > **Signing & Capabilities**.
    *   Click **+ Capability** and add **Background Modes**.
    *   Check:
        *   `Location updates`
        *   `Background fetch`
        *   `Remote notifications` (optional, for waking up app)
4.  **Info.plist Keys**:
    Add the following keys to your `Info.plist`:
    *   `NSLocationAlwaysAndWhenInUseUsageDescription`: "This app tracks location for personal device monitoring even in the background."
    *   `NSLocationWhenInUseUsageDescription`: "This app tracks location for personal device monitoring."
    *   `UIBackgroundModes`: `location`, `fetch`

## Configuration

The agent expects the following keys in `UserDefaults` (you can populate these via a QR scanner or simple UI in the app):
*   `server_url`: The backend server address (e.g., `http://192.168.1.10:3000`)
*   `device_id`: The unique ID for this device in your dashboard.

## Reboot Survival Logic

The agent uses `manager.startMonitoringSignificantLocationChanges()` in `LocationManager.swift`. 
When the device reboots, iOS will automatically relaunch the app in the background when a significant location change (cell tower switch) occurs. The `AppDelegate` catches this event and re-establishes the connection.
