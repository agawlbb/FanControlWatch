import Foundation
import WatchKit
import FanControlCore

@MainActor enum BackgroundRefresh {
    static let identifier = "dev.fancontrol.watch.refresh"
    static func schedule() {
        guard Vault.load() != nil else { return }
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(15 * 60), userInfo: identifier as NSString) { _ in }
    }
    static func run() async {
        defer { schedule() }
        guard let original = Vault.load() else { return }
        let configuration = URLSessionConfiguration.ephemeral
        // Disallow the watch's built-in cellular radio, without rejecting a
        // phone proxy merely because its upstream connection is expensive.
        configuration.allowsCellularAccess = false
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = false
        let client = Integration(original, http: HTTP(configuration: configuration))
        do {
            var config = try await client.request(["action": "config", "platform": "watch_os"])
            config["token"] = original.token; config["watch_id"] = original.watch_id
            let next = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: config)).validated()
            try Task.checkCancellation()
            guard Vault.load() == original else { return }
            try Vault.save(next)
            let reader = Integration(next, http: HTTP(configuration: configuration))
            let deadline = Date().addingTimeInterval(18)
            for device in next.devices.filter({ $0.domain == "fan" }) {
                guard Date() < deadline, !Task.isCancelled, Vault.load() == next else { return }
                let body: [String: Any] = device.panel.map { ["action": "panel_state", "panel_id": $0.id] } ?? ["action": "state", "entity": device.entity]
                if let state = try? await reader.request(body), !Task.isCancelled, Vault.load() == next {
                    ObservationCache.shared.save(state, connection: next, device: device)
                }
            }
        } catch { /* Keep the previous observations; never synthesize a state. */ }
    }
}
