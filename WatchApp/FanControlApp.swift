import SwiftUI
import WatchKit
import UserNotifications
import FanControlCore

@main struct FanControlApp: App {
    init() { UNUserNotificationCenter.current().delegate = ExerciseAlerts.shared }
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
    private var client: Integration?
    private var work: Task<Void, Never>?
    private var command: Task<Void, Never>?
    private var draft: Task<Void, Never>?
    private var generation = UUID()
    private var visible = false
    @Published private var sessionTarget: String?
    @Published private(set) var showingSettings = false
    var device: Device? {
        guard !showingSettings else { return nil }
        return connection?.devices.first { $0.entity == (sessionTarget ?? connection?.entity) }
    }
    var busy: Bool { feedback?.phase == .pending }
    // Action requests can start before the first observation. Keep entry reads
    // running so the settled visible-entry wake cannot be blocked by that tap.
    private var canRefresh: Bool { !busy || feedback.map { ActionReceipts.applies($0.command) } == true }
    var canAdjustSpeed: Bool { stateFresh && device?.domain == "fan" && (!busy || feedback?.command == "turn_on") && ["on", "off"].contains(observed["state"] as? String ?? "") }
    func leave(resetReceipts: Bool = true) {
        if resetReceipts { actionReceipts.clear() }
        visible = false; generation = UUID(); work?.cancel(); command?.cancel(); draft?.cancel(); speedDraft = nil
        if feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
        stateFresh = false
    }
    func enter(resetSelection: Bool = true) {
        // A refresh launch can instantiate the view without user-visible entry.
        guard WKExtension.shared().applicationState == .active else { return }
        leave(resetReceipts: resetSelection); visible = true
        if resetSelection { connection = Vault.load(); sessionTarget = nil; showingSettings = false; feedback = nil }
        observed = connection.flatMap { c in device.map { ObservationCache.shared.load(c, $0) } } ?? [:]
        BackgroundRefresh.schedule()
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
        client = Integration(connection)
        let ticket = generation
        work = Task {
            // Resolve HA's current selection before the entry wake. A saved
            // connection may still name a different car after a watch-face tap.
            await refresh(ticket)
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            var wakeAttempted = false
            while !Task.isCancelled && ticket == generation && visible {
                if stateFresh, !wakeAttempted, let p = device?.panel, p.vehicle {
                    wakeAttempted = true
                    _ = try? await client?.request(panelBody(p, command: "wake"))
                }
                if canRefresh && speedDraft == nil { await refresh(ticket) }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    func swipe(_ direction: Int) {
        guard let c = connection else { return }
        let current: WatchPage = showingSettings ? .settings : .device(sessionTarget ?? c.entity)
        let next = WatchPage.next(current, entities: c.devices.map(\.entity), active: c.entity, direction: direction)
        leave(resetReceipts: false); observed = [:]; feedback = nil
        switch next {
        case .settings: showingSettings = true
        case .device(let entity): showingSettings = false; sessionTarget = entity
        }
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
    private func refresh(_ ticket: UUID) async {
        guard let old = connection, let client else { return }
        do {
            let config = try await client.request(["action": "config", "platform": "watch_os"])
            var complete = config; complete["token"] = old.token; complete["watch_id"] = old.watch_id
            let next = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: complete)).validated()
            guard ticket == generation, !Task.isCancelled, canRefresh else { return }
            if next != old {
                ExercisePlayer.shared.stopIfTargetChanged(next)
                if next.devices != old.devices || next.watch_id != old.watch_id { actionReceipts.clear() }
                try Vault.save(next); connection = next; observed = [:]; feedback = nil
                if !next.devices.contains(where: { $0.entity == sessionTarget }) { sessionTarget = nil }
                enter(resetSelection: false); return
            }
            guard let d = device else { observed = [:]; return }
            let state = try await client.request(stateBody(d))
            guard ticket == generation, !Task.isCancelled, canRefresh else { return }
            ObservationCache.shared.save(state, connection: old, device: d)
            if d.domain == "fan", !["on", "off"].contains(state["state"] as? String ?? "") {
                observed = ObservationCache.shared.load(old, d); stateFresh = false
            } else { observed = state; stateFresh = true }
            message = ""
            if !busy && speedDraft == nil { feedback = nil }
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            // A failed read is not an HA observation of unknown/off. Retain only
            // this visible target's last observation in gray. Its toggle stays tappable.
            stateFresh = false; message = "Connection interrupted"
            if case ControlError.rejected(let status) = error, [401, 403].contains(status), connection == old { forget(); message = "Watch access revoked. Pair again." }
        }
    }
    func actionFeedback(_ action: String) -> Feedback? {
        guard let c = connection, let d = device else { return nil }
        return actionReceipts.feedback(target: c.watch_id + "|" + d.entity, command: action)
    }
    func adjust(_ delta: Int) {
        guard canAdjustSpeed else { return }
        let percentage = (observed["attributes"] as? [String: Any])?["percentage"] as? Int ?? 0
        let current = Evidence.percentages.firstIndex(where: { $0 >= percentage }).map { $0 + 1 } ?? 6
        speedDraft = min(6, max(1, (speedDraft ?? current) + delta))
        draft?.cancel()
        let ticket = generation
        draft = Task {
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            // Draft changes are allowed during ON confirmation; delivery stays
            // serialized and never clears or inverts the original power intent.
            while busy {
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
            guard ticket == generation, visible, !Task.isCancelled, stateFresh else { return }
            guard let speed = speedDraft else { return }; speedDraft = nil
            send("speed\(speed)", label: "Speed \(speed)")
        }
    }
    func send(_ action: String, label: String) {
        let receiptAction = ActionReceipts.applies(action)
        let toggle = ToggleIntent.family(action) != nil
        let replacing = busy && ToggleIntent.replaces(action, feedback?.command)
        guard (!busy || replacing), receiptAction || toggle || stateFresh, visible,
              let c = connection, let d = device, let client else { return }
        if replacing { command?.cancel() }
        draft?.cancel(); speedDraft = nil
        let requested = RequestedPresentation.label(command: action, original: label)
        let f = Feedback(target: receiptAction ? c.watch_id + "|" + d.entity : c.identity, command: action, label: requested)
        if receiptAction { actionReceipts.begin(f) }
        feedback = f; message = "Requested"; musicEvidence = ""
        let ticket = generation
        if action == "start_exercise" {
            ExercisePlayer.shared.start(c, target: d)
        }
        if action == "stop_exercise" { ExercisePlayer.shared.stop() }
        let exerciseAlert = ["start_exercise", "stop_exercise"].contains(action) ? ExerciseAlerts.shared.begin(target: c.watch_id + "|" + d.entity, action: action) : nil
        command = Task {
            let deadline = Date().addingTimeInterval(60)
            let operationID = UUID().uuidString.lowercased()
            let issued = Int(Date().timeIntervalSince1970 * 1000)
            var sent = false
            var completed = false
            var receiptAccepted = false
            var stopAccepted = false
            defer {
                if ticket == generation && feedback?.id == f.id && feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
                if ticket == generation && receiptAction && !receiptAccepted { actionReceipts.finish(f, accepted: false) }
                if action == "stop_exercise" && !completed && !stopAccepted {
                    var cancel = panelBody(d.panel!, command: "cancel_stop"); cancel["operation_id"] = operationID
                    let cancellationBody = cancel
                    Task { _ = try? await client.request(cancellationBody) }
                }
            }
            do {
                while Date() < deadline {
                    try Task.checkCancellation()
                    guard ticket == generation, connection == c, visible else { throw CancellationError() }
                    // Revalidate the exact configuration before dispatch; never redirect an old tap.
                    let config = try await client.request(["action": "config", "platform": "watch_os"])
                    var full = config; full["token"] = c.token; full["watch_id"] = c.watch_id
                    let live = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: full)).validated()
                    // HA may select Driving after this accepted Stop completes.
                    // Keep polling the same approved operation, never a new target.
                    var comparable = live
                    if action == "stop_exercise" && stopAccepted { comparable.entity = c.entity }
                    guard comparable == c else { throw ControlError.invalidConfiguration }
                    try Task.checkCancellation()
                    guard ticket == generation, feedback?.id == f.id else { return }
                    var state: [String: Any] = [:]
                    if action != "stop_exercise" { state = try await client.request(stateBody(d)) }
                    var body = d.panel.map { panelBody($0, command: action) } ?? ["action": "command", "entity": d.entity, "command": action]
                    if action == "start_exercise" || action == "stop_exercise" { body["music_mode"] = "local" }
                    if action == "start_exercise" || action == "stop_exercise" { body["operation_id"] = operationID; body["issued_at_ms"] = issued }
                    let available: Bool
                    if let p = d.panel, p.type != "fan" {
                        let ready = !p.vehicle || state["vehicle_ready"] as? Bool == true || action.hasPrefix("garage_")
                        if action.hasPrefix("garage_") || action.hasPrefix("trunk_") { available = ready && state[action + "_available"] as? Bool == true }
                        else if action.hasPrefix("climate_") { available = ready && state["climate_available"] as? Bool == true && (action != "climate_off" || p.type != "driving" || state["climate_off_available"] as? Bool == true) }
                        else if action == "honk" { available = ready && state["honk_available"] as? Bool == true }
                        else if action == "podcast" { available = state["podcast_available"] as? Bool == true }
                        else if action == "stop_exercise" { available = true }
                        else { available = ready && state[action == "leave" ? "script_available" : "start_available"] as? Bool == true }
                    } else { available = ["on", "off"].contains(state["state"] as? String ?? "") || ["script", "scene"].contains(d.domain) && !["unknown", "unavailable", ""].contains(state["state"] as? String ?? "") }
                    try Task.checkCancellation()
                    guard ticket == generation, feedback?.id == f.id, connection == c else { return }
                    if available && (!sent || action == "stop_exercise") {
                        sent = true // Ambiguous responses must never replay one-shot actions.
                        var commandResponded = false
                        do { state = try await client.request(body); commandResponded = true }
                        catch {
                            try Task.checkCancellation()
                            if case ControlError.rejected = error { throw error }
                            if action == "activate" || action == "leave" || action == "honk" || action == "podcast" { throw error }
                            // Delivery may have happened. Poll evidence without replaying the command.
                            state = [:]
                        }
                        if receiptAction && commandResponded && (action != "start_exercise" || Evidence.matches(action, state, panel: d.panel)) {
                            guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                            if action == "stop_exercise", ["pending", "complete"].contains(state["operation_status"] as? String ?? "") {
                                // HA owns bounded continuation once accepted, even though
                                // the UI stays gray until the operation actually completes.
                                stopAccepted = true
                            }
                            guard ActionReceipts.acknowledges(action, response: state) else {
                                if action != "stop_exercise" || state["operation_status"] as? String != "pending" { throw ControlError.notConfirmed }
                                // Keep polling this operation; acceptance alone is not completion.
                                try await Task.sleep(nanoseconds: 700_000_000)
                                continue
                            }
                            receiptAccepted = true; actionReceipts.finish(f, accepted: true)
                            if let exerciseAlert, Evidence.matches(action, state, panel: d.panel) { ExerciseAlerts.shared.confirm(exerciseAlert) }
                        }
                        if action == "activate" || action == "leave" || action == "honk" || action == "podcast" || action == "stop_exercise" && receiptAccepted {
                            guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                            feedback?.phase = .accepted; message = "Request accepted"; return
                        }
                    }
                    guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                    if receiptAccepted { feedback?.phase = .accepted; message = ""; return }
                    // Start is dispatched once; subsequent reads only establish
                    // its lock outcome. Stop retains its stable operation ID.
                    if sent && Evidence.matches(action, state, panel: d.panel) {
                        completed = true
                        if receiptAction { actionReceipts.finish(f, accepted: true) }
                        if let exerciseAlert { ExerciseAlerts.shared.confirm(exerciseAlert) }
                        ObservationCache.shared.save(state, connection: c, device: d)
                        observed = state; stateFresh = true; feedback?.phase = .confirmed; message = ""; return
                    }
                    try await Task.sleep(nanoseconds: 700_000_000)
                }
            } catch { }
            guard ticket == generation, feedback?.id == f.id else { return }
            feedback?.phase = .unconfirmed; message = "Not confirmed"

        }
    }
    func cancel() {
        draft?.cancel(); speedDraft = nil; command?.cancel()
        if busy { feedback?.phase = .unconfirmed; message = "Not confirmed" }
    }
    func paired(_ value: Connection) { connection = value; enter() }
    func forget() { leave(); showingSettings = false; ExercisePlayer.shared.forget(); ObservationCache.shared.clear(); Vault.clear(); connection = nil; observed = [:]; feedback = nil }
}





