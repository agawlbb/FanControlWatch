import Foundation

// Persist the original absolute intent; retries must never recompute a toggle.
public struct CommandRecord: Codable {
    public let id: String
    public let connection: Connection
    public let entity: String
    public let body: Data
    public let issued: Date
    public var accepted = false
    public var retries: Int?
    public var result: Data?
    public var timings: [String: Double]?
    public var events: [String]?
    public func awaitingHandoff(now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(issued)
        return !accepted && result == nil && age >= 0 && age < Connection.handoffSeconds
    }
    public mutating func mark(_ phase: String) {
        var times = timings ?? [:]
        if times[phase] == nil { times[phase] = Date().timeIntervalSince1970 * 1000 }
        timings = times
        var list = events ?? []
        if list.last != phase { list.append(phase) }
        events = Array(list.suffix(40))
    }
    public init(id: String, connection: Connection, entity: String, body: Data, issued: Date) {
        self.id = id; self.connection = connection; self.entity = entity; self.body = body; self.issued = issued
    }
}
