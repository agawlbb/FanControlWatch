import XCTest
@testable import FanControlCore

final class RemoteHandoffTests: XCTestCase {
    private func connection(remote: String? = "https://remote.example") throws -> Connection {
        var json: [String: Any] = ["url": "http://localhost:8123", "token": String(repeating: "a", count: 64),
                                 "watch_id": String(repeating: "b", count: 32), "entity": "fan.test",
                                 "devices": [["entity": "fan.test", "title": "Test"]]]
        if let remote { json["remote_url"] = remote }
        return try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: json)).validated()
    }
    func testRemoteAddressDoesNotUseLocalhostEvenWhenLocalIsConfigured() throws {
        XCTAssertEqual(try connection().remoteAddress().absoluteString, "https://remote.example")
        for remote in [nil, "", "https://localhost", "https://127.0.0.1:8123", "https://[::1]"] as [String?] {
            XCTAssertThrowsError(try connection(remote: remote).remoteAddress())
        }
        XCTAssertThrowsError(try connection(remote: "http://remote.example"))
    }
    func testMissingRemoteFailsBeforeAnyNetworkRequest() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        var requests = 0
        MockProtocol.handle = { _ in requests += 1; throw URLError(.cannotConnectToHost) }
        defer { MockProtocol.handle = nil }
        let client = try Integration(connection(remote: nil), http: HTTP(configuration: config))
        do { _ = try await client.request(["action": "config"]); XCTFail("Missing remote must fail") }
        catch { XCTAssertEqual(requests, 0) }
    }
    func testHandoffEndsAtTenSecondsAndNeverResumesAcceptedOrFailedWork() throws {
        let issued = Date(timeIntervalSince1970: 1000)
        var record = CommandRecord(id: "one", connection: try connection(), entity: "fan.test", body: Data(), issued: issued)
        XCTAssertTrue(record.awaitingHandoff(now: issued.addingTimeInterval(9.99)))
        XCTAssertFalse(record.awaitingHandoff(now: issued.addingTimeInterval(10)))
        XCTAssertFalse(record.awaitingHandoff(now: issued.addingTimeInterval(180)))
        record.accepted = true
        XCTAssertFalse(record.awaitingHandoff(now: issued.addingTimeInterval(1)))
        record.accepted = false; record.result = Data("failed".utf8)
        XCTAssertFalse(record.awaitingHandoff(now: issued.addingTimeInterval(1)))
    }
    func testActionResetsFiveSecondsAfterFirstAcknowledgment() {
        var receipts = ActionReceipts()
        let start = Date(timeIntervalSince1970: 1000)
        let f = Feedback(target: "watch/panel", command: "honk", label: "Activated")
        receipts.begin(f)
        XCTAssertEqual(receipts.feedback(target: f.target, command: f.command, now: start)?.phase, .pending)
        receipts.finish(f, accepted: true, now: start)
        XCTAssertEqual(receipts.feedback(target: f.target, command: f.command, now: start.addingTimeInterval(4.99))?.phase, .accepted)
        // Duplicate receipts cannot extend the original five-second display.
        receipts.finish(f, accepted: true, now: start.addingTimeInterval(4))
        XCTAssertNil(receipts.feedback(target: f.target, command: f.command, now: start.addingTimeInterval(5)))
    }
    func testFailureRestoresNameAndStaleTimerCannotClearNewTap() {
        var receipts = ActionReceipts()
        let old = Feedback(target: "watch/panel", command: "honk", label: "Activated")
        receipts.begin(old); receipts.finish(old, accepted: false)
        XCTAssertNil(receipts.feedback(target: old.target, command: old.command))
        receipts.finish(old, accepted: true)
        XCTAssertNil(receipts.feedback(target: old.target, command: old.command))
        let next = Feedback(target: old.target, command: old.command, label: "Activated")
        receipts.begin(next); receipts.remove(old); receipts.finish(old, accepted: false)
        XCTAssertEqual(receipts.feedback(target: next.target, command: next.command)?.id, next.id)
        let other = Feedback(target: "other/panel", command: old.command, label: "Activated")
        receipts.remove(other)
        XCTAssertEqual(receipts.feedback(target: next.target, command: next.command)?.phase, .pending)
    }
    func testConnectionErrorsAreUsefulAndContainNoCredentials() {
        XCTAssertEqual(ConnectionCheck.failureMessage(URLError(.timedOut)), "Connection timed out.")
        XCTAssertEqual(ConnectionCheck.failureMessage(URLError(.cannotFindHost)), "DNS lookup failed.")
        XCTAssertEqual(ConnectionCheck.failureMessage(ControlError.rejected(403)), "Pairing rejected by Home Assistant.")
        XCTAssertTrue(ConnectionCheck.failureMessage(URLError(.serverCertificateUntrusted)).contains("certificate"))
        XCTAssertTrue(ConnectionCheck.failureMessage(ControlError.invalidConfiguration).contains("remote HTTPS"))
    }
}
