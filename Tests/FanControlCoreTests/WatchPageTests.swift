import XCTest
@testable import FanControlCore

final class WatchPageTests: XCTestCase {
    func testSettingsIsReachableWithOnlyOnePanelAndWrapsBothWays() {
        let entities = ["panel.exercise"]
        for direction in [-1, 1] {
            XCTAssertEqual(WatchPage.next(.device(entities[0]), entities: entities, direction: direction), .settings)
            XCTAssertEqual(WatchPage.next(.settings, entities: entities, direction: direction), .device(entities[0]))
        }
    }
    func testSettingsFollowsAllControlsWithoutChangingTheirOrder() {
        let entities = ["panel.fan", "panel.exercise", "panel.driving"]
        XCTAssertEqual(WatchPage.next(.device(entities[0]), entities: entities, direction: 1), .device(entities[1]))
        XCTAssertEqual(WatchPage.next(.device(entities[2]), entities: entities, direction: 1), .settings)
        XCTAssertEqual(WatchPage.next(.settings, entities: entities, direction: 1), .device(entities[0]))
        XCTAssertEqual(WatchPage.next(.device(entities[0]), entities: entities, direction: -1), .settings)
        XCTAssertEqual(WatchPage.next(.settings, entities: entities, direction: -1), .device(entities[2]))
    }
    func testUnconfiguredWatchStillHasLocalSettings() {
        XCTAssertEqual(WatchPage.next(.settings, entities: [], direction: 1), .settings)
    }
}
