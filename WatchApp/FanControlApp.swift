import SwiftUI
import WatchKit
import FanControlCore

@main struct FanControlApp: App {
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
    var device: Device? { connection?.devices.first { $0.entity == (sessionTarget ?? connection?.entity) } }
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
        if resetSelection { connection = Vault.load(); sessionTarget = nil; feedback = nil }
        observed = connection.flatMap { c in device.map { ObservationCache.shared.load(c, $0) } } ?? [:]
        BackgroundRefresh.schedule()
        #if DEBUG
        if let preview = ControlPreview.snapshot() {
            connection = preview.0; observed = preview.1; stateFresh = true
            if ProcessInfo.processInfo.arguments.contains("--preview-pending") {
                feedback = Feedback(target: preview.0.identity, command: "climate_off", label: "Climate OFF")
            }
            let args = ProcessInfo.processInfo.arguments
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
        guard let c = connection, let current = device,
              let index = c.devices.firstIndex(of: current), c.devices.count > 1 else { return }
        let next = (index + direction + c.devices.count) % c.devices.count
        leave(resetReceipts: false); sessionTarget = c.devices[next].entity; observed = [:]; feedback = nil
        enter(resetSelection: false)
    }
    private func panelBody(_ p: Panel, command: String? = nil) -> [String: Any] {
        var body: [String: Any] = ["action": command == nil ? "panel_state" : "panel_command", "panel_id": p.id]
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
        if action == "start_exercise", let url = URL(string: "spotify:") {
            WKExtension.shared().openSystemURL(url)
            musicEvidence = "Spotify playback unknown"
        }
        command = Task {
            let deadline = Date().addingTimeInterval(60)
            let operationID = UUID().uuidString.lowercased()
            let issued = Int(Date().timeIntervalSince1970 * 1000)
            var sent = false
            var musicSent = false
            var completed = false
            var receiptAccepted = false
            defer {
                if ticket == generation && feedback?.id == f.id && feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
                if ticket == generation && receiptAction && !receiptAccepted { actionReceipts.finish(f, accepted: false) }
                if action == "stop_exercise" && !completed && !receiptAccepted {
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
                    guard live == c else { throw ControlError.invalidConfiguration }
                    try Task.checkCancellation()
                    guard ticket == generation, feedback?.id == f.id else { return }
                    var state = try await client.request(stateBody(d))
                    var body = d.panel.map { panelBody($0, command: action) } ?? ["action": "command", "entity": d.entity, "command": action]
                    if action == "stop_exercise" { body["operation_id"] = operationID; body["issued_at_ms"] = issued }
                    let available: Bool
                    if let p = d.panel, p.type != "fan" {
                        let ready = !p.vehicle || state["vehicle_ready"] as? Bool == true || action.hasPrefix("garage_")
                        if action.hasPrefix("garage_") || action.hasPrefix("trunk_") { available = ready && state[action + "_available"] as? Bool == true }
                        else if action.hasPrefix("climate_") { available = ready && state["climate_available"] as? Bool == true && (action != "climate_off" || p.type != "driving" || state["climate_off_available"] as? Bool == true) }
                        else if action == "honk" { available = ready && state["honk_available"] as? Bool == true }
                        else if action == "podcast" { available = state["podcast_available"] as? Bool == true }
                        else { available = ready && state[action == "leave" ? "script_available" : action == "start_exercise" ? "start_available" : "stop_available"] as? Bool == true }
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
                        if receiptAction && commandResponded {
                            guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                            guard ActionReceipts.acknowledges(action, response: state) else { throw ControlError.notConfirmed }
                            receiptAccepted = true; actionReceipts.finish(f, accepted: true)
                        }
                        if action == "activate" || action == "leave" || action == "honk" || action == "podcast" || action == "stop_exercise" && receiptAccepted {
                            guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                            feedback?.phase = .accepted; message = "Request accepted"; return
                        }
                    }
                    if action == "start_exercise" && !musicSent && sent {
                        musicSent = true
                        // Music has its own one-shot evidence and cannot confirm vehicle state.
                        do { _ = try await client.request(panelBody(d.panel!, command: "start_music")); musicEvidence = "Music dispatch accepted · playback unknown" }
                        catch { musicEvidence = "Music not confirmed" }
                    }
                    guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                    if receiptAccepted { feedback?.phase = .accepted; message = ""; return }
                    // Preserve the separate one-shot music request after an
                    // ambiguous Start response, without treating a later state
                    // read as this tap's receipt. Stop keeps its existing stable
                    // operation-ID delivery retries until HA acknowledges it.
                    if action == "start_exercise" && sent { throw ControlError.notConfirmed }
                    if sent && Evidence.matches(action, state, panel: d.panel) {
                        completed = true
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
    func forget() { leave(); ObservationCache.shared.clear(); Vault.clear(); connection = nil; observed = [:]; feedback = nil }
}





