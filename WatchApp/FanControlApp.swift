import SwiftUI
import WatchKit
import FanControlCore

@main struct FanControlApp: App {
    var body: some Scene { WindowGroup { ControlsView() } }
}
@MainActor final class WatchModel: ObservableObject {
    @Published var connection = Vault.load()
    @Published var observed: [String: Any] = [:]
    @Published var feedback: Feedback?
    @Published var message = ""
    @Published var speedDraft: Int?
    @Published var musicEvidence = ""
    private var client: Integration?
    private var work: Task<Void, Never>?
    private var command: Task<Void, Never>?
    private var draft: Task<Void, Never>?
    private var generation = UUID()
    private var visible = false
    var device: Device? { connection?.active }
    var busy: Bool { feedback?.phase == .pending }
    func leave() {
        visible = false; generation = UUID(); work?.cancel(); command?.cancel(); draft?.cancel(); speedDraft = nil
        if feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
        observed = [:]
    }
    func enter() {
        leave(); visible = true
        guard let connection else { return }
        client = Integration(connection)
        let ticket = generation
        work = Task {
            // Wake only after the selected page has remained visible and settled.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, ticket == generation, visible else { return }
            if let p = device?.panel, p.vehicle {
                _ = try? await client?.request(panelBody(p, command: "wake"))
            }
            while !Task.isCancelled && ticket == generation && visible {
                if !busy && speedDraft == nil { await refresh(ticket) }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
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
        guard let old = connection, let client, let d = old.active else { return }
        do {
            let config = try await client.request(["action": "config"])
            var complete = config; complete["token"] = old.token; complete["watch_id"] = old.watch_id
            let next = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: complete)).validated()
            guard ticket == generation, !Task.isCancelled, !busy else { return }
            if next != old {
                try Vault.save(next); connection = next; observed = [:]; feedback = nil; enter(); return
            }
            let state = try await client.request(stateBody(d))
            guard ticket == generation, !Task.isCancelled, !busy else { return }
            observed = state; message = ""
            if feedback?.phase == .unconfirmed { feedback = nil }
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            observed = [:]; message = "State unknown · Refresh available"
            if case ControlError.rejected(let status) = error, [401, 403].contains(status), connection == old { forget(); message = "Watch access revoked. Pair again." }
        }
    }
    func adjust(_ delta: Int) {
        guard !busy, device?.domain == "fan", observed["state"] as? String == "on" || observed["state"] as? String == "off" else { return }
        let percentage = (observed["attributes"] as? [String: Any])?["percentage"] as? Int ?? 0
        let current = Evidence.percentages.firstIndex(where: { $0 >= percentage }).map { $0 + 1 } ?? 6
        speedDraft = min(6, max(1, (speedDraft ?? current) + delta))
        draft?.cancel()
        draft = Task {
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            guard let speed = speedDraft else { return }; speedDraft = nil
            send("speed\(speed)", label: "Speed \(speed)")
        }
    }
    func send(_ action: String, label: String) {
        guard !busy, visible, let c = connection, let d = c.active, let client else { return }
        draft?.cancel(); speedDraft = nil
        let requested = RequestedPresentation.label(command: action, original: label)
        let f = Feedback(target: c.identity, command: action, label: requested)
        feedback = f; message = "Requested"; musicEvidence = ""
        let ticket = generation
        if action == "start_exercise", let url = URL(string: "spotify:") {
            WKExtension.shared().openSystemURL(url)
            musicEvidence = "Spotify launch requested; playback unknown"
        }
        command = Task {
            let deadline = Date().addingTimeInterval(60)
            let operationID = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
            let issued = Int(Date().timeIntervalSince1970 * 1000)
            var sent = false
            var musicSent = false
            var completed = false
            defer {
                if ticket == generation && feedback?.id == f.id && feedback?.phase == .pending { feedback?.phase = .unconfirmed; message = "Not confirmed" }
                if action == "stop_exercise" && !completed {
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
                    let config = try await client.request(["action": "config"])
                    var full = config; full["token"] = c.token; full["watch_id"] = c.watch_id
                    let live = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: full)).validated()
                    guard live == c else { throw ControlError.invalidConfiguration }
                    var state = try await client.request(stateBody(d))
                    var body = d.panel.map { panelBody($0, command: action) } ?? ["action": "command", "entity": d.entity, "command": action]
                    if action == "stop_exercise" { body["operation_id"] = operationID; body["issued_at_ms"] = issued }
                    let available: Bool
                    if let p = d.panel {
                        let ready = !p.vehicle || state["vehicle_ready"] as? Bool == true || action.hasPrefix("garage_")
                        if action.hasPrefix("garage_") || action.hasPrefix("trunk_") { available = ready && state[action + "_available"] as? Bool == true }
                        else if action.hasPrefix("climate_") { available = ready && state["climate_available"] as? Bool == true }
                        else { available = ready && state[action == "leave" ? "script_available" : action == "start_exercise" ? "start_available" : "stop_available"] as? Bool == true }
                    } else { available = ["on", "off"].contains(state["state"] as? String ?? "") || ["script", "scene"].contains(d.domain) && !["unknown", "unavailable", ""].contains(state["state"] as? String ?? "") }
                    if available && (!sent || action == "stop_exercise") {
                        sent = true // Ambiguous responses must never replay one-shot actions.
                        do { state = try await client.request(body) }
                        catch {
                            try Task.checkCancellation()
                            if case ControlError.rejected = error { throw error }
                            if action == "activate" || action == "leave" { throw error }
                            // Delivery may have happened. Poll evidence without replaying the command.
                            state = [:]
                        }
                        if action == "activate" || action == "leave" {
                            guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                            feedback?.phase = .accepted; message = "Request accepted"; return
                        }
                    }
                    if action == "start_exercise" && !musicSent && sent {
                        musicSent = true
                        // Music has its own one-shot evidence and cannot confirm vehicle state.
                        do { _ = try await client.request(panelBody(d.panel!, command: "start_music")); musicEvidence = "Music request accepted; playback unknown" }
                        catch { musicEvidence = "Music not confirmed" }
                    }
                    guard ticket == generation, feedback?.id == f.id, !Task.isCancelled else { return }
                    if sent && Evidence.matches(action, state, panel: d.panel) {
                        completed = true; observed = state; feedback?.phase = .confirmed; message = d.panel == nil ? "Confirmed by Home Assistant" : "HA confirmed · physical state not independently verified"; return
                    }
                    try await Task.sleep(nanoseconds: 700_000_000)
                }
            } catch { }
            guard ticket == generation, feedback?.id == f.id else { return }
            feedback?.phase = .unconfirmed; message = "Not confirmed"

        }
    }
    func cancel() { command?.cancel(); if busy { feedback?.phase = .unconfirmed; message = "Not confirmed" } }
    func paired(_ value: Connection) { connection = value; enter() }
    func forget() { leave(); Vault.clear(); connection = nil; feedback = nil }
}





