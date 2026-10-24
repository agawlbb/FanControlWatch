import SwiftUI
import WatchKit
import UserNotifications
import FanControlCore

@main struct FanControlApp: App {
    @WKApplicationDelegateAdaptor(PushNotifications.self) private var pushDelegate
    init() { UNUserNotificationCenter.current().delegate = ExerciseAlerts.shared; WatchCompanion.shared.start(); CommandDelivery.shared.recover() }
    var body: some Scene {
        WindowGroup { ControlsView() }
            .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) { await BackgroundRefresh.run() }
    }
}
@MainActor final class WatchModel: ObservableObject {
    @Published var connection = Vault.load()
    @Published var observed: [String: Any] = [:]
    @Published var stateFresh = false
    @Published var feedback: Feedback?
    @Published var message = ""
    @Published var speedDraft: Int?
    @Published var musicEvidence = ""
    @Published private var actionReceipts = ActionReceipts()
    private var work: Task<Void, Never>?
    private var command: Task<Void, Never>?
    private var vehicleIntent: (client: Integration, id: String, alert: String?)?
    private var generation = UUID()
    private var visible = false
    private let defaultTile = DefaultWatchTile()
    private var wakeAfter: ContinuousClock.Instant?
    @Published private var sessionTarget: String?
    @Published private(set) var showingSettings = false
    var device: Device? {
        guard !showingSettings else { return nil }
        return connection?.devices.first { $0.entity == (sessionTarget ?? connection?.entity) }
    }
    var busy: Bool { feedback?.phase == .pending }
    var canAdjustSpeed: Bool { visible && device?.domain == "fan" && (!busy || feedback?.command == "turn_on" || feedback?.command.hasPrefix("speed") == true) }
    var displayedSpeed: Int {
        if let speedDraft { return speedDraft }
        if let command = feedback?.command, command.hasPrefix("speed"), let value = Int(command.dropFirst(5)) { return value }
        let percentage = (observed["attributes"] as? [String: Any])?["percentage"] as? Int ?? 16
        return Evidence.percentages.firstIndex(where: { $0 >= percentage }).map { $0 + 1 } ?? 6
    }
    func leave(resetReceipts: Bool = true) {
        if resetReceipts { actionReceipts.clear() }
        visible = false; generation = UUID(); work?.cancel(); command?.cancel(); speedDraft = nil
        if feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
        stateFresh = false
    }
    func enter(resetSelection: Bool = true, allowEntryWake: Bool = true) {
        // A refresh launch can instantiate the view without user-visible entry.
        guard WKExtension.shared().applicationState == .active else { return }
        leave(resetReceipts: resetSelection); visible = true
        if resetSelection { WatchCompanion.shared.beginEntry(); connection = Vault.load(); sessionTarget = connection.flatMap { defaultTile.load($0) }; showingSettings = false; feedback = nil; wakeAfter = nil }
        // Migrate older unlocked-only keychain entries before the next wrist-down push.
        if let connection { try? Vault.save(connection) }
        if let connection, resetSelection {
            PushDiagnostics.shared.record("opened", connection: connection)
        }
        observed = connection.flatMap { c in device.map { ObservationCache.shared.load(c, $0) } } ?? [:]
        WatchCompanion.shared.requestLatest()
        // Settings is local navigation, with no device reads, entry wake or controls.
        if showingSettings { observed = [:]; return }
        #if DEBUG
        if let preview = ControlPreview.snapshot() {
            connection = preview.0; observed = preview.1; stateFresh = true
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--preview-exercise") {
                ExercisePlayer.shared.preview(playing: ProcessInfo.processInfo.arguments.contains("--preview-playing"))
            }
            #endif
            if ProcessInfo.processInfo.arguments.contains("--preview-pending") {
                feedback = Feedback(target: preview.0.identity, command: "climate_off", label: "Climate OFF")
            }
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--preview-settings") { showingSettings = true; observed = [:]; return }
            if args.contains("--preview-action-pending") || args.contains("--preview-action-accepted") {
                let action = args.contains("--preview-exercise") ? "start_exercise" : "honk"
                let f = Feedback(target: preview.0.watch_id + "|panel.preview", command: action, label: "Activated")
                actionReceipts.begin(f)
                if args.contains("--preview-action-accepted") { actionReceipts.finish(f, accepted: true) }
                else { feedback = f }
            }
            return
        }
        #endif
        guard let connection else { return }
        if let d = device { resumeCommand(connection, d) }
        let ticket = generation
        work = Task {

            // A foreground entry asks the phone once. Only explicit visible
            // vehicle entry and user commands perform watch-side HA work.
            if let deadline = wakeAfter {
                do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            }
            guard !Task.isCancelled, ticket == generation, visible,
                  allowEntryWake, let d = device, let p = d.panel, p.vehicle else { return }
            do {
                let raw = try await Integration(connection).request(["action": "config", "platform": "watch_os"])
                var full = raw; full["token"] = connection.token; full["watch_id"] = connection.watch_id
                let live = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: full)).validated()
                guard ticket == generation, visible, !Task.isCancelled,
                      live.devices.contains(d), live.watch_id == connection.watch_id, live.token == connection.token,
                      WKExtension.shared().applicationState == .active else { return }
                guard raw["vehicle_operations_version"] as? Int == 1 else { return }
                var body = panelBody(p, command: "wake")
                body["action"] = "vehicle_submit"
                body["operation_id"] = UUID().uuidString.lowercased()
                body["issued_at_ms"] = Int(Date().timeIntervalSince1970 * 1000)
                _ = try? await Integration(live).request(body)
            } catch { /* A stale entry never wakes another target. */ }
        }
    }
    func swipe(_ direction: Int) {
        guard let c = connection else { return }
        let current: WatchPage = showingSettings ? .settings : .device(sessionTarget ?? c.entity)
        let next = WatchPage.next(current, entities: (c.companion_settings ?? CompanionSettings()).ordered(c.devices.map(\.entity)), direction: direction)
        leave(resetReceipts: false); observed = [:]; feedback = nil
        switch next {
        case .settings: showingSettings = true
        case .device(let entity):
            showingSettings = false; sessionTarget = entity
            defaultTile.save(entity, connection: c)
        }
        wakeAfter = .now.advanced(by: .milliseconds(1500))
        enter(resetSelection: false)
    }
    private func panelBody(_ p: Panel, command: String? = nil) -> [String: Any] {
        var body: [String: Any] = ["action": command == nil ? "panel_state" : "panel_command", "panel_id": p.id]
        if p.type == "exercise" { body["music_mode"] = "local" }
        if let command { body["command"] = command; body["panel_config"] = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) }
        return body
    }
    private func stateBody(_ d: Device) -> [String: Any] {
        if let p = d.panel { return panelBody(p) }
        return ["action": "state", "entity": d.entity]
    }
    func actionFeedback(_ action: String) -> Feedback? {
        guard let c = connection, let d = device else { return nil }
        return actionReceipts.feedback(target: c.watch_id + "|" + d.entity, command: action)
    }
    func adjust(_ delta: Int) {
        guard canAdjustSpeed else { return }
        let speed = min(6, max(1, displayedSpeed + delta))
        speedDraft = speed
        // HA owns the quiet window too: a saved request cannot vanish on wrist-down.
        send("speed\(speed)", label: "Speed \(speed)", quietWindow: true)
    }
    func send(_ action: String, label: String, quietWindow: Bool = false) {
        let replacing = busy && (ToggleIntent.replaces(action, feedback?.command) || quietWindow)
        guard (!busy || replacing), visible, let c = connection, let d = device else { return }
        WatchCompanion.shared.protectIntent(d.entity)
        command?.cancel()
        if !quietWindow { speedDraft = nil }
        let f = Feedback(target: ActionReceipts.applies(action) ? c.watch_id + "|" + d.entity : c.identity,
                         command: action, label: RequestedPresentation.label(command: action, original: label))
        feedback = f; message = "Requested"; musicEvidence = ""
        if ActionReceipts.applies(action) { actionReceipts.begin(f) }
        if action == "start_exercise" { ExercisePlayer.shared.start(c, target: d) }
        if action == "stop_exercise" { ExercisePlayer.shared.stop() }
        var body = d.panel.map { panelBody($0, command: action) } ?? ["entity": d.entity, "command": action]
        let identity = UUID().uuidString.lowercased()
        let issued = Int(Date().timeIntervalSince1970 * 1000)
        body["action"] = "operation_submit"; body["operation_id"] = identity; body["issued_at_ms"] = issued
        if quietWindow { body["not_before_ms"] = issued + 1000 }
        do { try CommandDelivery.shared.enqueue(body, connection: c, device: d) }
        catch { feedback?.phase = .unconfirmed; message = "Could not save request"; return }
        monitor(identity, body: body, connection: c, device: d, feedback: f)
    }
    private func monitor(_ identity: String, body: [String: Any], connection c: Connection, device d: Device, feedback f: Feedback) {
        let ticket = generation
        let client = Integration(c)
        vehicleIntent = (client, identity, nil)
        command = Task {
            let issued = body["issued_at_ms"] as? Int ?? 0
            let deadline = Date(timeIntervalSince1970: Double(issued) / 1000 + VehicleOperation.alertSeconds)
            var submitted = Date() >= deadline
            var first = true
            var saved = CommandDelivery.shared.pending(connection: c, device: d).flatMap { $0.id == identity ? $0.result : nil }
            while first || Date() < deadline {
                first = false
                if Task.isCancelled { return }
                do {
                    // Submit directly. HA authenticates and validates the captured target;
                    // preflight reads must never stand between the tap and acceptance.
                    let state: [String: Any]
                    if let data = saved, let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       ["complete", "accepted", "failed", "cancelled", "unconfirmed"].contains(result["operation_status"] as? String ?? "") {
                        state = result
                    } else { state = try await client.request(submitted ? ["action": "operation_status", "operation_id": identity] : body) }
                    saved = nil
                    guard state["operation_id"] as? String == identity else { throw ControlError.invalidResponse }
                    let status = state["operation_status"] as? String ?? "unknown"
                    submitted = status != "unknown"
                    CommandDelivery.shared.outcome(identity, state: state)
                    guard !Task.isCancelled, visible, ticket == generation, feedback?.id == f.id else { return }
                    if status == "complete" || status == "accepted" {
                        speedDraft = nil
                        if ActionReceipts.applies(f.command) {
                            actionReceipts.finish(f, accepted: true); feedback?.phase = .accepted; message = "Request accepted"
                        } else if status == "complete" {
                            ObservationCache.shared.save(state, connection: c, device: d)
                            observed = state; stateFresh = true; feedback?.phase = .confirmed; message = ""
                        } else { feedback?.phase = .unconfirmed; message = "Not confirmed" }
                        return
                    }
                    if ["failed", "cancelled", "unconfirmed"].contains(status) {
                        speedDraft = nil; feedback?.phase = .unconfirmed
                        if ActionReceipts.applies(f.command) { actionReceipts.finish(f, accepted: false) }
                        message = status == "failed" ? "Request failed" : status == "cancelled" ? "Cancelled" : "Not confirmed"
                        return
                    }
                    message = VehicleOperation.progress(state["stage"] as? String ?? "")
                } catch {
                    if Task.isCancelled { return }
                    if case ControlError.rejected(let code) = error, code != 429 && code < 500 {
                        guard ticket == generation, feedback?.id == f.id else { return }
                        CommandDelivery.shared.rejected(identity)
                        feedback?.phase = .unconfirmed; message = "Request rejected"
                        if ActionReceipts.applies(f.command) { actionReceipts.finish(f, accepted: false) }
                        return
                    }
                    // Stable IDs make both endpoint fallback and retry safe.
                }
                do { try await Task.sleep(nanoseconds: 1_500_000_000) } catch { return }
            }
            guard ticket == generation, feedback?.id == f.id else { return }
            speedDraft = nil; feedback?.phase = .unconfirmed; message = "Not confirmed"
        }
    }
    private func resumeCommand(_ c: Connection, _ d: Device) {
        guard let entry = CommandDelivery.shared.pending(connection: c, device: d),
              let body = try? JSONSerialization.jsonObject(with: entry.body) as? [String: Any],
              let action = body["command"] as? String else { return }
        let f = Feedback(target: ActionReceipts.applies(action) ? c.watch_id + "|" + d.entity : c.identity,
                         command: action, label: RequestedPresentation.label(command: action, original: "Requested"))
        feedback = f
        if ActionReceipts.applies(action) { actionReceipts.begin(f) }
        monitor(entry.id, body: body, connection: c, device: d, feedback: f)
    }
    func cancel() {
        if let intent = vehicleIntent {
            Task { _ = try? await intent.client.request(["action": "operation_cancel", "operation_id": intent.id]) }
        }
        command?.cancel(); speedDraft = nil
        if busy { feedback?.phase = .unconfirmed; message = "Cancelled" }
    }
    func receiveCompanion() {
        guard let saved = Vault.load() else { return }
        // Invalidate older navigation even when a command defers visible selection.
        _ = defaultTile.load(saved)
        // Persisted snapshots can arrive during a command. Never clear or
        // recolor that intent; apply selection on its next safe entry.
        guard feedback == nil, speedDraft == nil else { return }
        let changed = connection.map { !$0.sameTarget(as: saved) || $0.revision != saved.revision } ?? true
        connection = saved
        if changed { enter(resetSelection: true, allowEntryWake: false) }
        else if let d = device { observed = ObservationCache.shared.load(saved, d); stateFresh = false }
    }
    func paired(_ value: Connection) { if connection?.watch_id != value.watch_id || connection?.token != value.token { CommandDelivery.shared.clear() }; connection = value; WatchCompanion.shared.provision(); enter() }
    func forget() { CommandDelivery.shared.clear(); defaultTile.clear(); leave(); showingSettings = false; ExercisePlayer.shared.forget(); ObservationCache.shared.clear(); PushDiagnostics.shared.clear(); Vault.clear(); connection = nil; observed = [:]; feedback = nil }
}





