import XCTest
@testable import FanControlCore

final class WatchPageTests: XCTestCase {
    func testSettingsIsTerminalAndNeverWrapsAcrossControls() {
        let entities = ["panel.fan", "panel.exercise", "panel.driving"]
        XCTAssertEqual(WatchPage.next(.settings, entities: entities, direction: 1), .settings)
        XCTAssertEqual(WatchPage.next(.settings, entities: entities, direction: -1), .device(entities[2]))
        XCTAssertEqual(WatchPage.next(.device(entities[0]), entities: entities, direction: -1), .device(entities[0]))
    }
    func testActivePanelIsAlwaysFirstAndSettingsIsFarthest() {
        let entities = ["panel.fan", "panel.exercise", "panel.driving"]
        let pages: [WatchPage] = [.device(entities[1]), .device(entities[0]), .device(entities[2]), .settings]
        for index in pages.indices {
            XCTAssertEqual(WatchPage.next(pages[index], entities: entities, active: entities[1], direction: 1), pages[min(index + 1, pages.count - 1)])
            XCTAssertEqual(WatchPage.next(pages[index], entities: entities, active: entities[1], direction: -1), pages[max(0, index - 1)])
        }
    }
    func testUnconfiguredWatchStillHasLocalSettings() {
        XCTAssertEqual(WatchPage.next(.settings, entities: [], direction: 1), .settings)
        XCTAssertEqual(WatchPage.next(.device("exercise"), entities: ["exercise"], direction: 1), .settings)
        XCTAssertEqual(WatchPage.next(.device("exercise"), entities: ["exercise"], direction: -1), .device("exercise"))
    }
}
