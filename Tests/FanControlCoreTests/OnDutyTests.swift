import XCTest
@testable import FanControlCore

final class OnDutyTests: XCTestCase {
    @MainActor func testFlightSelectionComesFromConfiguredSensors() async throws {
        let raw = Data(#"{"entity":"panel.on_duty","title":"On Duty","panel":{"id":"on_duty","name":"On Duty","type":"on_duty","city_pair_entity":"sensor.airports","departure_entity":"sensor.departure"}}"#.utf8)
        let device = try JSONDecoder().decode(Device.self, from: raw)
        try device.panel!.validateRoles()
        XCTAssertFalse(device.panel!.vehicle)
        XCTAssertEqual(VisibleStateRefresh.available(["available": true], for: device), true)
        XCTAssertFalse(VisibleStateRefresh.available(["available": false], for: device))
    }
    func testDepartureAndCountdown() throws {
        let departure = try XCTUnwrap(FlightPresentation.departure("2026-11-05T18:52:00+00:00"))
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(-3661)), "1h 2m")
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(-1)), "1m")
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(100)), "0m")
        XCTAssertNotNil(FlightPresentation.departure("2026-11-05T18:52:00.123+00:00"))
        XCTAssertNil(FlightPresentation.departure("unknown"))
    }
    func testFullMessageRoundTrip() throws {
        let message = AppMessage(id: "alert", title: "Route changed", message: "Full route\nSecond line", atMS: 123)
        XCTAssertEqual(try JSONDecoder().decode(AppMessage.self, from: JSONEncoder().encode(message)), message)
    }
}
