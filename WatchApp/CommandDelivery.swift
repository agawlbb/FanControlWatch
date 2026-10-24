import Foundation
import WatchKit
import FanControlCore

// The keychain outbox owns intent until HA acknowledges durable acceptance.
// A background upload hands delivery to watchOS immediately, before screen exit.
@MainActor final class CommandDelivery: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = CommandDelivery()
    static let sessionID = "dev.fancontrol.watch.command-delivery"
    typealias Entry = CommandRecord
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
    private func save() throws { try SecureCommandStorage.save(JSONEncoder().encode(entries)) }
    func enqueue(_ body: [String: Any], connection: Connection, device: Device) throws {
        guard let id = body["operation_id"] as? String, let issued = body["issued_at_ms"] as? Int else { throw ControlError.invalidConfiguration }
        entries = entries.filter { Date().timeIntervalSince($0.value.issued) < 600 }
        for old in entries.keys where entries[old]?.entity == device.entity && entries[old]?.connection.watch_id == connection.watch_id {
            entries[old]?.accepted = true  // Superseded locally; never recover the old intent.
        }
        entries[id] = Entry(id: id, connection: connection, entity: device.entity, body: try JSONSerialization.data(withJSONObject: body), issued: Date(timeIntervalSince1970: Double(issued) / 1000))
        try save()
        try? upload(id, remote: false)
    }
    private func upload(_ id: String, remote: Bool, delay: TimeInterval = 0) throws {
        guard let entry = entries[id], !entry.accepted, Date().timeIntervalSince(entry.issued) < 180,
              let current = Vault.load(), current.watch_id == entry.connection.watch_id, current.token == entry.connection.token,
              let body = try JSONSerialization.jsonObject(with: entry.body) as? [String: Any] else { return }
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
    func recover() {
        _ = session
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
        if let data = entry.result, let previous = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           ["complete", "accepted", "failed", "cancelled", "unconfirmed"].contains(previous["operation_status"] as? String ?? "") { return }
        let status = state["operation_status"] as? String ?? "unknown"
        guard status != "unknown" else { return }
        entry.accepted = true
        entry.result = try? JSONSerialization.data(withJSONObject: state)
        entries[id] = entry
        try? save()
    }
    func rejected(_ id: String) {
        outcome(id, state: ["operation_id": id, "operation_status": "failed", "reason": "Request rejected"])
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
        Task { @MainActor in
            if (self.buffers[dataTask.taskIdentifier]?.count ?? 0) + data.count <= 262144 { self.buffers[dataTask.taskIdentifier, default: Data()].append(data) }
        }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            let parts = (task.taskDescription ?? "").components(separatedBy: "|")
            guard parts.count == 4, let entry = self.entries[parts[0]] else { return }
            let data = self.buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            try? FileManager.default.removeItem(atPath: parts[3])
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
        Task { @MainActor in
            let tasks = self.backgroundTasks; self.backgroundTasks.removeAll()
            for task in tasks { task.setTaskCompletedWithSnapshot(false) }
        }
    }
}
