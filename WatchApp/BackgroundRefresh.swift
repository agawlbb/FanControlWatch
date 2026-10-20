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
        _ = await refresh()
        PushNotifications.syncRegistration()
    }
    static func refresh() async -> Bool {
        guard WKExtension.shared().applicationState != .active, let original = Vault.load() else { return false }
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
            guard WKExtension.shared().applicationState != .active, Vault.load() == original else { return false }
            try Vault.save(next)
            let reader = Integration(next, http: HTTP(configuration: configuration))
            // Only the HA-selected panel needs passive observations. Reads do
            // not use the entry loop, which is the only vehicle wake producer.
            if let device = next.active {
                guard !Task.isCancelled, Vault.load() == next else { return false }
                let body: [String: Any] = device.panel.map { ["action": "panel_state", "panel_id": $0.id] } ?? ["action": "state", "entity": device.entity]
                if let state = try? await reader.request(body), !Task.isCancelled, Vault.load() == next {
                    ObservationCache.shared.save(state, connection: next, device: device)
                }
            }
            return true
        } catch { return false /* Keep observations; never synthesize state. */ }
    }
}
