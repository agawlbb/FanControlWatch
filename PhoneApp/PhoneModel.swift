import Foundation
import SwiftUI
import WatchConnectivity
import BackgroundTasks
import FanControlCore

@MainActor final class PhoneModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneModel()
    @Published private(set) var connection = Vault.load()
    @Published var settings = CompanionSettings()
    @Published var error = ""
    @Published private(set) var reachable = false
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var watchSequence = 0
    @Published private(set) var events: [String] = []
    @Published private(set) var refreshing = false
    var pushToken: String?
    private let session = WCSession.default
    private var snapshot: CompanionSnapshot?
    private var foregroundWork: Task<Void, Never>?
    private var outbox: [[String: Any]] = []
    @Published private(set) var saving = false
    private var defaults: UserDefaults { .standard }
    override private init() {
        super.init()
        if let c = connection { settings = c.companion_settings ?? CompanionSettings() }
        if let raw = defaults.data(forKey: "phoneSnapshot"), let saved = try? JSONDecoder().decode(CompanionSnapshot.self, from: raw),
           let c = connection, (try? saved.resolved(for: c)) != nil { snapshot = saved; refreshedAt = Date(timeIntervalSince1970: Double(saved.atMS) / 1000) }
        events = defaults.stringArray(forKey: "phoneEvents") ?? []
        outbox = defaults.array(forKey: "phoneReceipts") as? [[String: Any]] ?? []
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-companion") {
            let json = """
            {"url":"https://example.invalid","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))","entity":"panel.driving","companion":true,"devices":[{"entity":"panel.driving","title":"Driving"},{"entity":"panel.exercise","title":"Exercise"},{"entity":"fan.office","title":"Office fan"}]}
            """
            connection = try? JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
            settings = CompanionSettings(order: ["fan.office", "panel.driving", "panel.exercise"])
            return
        }
        #endif
        session.delegate = self; session.activate()
    }
    func foreground() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-companion") { return }
        #endif
        foregroundWork?.cancel()
        foregroundWork = Task {
            await registerPush()
            while !Task.isCancelled {
                _ = await refresh()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            }
        }
    }
    func background() {
        foregroundWork?.cancel(); foregroundWork = nil
        let request = BGAppRefreshTaskRequest(identifier: PhoneDelegate.refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PhoneDelegate.refreshID)
        try? BGTaskScheduler.shared.submit(request)
    }
    func link() {
        guard session.activationState == .activated, session.isReachable else { error = "Open Fan Control on your watch."; return }
        session.sendMessage(["action": "link"], replyHandler: nil, errorHandler: { _ in Task { @MainActor in self.error = "Watch unavailable" } })
    }
    func unlink() {
        guard let c = connection else { return }
        Task {
            do {
                _ = try await Integration(c).request(["action": "companion_unlink"])
                guard connection?.token == c.token else { return }
                foregroundWork?.cancel(); connection = nil; snapshot = nil; outbox = []; events = []
                Vault.clear()
                for key in ["phoneSnapshot", "phoneReceipts", "phoneEvents"] { defaults.removeObject(forKey: key) }
                for transfer in session.outstandingFileTransfers { transfer.cancel() }
                for transfer in session.outstandingUserInfoTransfers { transfer.cancel() }
                try? session.updateApplicationContext([:])
            } catch { self.error = "Unlink failed. Try again." }
        }
    }
    func registerPush() async {
        guard let c = connection, let pushToken,
              let environment = Bundle.main.object(forInfoDictionaryKey: "FanControlAPNSEnvironment") as? String else { return }
        do { _ = try await Integration(c).request(["action": "companion_push_register", "device_token": pushToken, "environment": environment == "development" ? "sandbox" : "production"]) }
        catch { record("phone_failed"); self.error = "Push registration failed" }
    }
    @discardableResult func refresh(updateID: String? = nil) async -> Bool {
        guard let original = connection, !refreshing, !saving else { return false }
        refreshing = true; defer { refreshing = false }
        do {
            let response = try await Integration(original).request(["action": "companion_snapshot"])
            try Task.checkCancellation()
            guard connection?.token == original.token else { return false }
            let next = try CompanionSnapshot(response: response, connection: original, updateID: updateID)
            try install(next, original: original)
            record("phone_saved", updateID: updateID)
            await flushReceipts()
            return true
        } catch {
            record("phone_failed", updateID: updateID)
            self.error = "Home Assistant unavailable"
            await flushReceipts()
            return false
        }
    }
    private func install(_ next: CompanionSnapshot, original: Connection) throws {
        if let old = snapshot, old.watchID == next.watchID, old.sequence >= next.sequence { return }
        let c = try next.resolved(for: original)
        try Vault.save(c)
        defaults.set(try JSONEncoder().encode(next), forKey: "phoneSnapshot")
        connection = c; snapshot = next; settings = c.companion_settings ?? CompanionSettings()
        refreshedAt = Date(timeIntervalSince1970: Double(next.atMS) / 1000); error = ""
        publish()
    }
    func saveSettings() {
        guard let original = connection, !saving else { return }
        let value = settings
        saving = true
        Task {
            defer { saving = false }
            do {
                let raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
                let response = try await Integration(original).request(["action": "companion_settings", "revision": original.revision ?? 0, "settings": raw])
                guard connection?.token == original.token else { return }
                let next = try CompanionSnapshot(response: response, connection: original)
                try install(next, original: original)
            } catch {
                settings = connection?.companion_settings ?? CompanionSettings()
                self.error = "Settings not saved. Refresh and try again."
            }
        }
    }
    var orderedDevices: [Device] {
        guard let c = connection else { return [] }
        return settings.ordered(c.devices.map(\.entity)).compactMap { id in c.devices.first { $0.entity == id } }
    }
    func move(_ indices: IndexSet, to destination: Int) {
        var order = orderedDevices.map(\.entity); order.move(fromOffsets: indices, toOffset: destination)
        settings.order = order; saveSettings()
    }
    private func payload() -> [String: Any] {
        var value: [String: Any] = [:]
        if let snapshot, let raw = try? JSONEncoder().encode(snapshot) { value["snapshot"] = raw }
        if let manifest = PhoneLibrary.shared.manifest, manifest.watchID == connection?.watch_id,
           let raw = try? JSONEncoder().encode(manifest) { value["playlist"] = raw }
        return value
    }
    func publish() {
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled, connection != nil else { return }
        do { try session.updateApplicationContext(payload()) }
        catch { self.error = "Watch update pending" }
    }
    func record(_ phase: String, updateID: String? = nil) {
        guard let c = connection else { return }
        let at = Int(Date().timeIntervalSince1970 * 1000)
        var event: [String: Any] = ["id": UUID().uuidString.lowercased(), "phase": phase, "at_ms": at, "panel": c.entity, "revision": c.revision ?? 0, "watch_id": c.watch_id]
        if let updateID { event["update_id"] = updateID }
        outbox.append(event); outbox = Array(outbox.suffix(120)); defaults.set(outbox, forKey: "phoneReceipts")
        events.append("\(Date().formatted(date: .omitted, time: .standard)) · \(phase)")
        events = Array(events.suffix(120)); defaults.set(events, forKey: "phoneEvents")
    }
    private func flushReceipts() async {
        guard let c = connection, !outbox.isEmpty else { return }
        let batch = Array(outbox.prefix(12))
        guard let result = try? await Integration(c).request(["action": "push_receipts", "events": batch]) else { return }
        let acknowledged = Set((result["recorded"] as? [String] ?? []) + (result["discarded"] as? [String] ?? []))
        outbox.removeAll { acknowledged.contains($0["id"] as? String ?? "") }; defaults.set(outbox, forKey: "phoneReceipts")
    }
    private func receive(_ value: [String: Any]) {
        if let grant = value["grant"] as? Data, let c = try? JSONDecoder().decode(Connection.self, from: grant).validated(), c.companion == true {
            do {
                if connection?.token != c.token { snapshot = nil; defaults.removeObject(forKey: "phoneSnapshot"); outbox = []; defaults.removeObject(forKey: "phoneReceipts") }
                try Vault.save(c); connection = c; settings = c.companion_settings ?? CompanionSettings(); error = ""
                Task { await registerPush(); _ = await refresh() }
            } catch { self.error = "Link failed" }
        }
        guard value["watch_id"] as? String == connection?.watch_id else { return }
        if value["watch_opened"] as? Bool == true {
            record("watch_opened")
            // Preserve the watch's actual first-display panel and time separately
            // from the phone's newer cached selection.
            if let last = outbox.indices.last {
                outbox[last]["panel"] = value["panel"] as? String ?? ""
                outbox[last]["revision"] = value["revision"] as? Int ?? 0
                outbox[last]["at_ms"] = value["at_ms"] as? Int ?? outbox[last]["at_ms"]
                defaults.set(outbox, forKey: "phoneReceipts")
            }
        }
        if let seq = value["watch_saved"] as? Int {
            watchSequence = max(watchSequence, seq)
            let update = (value["update_id"] as? String).flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
            record("watch_saved", updateID: update)
            Task { await flushReceipts() }
        }
        if let id = value["playlist_saved"] as? String { PhoneLibrary.shared.acknowledge(id) }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in self.reachable = session.isReachable; self.publish() } }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in PhoneLibrary.shared.transferFinished(fileTransfer, error: error) }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.reachable = session.isReachable } }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            Vault.clear(); self.connection = nil; self.snapshot = nil; self.outbox = []; self.settings = CompanionSettings()
            self.defaults.removeObject(forKey: "phoneSnapshot"); self.defaults.removeObject(forKey: "phoneReceipts")
            session.activate()
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { Task { @MainActor in self.receive(userInfo) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            replyHandler(self.payload()) // Return cache promptly; fetch HA separately.
            if message["action"] as? String == "latest" { _ = await self.refresh() }
        }
    }
}
