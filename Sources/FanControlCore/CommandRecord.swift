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
    public init(id: String, connection: Connection, entity: String, body: Data, issued: Date) {
        self.id = id; self.connection = connection; self.entity = entity; self.body = body; self.issued = issued
    }
}
