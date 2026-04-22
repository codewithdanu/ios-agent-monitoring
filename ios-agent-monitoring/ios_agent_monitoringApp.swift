//
//  ios_agent_monitoringApp.swift
//  ios-agent-monitoring
//
//  Created by IdaDanuartha on 22/04/26.
//

import SwiftUI

@main
struct ios_agent_monitoringApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        let s = components.queryItems?.first(where: { $0.name == "s" })?.value ?? ""
        let i = components.queryItems?.first(where: { $0.name == "i" })?.value ?? ""
        let t = components.queryItems?.first(where: { $0.name == "t" })?.value ?? ""
        
        if !s.isEmpty && !i.isEmpty {
            let normalizedServer = s.hasPrefix("http") ? s : "http://\(s)"
            
            UserDefaults.standard.set(normalizedServer, forKey: "server_url")
            UserDefaults.standard.set(i, forKey: "device_id")
            UserDefaults.standard.set(t, forKey: "device_token")
            
            // Restart tracking if already active
            LocationManager.shared.startTracking()
            SocketManager.shared.connect()
        }
    }
}
