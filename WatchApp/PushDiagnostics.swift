import SwiftUI
import FanControlCore

@MainActor enum PushDiagnostics {
    static let shared = PushTrace()
    private static var sending = false
    static func flush(_ connection: Connection, client supplied: Integration? = nil) async {
        guard !sending, Vault.load() == connection else { return }
        sending = true; defer { sending = false }
        let client = supplied ?? Integration(connection)
        // Bounded; a later opening/refresh resumes remaining receipts.
        for _ in 0..<10 {
            let events = shared.pending(connection)
            guard !events.isEmpty, Vault.load() == connection, !Task.isCancelled,
                  let data = try? JSONEncoder().encode(events),
                  let body = try? JSONSerialization.jsonObject(with: data) else { return }
            do {
                let response = try await client.request(["action": "push_receipts", "events": body])
                guard Vault.load() == connection, let ids = response["recorded"] as? [String] else { return }
                let discarded = response["discarded"] as? [String] ?? []
                shared.acknowledge(Set(ids + discarded), connection: connection)
                if ids.isEmpty && discarded.isEmpty { return }
            } catch { return } // Keep the original event IDs/times for the next attempt.
        }
    }
}

struct PushDiagnosticsView: View {
    let connection: Connection?
    @State private var events: [PushTraceEvent] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Push diagnostics").font(.headline)
                Text("Receipt is separate from selection saved. HA diagnostics reconcile matching update IDs.").font(.caption)
                Button("Report pending receipts") {
                    Task {
                        if let connection { await PushDiagnostics.flush(connection) }
                        events = PushDiagnostics.shared.history(connection)
                    }
                }
                ForEach(events.reversed()) { event in
                    VStack(alignment: .leading) {
                        Text(event.phase.replacingOccurrences(of: "_", with: " "))
                        Text(Date(timeIntervalSince1970: Double(event.at_ms) / 1000), style: .time)
                        Text(event.update_id ?? "No correlated push")
                        if !event.panel.isEmpty { Text(event.panel) }
                        if let revision = event.revision { Text("Revision \(revision)") }
                        Text(event.reported ? "Reported to HA" : "Stored on watch")
                    }.font(.caption2)
                    Divider()
                }
            }
        }.onAppear { events = PushDiagnostics.shared.history(connection) }
    }
}
