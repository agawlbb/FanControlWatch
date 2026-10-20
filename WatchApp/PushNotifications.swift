import Foundation
import WatchKit
import FanControlCore

// Pushes are passive invalidations. Never call WatchModel.enter or send commands.
@MainActor final class PushNotifications: NSObject, WKApplicationDelegate {
    private static var token: String?
    private static var delivery: Task<Void, Never>?

    static func register() {
        guard Vault.load() != nil else { return }
        WKApplication.shared().registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        Self.token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Self.syncRegistration()
    }

    static func syncRegistration() {
        guard let token, let original = Vault.load(),
              let environment = Bundle.main.object(forInfoDictionaryKey: "FanControlAPNSEnvironment") as? String,
              ["development", "production"].contains(environment) else { return }
        delivery?.cancel()
        delivery = Task {
            // Existing encrypted pairing carries the APNs token to HA; relay
            // credentials and Apple's signing key never enter the watch app.
            guard !Task.isCancelled, Vault.load() == original else { return }
            _ = try? await Integration(original).request([
                "action": "push_register", "device_token": token,
                "environment": environment == "development" ? "sandbox" : "production"
            ])
        }
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any],
                                      fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        guard let hint = userInfo["fancontrol"] as? [String: Any], hint["refresh"] as? Bool == true else {
            completionHandler(.noData); return
        }
        Task {
            // An active UI already polls; this never navigates, confirms a
            // command, or launches the foreground entry/wake path.
            completionHandler(await BackgroundRefresh.refresh() ? .newData : .noData)
        }
    }
}
