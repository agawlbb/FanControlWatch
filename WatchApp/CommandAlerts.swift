import Foundation
import UserNotifications
import FanControlCore

// A local fallback covers missing HA ownership. Accepted work uses HA outcome APNs.
@MainActor final class CommandAlerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CommandAlerts()
    private let center = UNUserNotificationCenter.current()
    private var generations: [String: UUID] = [:]
    func begin(_ id: String, deadline: Date) {
        let ticket = UUID(); generations[id] = ticket
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            PushNotifications.register()
            guard generations[id] == ticket else { return }
            let content = UNMutableNotificationContent()
            content.title = "Fan Control not confirmed"
            content.body = "The watch could not confirm that Home Assistant received your request."
            content.sound = .default
            content.userInfo = ["operation_id": id]
            try? await center.add(UNNotificationRequest(identifier: "command-" + id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)))
            if generations[id] != ticket { center.removePendingNotificationRequests(withIdentifiers: ["command-" + id]) }
        }
    }
    func clear(_ id: String) {
        generations.removeValue(forKey: id)
        center.removePendingNotificationRequests(withIdentifiers: ["command-" + id])
        center.removeDeliveredNotifications(withIdentifiers: ["command-" + id])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func outcome(_ id: String, state: [String: Any]) {
        guard state["operation_id"] as? String == id else { return }
        if CommandPolicy.owns(state) || state["operation_status"] as? String == "cancelled" { clear(id); return }
        guard ["failed", "unconfirmed"].contains(state["operation_status"] as? String ?? "") else { return }
        clear(id)
        // HA's dedicated watch alert is authoritative after handoff. Do not duplicate it locally.
        guard state["outcome_alerts"] as? Bool != true else { return }
        let defaults = UserDefaults.standard
        var delivered = defaults.stringArray(forKey: "commandAlertIDs") ?? []
        guard !delivered.contains(id) else { return }
        delivered.append(id); defaults.set(Array(delivered.suffix(64)), forKey: "commandAlertIDs")
        let content = UNMutableNotificationContent()
        content.title = state["operation_status"] as? String == "failed" ? "Fan Control request failed" : "Fan Control not confirmed"
        content.body = "Home Assistant could not confirm the requested outcome."
        content.sound = .default
        Task { try? await center.add(UNNotificationRequest(identifier: "command-" + id, content: content, trigger: nil)) }
    }
}
