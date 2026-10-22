import Foundation

// Receipt evidence is separate from observed device state and physical completion.
public struct ActionReceipts {
    private var entries: [String: Feedback] = [:]
    public init() {}
    // An untouched action is ready to request, independent of observed state.
    public static func isGray(_ feedback: Feedback?) -> Bool {
        feedback.map { $0.phase != .accepted } ?? false
    }
    public static func applies(_ command: String) -> Bool {
        ["leave", "honk", "podcast", "start_exercise", "stop_exercise"].contains(command)
    }
    private func key(_ target: String, _ command: String) -> String { target + "|" + command }
    public func feedback(target: String, command: String) -> Feedback? { entries[key(target, command)] }
    public mutating func begin(_ feedback: Feedback) {
        guard Self.applies(feedback.command) else { return }
        entries[key(feedback.target, feedback.command)] = feedback
    }
    public mutating func finish(_ feedback: Feedback, accepted: Bool) {
        let k = key(feedback.target, feedback.command)
        guard entries[k]?.id == feedback.id else { return }
        entries[k]?.phase = accepted ? .accepted : .unconfirmed
    }
    public mutating func clear() { entries.removeAll() }
    public static func acknowledges(_ command: String, response: [String: Any]) -> Bool {
        guard applies(command) else { return false }
        if command == "stop_exercise" {
            return ["pending", "complete"].contains(response["operation_status"] as? String ?? "")
        }
        // Only call with the authenticated response to this command's POST,
        // never with a state/config read, network completion or caught error.
        return true
    }
}
