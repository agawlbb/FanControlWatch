import Foundation
import WatchKit
import FanControlCore
import OSLog

extension Notification.Name { static let commandOutcomeSaved = Notification.Name("commandOutcomeSaved") }

// The keychain outbox owns intent until HA acknowledges durable acceptance.
// A background upload hands delivery to watchOS immediately, before screen exit.
@MainActor final class CommandDelivery: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = CommandDelivery()
    static let sessionID = "dev.fancontrol.watch.command-delivery"
    typealias Entry = CommandRecord
    private let logger = Logger(subsystem: "dev.fancontrol.watch", category: "command-delivery")
    private var entries: [String: Entry] = [:]
    private var buffers: [Int: Data] = [:]
    private var backgroundTasks: [WKURLSessionRefreshBackgroundTask] = []
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    override init() {
        super.init()
        if let data = SecureCommandStorage.load(), let saved = try? JSONDecoder().decode([String: Entry].self, from: data) { entries = saved }
    }
    func trace(_ id: String, _ phase: String) {
        entries[id]?.mark(phase)
        try? save()
        var events = UserDefaults.standard.array(forKey: "commandTimingEvents") as? [[String: String]] ?? []
        events.append(["id": id, "phase": phase, "at": String(Date().timeIntervalSince1970 * 1000)])
        UserDefaults.standard.set(Array(events.suffix(100)), forKey: "commandTimingEvents")
        logger.info("operation=\(id, privacy: .public) phase=\(phase, privacy: .public)")
    }
    func diagnostics() -> [String] {
        let events = UserDefaults.standard.array(forKey: "commandTimingEvents") as? [[String: String]] ?? []
        var result = events.reversed().map { ($0["id"] ?? "") + " " + ($0["phase"] ?? "") + " " + ($0["at"] ?? "") }
        for entry in entries.values {
            if let data = entry.result, let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timing = state["timing"] as? [String: Any] {
                result.append(entry.id + " HA " + String(describing: timing))
            }
        }
        return result
    }
    private func save() throws { try SecureCommandStorage.save(JSONEncoder().encode(entries)) }
    func enqueue(_ body: [String: Any], connection: Connection, device: Device) throws {
        guard let id = body["operation_id"] as? String, let issued = body["issued_at_ms"] as? Int else { throw ControlError.invalidConfiguration }
        let previous = entries
        let replaced = entries.values.filter { $0.entity == device.entity && $0.connection.watch_id == connection.watch_id }.map(\.id)
        entries = entries.filter { Date().timeIntervalSince($0.value.issued) < 600 }
        entries = entries.filter { $0.value.entity != device.entity || $0.value.connection.watch_id != connection.watch_id }
        // Retain only the latest intent for each target; never recover superseded work.
        entries[id] = Entry(id: id, connection: connection, entity: device.entity, body: try JSONSerialization.data(withJSONObject: body), issued: Date(timeIntervalSince1970: Double(issued) / 1000))
        entries[id]?.timings = ["tap": Double(issued)]
        entries[id]?.mark("saved")
        do { try save() } catch { entries = previous; throw error }
        for id in replaced { CommandAlerts.shared.clear(id) }
        CommandAlerts.shared.begin(id, deadline: Date(timeIntervalSince1970: Double(issued) / 1000 + VehicleOperation.alertSeconds))
        try? upload(id, remote: false)
    }
    private func upload(_ id: String, remote: Bool, delay: TimeInterval = 0) throws {
        guard let entry = entries[id], !entry.accepted, Date().timeIntervalSince(entry.issued) < 180,
              let current = Vault.load(), current.watch_id == entry.connection.watch_id, current.token == entry.connection.token,
              let body = try JSONSerialization.jsonObject(with: entry.body) as? [String: Any] else { return }
        entries[id]?.mark(remote ? "remote_upload" : "local_upload")
        try? save()
        logger.info("operation=\(id, privacy: .public) upload=\(remote ? "remote" : "local", privacy: .public)")
        let packet = try CommandEnvelope.prepare(body, connection: entry.connection)
        let address = remote ? (entry.connection.remote_url ?? entry.connection.url) : entry.connection.url
        var request = URLRequest(url: try Connection.address(address).appendingPathComponent("api/fan_control/watch/request"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("command-" + UUID().uuidString)
        try JSONSerialization.data(withJSONObject: packet.packet).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let task = session.uploadTask(with: request, fromFile: file)
        task.taskDescription = [id, packet.aad, remote ? "remote" : "local", file.path].joined(separator: "|")
        if delay > 0 { task.earliestBeginDate = Date().addingTimeInterval(delay) }
        task.resume()
    }
    func clear() {
        for id in entries.keys { CommandAlerts.shared.clear(id) }
        UserDefaults.standard.removeObject(forKey: "commandTimingEvents")
        entries.removeAll(); SecureCommandStorage.clear()
        session.getAllTasks { tasks in for task in tasks { task.cancel() } }
    }
    func recover() {
        _ = session
        Task { await CommandAlerts.shared.recover() }
        session.getAllTasks { tasks in
            let active = Set(tasks.compactMap { $0.taskDescription?.components(separatedBy: "|").first })
            Task { @MainActor in
                for entry in self.entries.values where !entry.accepted && !active.contains(entry.id) {
                    try? self.upload(entry.id, remote: false)
                }
            }
        }
    }
    func outcome(_ id: String, state: [String: Any]) {
        guard var entry = entries[id], state["operation_id"] as? String == id else { return }
        guard CommandPolicy.accept(state, id: id, previous: entry.result) else { return }
        entry.accepted = true
        entry.mark("ack_received")
        entry.result = try? JSONSerialization.data(withJSONObject: state)
        entries[id] = entry
        try? save()
        CommandAlerts.shared.outcome(id, state: state)
        logger.info("operation=\(id, privacy: .public) status=\(state["operation_status"] as? String ?? "unknown", privacy: .public)")
        NotificationCenter.default.post(name: .commandOutcomeSaved, object: id)
    }
    func record(_ id: String) -> Entry? { entries[id] }
    func alertRecords() -> [Entry] { Array(entries.values) }
    func reconcile(_ id: String) async {
        guard let entry = entries[id], let current = Vault.load(), current.watch_id == entry.connection.watch_id,
              current.token == entry.connection.token else { return }
        if let state = try? await Integration(entry.connection).request(["action": "operation_status", "operation_id": id]) {
            outcome(id, state: state)
        }
    }
    func rejected(_ id: String) {
        guard entries[id]?.accepted == false else { return }
        outcome(id, state: ["operation_id": id, "operation_status": "failed", "reason": "Request rejected", "local_error": true])
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription?.components(separatedBy: "|").first == id { task.cancel() }
        }
    }
    func pending(connection: Connection, device: Device) -> Entry? {
        entries.values.filter { $0.connection.watch_id == connection.watch_id && $0.connection.token == connection.token && $0.entity == device.entity && Date().timeIntervalSince($0.issued) < 600 }.max { $0.issued < $1.issued }
    }
    func reconnect(_ task: WKURLSessionRefreshBackgroundTask) {
        backgroundTasks.append(task)
        _ = session
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated {
            if (self.buffers[dataTask.taskIdentifier]?.count ?? 0) + data.count <= 262144 { self.buffers[dataTask.taskIdentifier, default: Data()].append(data) }
        }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            let parts = (task.taskDescription ?? "").components(separatedBy: "|")
            guard parts.count == 4 else { return }
            let data = self.buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            try? FileManager.default.removeItem(atPath: parts[3])
            guard let entry = self.entries[parts[0]] else { return }
            let code = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            if error == nil, (200..<300).contains(code), let result = try? CommandEnvelope.response(data, connection: entry.connection, aad: parts[1]) {
                self.outcome(entry.id, state: result)
            } else if code >= 400 && code < 500 && code != 429 {
                self.rejected(entry.id)
            } else {
                let count = (self.entries[entry.id]?.retries ?? 0) + 1
                self.entries[entry.id]?.retries = count
                try? self.save()
                try? self.upload(entry.id, remote: true, delay: parts[2] == "local" ? 0 : min(15, Double(count * 2)))
            }
        }
    }
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            let tasks = self.backgroundTasks; self.backgroundTasks.removeAll()
            for task in tasks { task.setTaskCompletedWithSnapshot(false) }
        }
    }
}
