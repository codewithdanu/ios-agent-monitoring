import Foundation
import Combine

/**
 * Manages WebSocket connection to the backend server.
 */
class SocketManager: NSObject, ObservableObject {
    static let shared = SocketManager()
    
    @Published var isConnected = false
    
    private var webSocket: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    
    var serverURL: String {
        return UserDefaults.standard.string(forKey: "server_url") ?? "http://localhost:3000"
    }
    
    var deviceId: String {
        return UserDefaults.standard.string(forKey: "device_id") ?? ""
    }
    
    var deviceToken: String {
        return UserDefaults.standard.string(forKey: "device_token") ?? ""
    }

    func connect() {
        guard !isConnected, !deviceId.isEmpty else { return }
        
        // Convert http/https to ws/wss
        let wsScheme = serverURL.contains("https") ? "wss" : "ws"
        let baseUrl = serverURL.replacingOccurrences(of: "http://", with: "")
                               .replacingOccurrences(of: "https://", with: "")
        
        // Socket.io v4 WebSocket URL
        let socketUrl = URL(string: "\(wsScheme)://\(baseUrl)/socket.io/?EIO=4&transport=websocket")!
        
        webSocket = urlSession.webSocketTask(with: socketUrl)
        webSocket?.resume()
        
        receiveMessage()
        
        print("SocketManager: Connecting to \(socketUrl)")
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    private func sendRegistration() {
        let registration: [String: Any] = [
            "deviceId": deviceId,
            "deviceToken": deviceToken,
            "deviceType": "MOBILE",
            "os": "iOS"
        ]
        
        emit(event: "REGISTER", data: registration)
    }
    
    // Send a Socket.io event (Packet Type 42)
    func emit(event: String, data: [String: Any]) {
        let packet = [event, data] as [Any]
        if let jsonData = try? JSONSerialization.data(withJSONObject: packet),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            // Socket.io v4 message prefix is '42'
            sendMessage("42\(jsonString)")
        }
    }
    
    func sendMessage(_ message: String) {
        let workItem = URLSessionWebSocketTask.Message.string(message)
        webSocket?.send(workItem) { error in
            if let error = error {
                print("SocketManager: Send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("SocketManager: Receive error: \(error)")
                self.handleDisconnection()
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleRawMessage(text)
                case .data(let data):
                    print("SocketManager: Received binary data: \(data.count) bytes")
                @unknown default:
                    break
                }
                self.receiveMessage()
            }
        }
    }
    
    private func handleRawMessage(_ text: String) {
        print("SocketManager: Raw received: \(text)")
        
        // Engine.io Packet Types:
        // 0: OPEN (contains sid/pingInterval/pingTimeout)
        // 2: PING (must respond with 3 PONG)
        // 4: MESSAGE (Socket.io packet follows)
        
        guard let firstChar = text.first else { return }
        
        switch firstChar {
        case "0":
            print("SocketManager: Engine.io OPEN")
            // Send Socket.io Connect packet (40)
            sendMessage("40")
            
        case "2":
            print("SocketManager: Engine.io PING -> Sending PONG")
            sendMessage("3")
            
        case "4":
            // Socket.io Message
            if text.count > 1, text[text.index(after: text.startIndex)] == "0" {
                print("SocketManager: Socket.io CONNECTED")
                DispatchQueue.main.async {
                    self.isConnected = true
                }
                self.sendRegistration()
            } else if text.hasPrefix("42") {
                let jsonPart = String(text.dropFirst(2))
                self.handleIncomingMessage(jsonPart)
            }
            
        default:
            break
        }
    }
    
    private func handleDisconnection() {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        // Attempt reconnect after delay if still supposed to be connected
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            self.connect()
        }
    }
    
    private func handleIncomingMessage(_ jsonString: String) {
        // Handle incoming events from server
        print("SocketManager: Event received: \(jsonString)")
    }
}
