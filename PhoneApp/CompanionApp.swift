import SwiftUI
import UIKit
import BackgroundTasks
import UserNotifications
import FanControlCore

@main struct CompanionApp: App {
    @UIApplicationDelegateAdaptor(PhoneDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { CompanionView() }
            .onChange(of: phase) { _, value in
                if value == .active { PhoneModel.shared.foreground() }
                else { PhoneModel.shared.background() }
            }
    }
}

final class PhoneDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let refreshID = "dev.fancontrol.watch.phone.refresh"
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = PhoneModel.shared
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshID, using: .main) { task in
            Task { @MainActor in
                let work = Task { await PhoneModel.shared.refresh() }
                task.expirationHandler = { work.cancel() }
                let success = await work.value
                PhoneModel.shared.background()
                task.setTaskCompleted(success: success)
            }
        }
        application.registerForRemoteNotifications()
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let hint = notification.request.content.userInfo["fancontrol"] as? [String: Any]
        Task { @MainActor in
            guard hint?["notification"] as? Bool == true,
                  let connection = PhoneModel.shared.connection,
                  hint?["watch_id"] as? String == connection.watch_id else {
                completionHandler([]); return
            }
            completionHandler([.banner, .list, .sound])
        }
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PhoneModel.shared.pushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PhoneModel.shared.registerPush() }
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let hint = userInfo["fancontrol"] as? [String: Any], hint["refresh"] as? Bool == true,
              hint["watch_id"] as? String == PhoneModel.shared.connection?.watch_id else { completionHandler(.noData); return }
        let update = (hint["update_id"] as? String).flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
        Task {
            PhoneModel.shared.record("phone_received", updateID: update)
            let success = await PhoneModel.shared.refresh(updateID: update)
            completionHandler(success ? .newData : .failed)
        }
    }
}
