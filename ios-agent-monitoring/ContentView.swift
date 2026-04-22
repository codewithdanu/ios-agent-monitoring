import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var locationManager = LocationManager.shared
    @StateObject var socketManager = SocketManager.shared
    
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "server_url") ?? ""
    @State private var deviceID: String = UserDefaults.standard.string(forKey: "device_id") ?? ""
    @State private var deviceToken: String = UserDefaults.standard.string(forKey: "device_token") ?? ""
    @State private var isEditing = false
    @State private var showingScanner = false
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: Configuration
                Section(header: Text("Configuration")) {
                    if isEditing {
                        TextField("Server URL (http://...)", text: $serverURL)
                        TextField("Device ID", text: $deviceID)
                        TextField("Device Token", text: $deviceToken)
                        
                        Button("Save Configuration") {
                            saveConfig()
                            isEditing = false
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                        
                        Button("Scan Setup QR") {
                            showingScanner = true
                        }
                        .foregroundColor(.indigo)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Server: \(serverURL.isEmpty ? "Not set" : serverURL)")
                                    .font(.subheadline)
                                Text("Device: \(deviceID.isEmpty ? "Not set" : deviceID)")
                                    .font(.subheadline)
                                Text("Token: \(deviceToken.isEmpty ? "Not set" : "********")")
                                    .font(.subheadline.italic())
                            }
                            Spacer()
                            Button("Edit") {
                                isEditing = true
                            }
                        }
                    }
                }
                
                // Section 2: Status
                Section(header: Text("Status")) {
                    StatusRow(title: "Connection", 
                              status: socketManager.isConnected ? "Connected" : "Disconnected", 
                              color: socketManager.isConnected ? .green : .red)
                    
                    StatusRow(title: "Location Access", 
                              status: permissionString, 
                              color: permissionColor)
                    
                    if let location = locationManager.lastLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest Coordinates").font(.caption).foregroundColor(.gray)
                            Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                // Section 3: Actions
                Section {
                    Button(action: {
                        locationManager.requestPermissions()
                    }) {
                        Label("Request Permissions", systemImage: "location.circle")
                    }
                    
                    Button(action: {
                        socketManager.connect()
                        locationManager.startTracking()
                    }) {
                        Label("Start Monitoring", systemImage: "play.fill")
                    }
                    .disabled(serverURL.isEmpty || deviceID.isEmpty)
                }
            }
            .navigationTitle("iOS Tracking Agent")
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showingScanner) {
                QRScannerCover(isPresented: $showingScanner) { result in
                    handleScanResult(result)
                }
            }
        }
    }
    
    private var permissionString: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
    
    private var permissionColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        case .denied: return .red
        default: return .gray
        }
    }
    
    private func saveConfig() {
        UserDefaults.standard.set(serverURL, forKey: "server_url")
        UserDefaults.standard.set(deviceID, forKey: "device_id")
        UserDefaults.standard.set(deviceToken, forKey: "device_token")
        
        // Notify SocketManager to reconnect with new config if needed
        if socketManager.isConnected {
            socketManager.disconnect()
            socketManager.connect()
        }
    }
    
    func handleScanResult(_ result: String) {
        // 1. Check if it's JSON
        if result.hasPrefix("{") {
            if let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                self.serverURL = json["s"] ?? ""
                self.deviceID = json["i"] ?? ""
                self.deviceToken = json["t"] ?? ""
                saveConfig()
                return
            }
        }
        
        // 2. Check if it's a URL/Deep Link
        if let url = URL(string: result), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let s = components.queryItems?.first(where: { $0.name == "s" })?.value ?? ""
            let i = components.queryItems?.first(where: { $0.name == "i" })?.value ?? ""
            let t = components.queryItems?.first(where: { $0.name == "t" })?.value ?? ""
            
            if !s.isEmpty && !i.isEmpty {
                self.serverURL = s.hasPrefix("http") ? s : "http://\(s)"
                self.deviceID = i
                self.deviceToken = t
                saveConfig()
            }
        }
    }
}

/**
 * A full-screen cover that displays the QR scanner and a close button.
 */
struct QRScannerCover: View {
    @Binding var isPresented: Bool
    var onDetected: (String) -> Void
    
    var body: some View {
        ZStack {
            QRScannerView { result in
                onDetected(result)
                isPresented = false
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button("Close") {
                        isPresented = false
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                Spacer()
                Text("Align QR Code within the frame")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.bottom, 50)
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundColor(color)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    ContentView()
}
