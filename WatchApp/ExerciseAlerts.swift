import Foundation
import UserNotifications

// Independent of view lifetime and network delivery. Cancel only with matching
// confirmation; an HTTP completion or accepted/pending operation is insufficient.
@MainActor final class ExerciseAlerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ExerciseAlerts()
    private var requests: [String: String] = [:]
    func begin(target: String, action: String) -> String {
        let id = "exercise-" + UUID().uuidString
        let deadline = Date().addingTimeInterval(60)
        let center = UNUserNotificationCenter.current()
        if let old = requests[target] { center.removePendingNotificationRequests(withIdentifiers: [old]) }
        requests[target] = id
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
            guard granted, requests[target] == id else { return }
            let content = UNMutableNotificationContent()
            content.title = "Exercise not confirmed"
            content.body = action == "stop_exercise" ? "Stop Exercise is not confirmed. Check that your car is unlocked and climate is on." : "Start Exercise is not confirmed. Check that your car is locked."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            if requests[target] != id { center.removePendingNotificationRequests(withIdentifiers: [id]) }
        }
        return id
    }
    func confirm(_ id: String) {
        if let key = requests.first(where: { $0.value == id })?.key { requests.removeValue(forKey: key) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
