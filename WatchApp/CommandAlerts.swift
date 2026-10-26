import Foundation
import UserNotifications
import FanControlCore

// A local fallback covers missing HA ownership. Accepted work uses HA outcome APNs.
@MainActor final class CommandAlerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CommandAlerts()
    private let center = UNUserNotificationCenter.current()
    private var generations: [String: UUID] = [:]
    private func record(_ id: String) -> CommandRecord? { CommandDelivery.shared.record(id) }
    private func fallback(_ id: String) -> Bool {
        record(id).map { CommandAlertPolicy.fallback($0, current: Vault.load()) } ?? false
    }
    private func trace(_ id: String, _ phase: String) { CommandDelivery.shared.trace(id, phase) }
    func begin(_ id: String, deadline: Date) {
        guard fallback(id), deadline.addingTimeInterval(30) > Date() else { return }
        let ticket = UUID(); generations[id] = ticket
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            PushNotifications.register()
            guard generations[id] == ticket, fallback(id), deadline.addingTimeInterval(30) > Date() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Fan Control not confirmed"
            content.body = "The watch could not confirm that Home Assistant received your request."
            content.sound = .default
            content.userInfo = ["operation_id": id, "kind": "handoff"]
            try? await center.add(UNNotificationRequest(identifier: "command-" + id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.addingTimeInterval(30).timeIntervalSinceNow), repeats: false)))
            if generations[id] != ticket || !fallback(id) {
                center.removePendingNotificationRequests(withIdentifiers: ["command-" + id])
            } else { trace(id, "alert_scheduled") }
        }
    }
    func clear(_ id: String) {
        generations.removeValue(forKey: id)
        center.removePendingNotificationRequests(withIdentifiers: ["command-" + id])
        center.removeDeliveredNotifications(withIdentifiers: ["command-" + id])
    }
    private func wasDelivered(_ id: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: "commandAlertIDs") ?? []).contains(id)
    }
    private func markDelivered(_ id: String) {
        var delivered = UserDefaults.standard.stringArray(forKey: "commandAlertIDs") ?? []
        if !delivered.contains(id) { delivered.append(id) }
        UserDefaults.standard.set(Array(delivered.suffix(64)), forKey: "commandAlertIDs")
    }
    // Reconcile OS-owned timers with the current outbox after upgrades/relaunch.
    // Never recreate an overdue timer or replay a historical terminal failure.
    func recover() async {
        let pending = await center.pendingNotificationRequests()
        for request in pending {
            if request.identifier.hasPrefix("exercise-") {
                center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
            } else if request.identifier.hasPrefix("command-") {
                let id = String(request.identifier.dropFirst(8))
                let outcome = request.content.userInfo["kind"] as? String == "outcome"
                let validOutcome = record(id).map { entry in
                    guard let data = entry.result, let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
                    return CommandAlertPolicy.localOutcome(entry, state: state, current: Vault.load())
                } ?? false
                let validFallback = fallback(id) && record(id).map({ Date().timeIntervalSince($0.issued) < CommandAlertPolicy.fallbackSeconds }) == true
                if !(outcome ? validOutcome : validFallback) {
                    clear(id); trace(id, "alert_recovery_removed")
                }
            }
        }
        let delivered = await center.deliveredNotifications()
        for notification in delivered {
            let request = notification.request
            if request.identifier.hasPrefix("exercise-") {
                center.removeDeliveredNotifications(withIdentifiers: [request.identifier])
            } else if request.identifier.hasPrefix("command-") {
                let id = String(request.identifier.dropFirst(8))
                markDelivered(id)
                let state = record(id).flatMap { $0.result }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let relevant = record(id).map { CommandAlertPolicy.relevant($0, current: Vault.load()) } ?? false
                if !relevant || state.map(CommandPolicy.owns) == true || state?["operation_status"] as? String == "cancelled" {
                    clear(id); trace(id, "alert_recovery_removed")
                }
            }
        }
        // Read-only reconciliation can cancel a missing-receipt timer when HA's
        // acknowledgment was lost. It never submits or wakes anything.
        for entry in CommandDelivery.shared.alertRecords() where fallback(entry.id) {
            await CommandDelivery.shared.reconcile(entry.id)
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        guard request.identifier.hasPrefix("command-") else { completionHandler([.banner, .sound]); return }
        let id = String(request.identifier.dropFirst(8))
        Task { @MainActor in
            let handoff = request.content.userInfo["kind"] as? String != "outcome"
            let relevant = self.record(id).map { CommandAlertPolicy.relevant($0, current: Vault.load()) } ?? false
            let state = self.record(id).flatMap { $0.result }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            guard relevant, state.map(CommandPolicy.owns) != true, state?["operation_status"] as? String != "cancelled",
                  !handoff || self.fallback(id) else {
                self.clear(id); self.trace(id, "alert_suppressed"); completionHandler([]); return
            }
            self.markDelivered(id); self.trace(id, "alert_presented")
            completionHandler([.banner, .sound])
        }
    }
    func outcome(_ id: String, state: [String: Any]) {
        guard state["operation_id"] as? String == id else { return }
        if CommandPolicy.owns(state) || state["operation_status"] as? String == "cancelled" { clear(id); return }
        guard ["failed", "unconfirmed"].contains(state["operation_status"] as? String ?? "") else { return }
        // Cancel the fallback, but retain any delivered alert until deduplication
        // checks it. Clearing first would hide evidence and allow a second alert.
        generations.removeValue(forKey: id)
        center.removePendingNotificationRequests(withIdentifiers: ["command-" + id])
        guard let entry = record(id), CommandAlertPolicy.localOutcome(entry, state: state, current: Vault.load()) else {
            clear(id); trace(id, "alert_suppressed"); return
        }
        guard !wasDelivered(id) else { return }
        let ticket = UUID(); generations[id] = ticket
        Task {
            let delivered = await center.deliveredNotifications()
            guard generations[id] == ticket else { return }
            if delivered.contains(where: { $0.request.identifier == "command-" + id }) {
                markDelivered(id); trace(id, "alert_duplicate_suppressed"); return
            }
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true,
                  generations[id] == ticket, let latest = record(id),
                  CommandAlertPolicy.localOutcome(latest, state: state, current: Vault.load()), !wasDelivered(id) else { return }
            markDelivered(id)
            let content = UNMutableNotificationContent()
            content.title = state["operation_status"] as? String == "failed" ? "Fan Control request failed" : "Fan Control not confirmed"
            content.body = "Home Assistant could not confirm the requested outcome."
            content.sound = .default
            content.userInfo = ["operation_id": id, "kind": "outcome"]
            try? await center.add(UNNotificationRequest(identifier: "command-" + id, content: content, trigger: nil))
            if generations[id] != ticket { clear(id) }
            else { trace(id, "alert_outcome_scheduled") }
        }
    }
}
