import XCTest
@testable import FanControlCore

final class ActionReceiptTests: XCTestCase {
    func testActionsExcludeFanSpeedAndToggles() {
        for command in ["leave", "honk", "start_exercise", "stop_exercise"] {
            XCTAssertTrue(ActionReceipts.applies(command))
        }
        for command in ["turn_on", "turn_off", "speed1", "speed6", "climate_on", "climate_off", "garage_open", "trunk_close", "activate"] {
            XCTAssertFalse(ActionReceipts.applies(command))
            XCTAssertFalse(ActionReceipts.acknowledges(command, response: [:]))
        }
        XCTAssertFalse(Evidence.matches("honk", ["accepted":true], panel:nil))
    }
    func testStopAcceptsPendingButRejectsTerminalRejections() {
        for status in ["pending", "complete"] {
            XCTAssertTrue(ActionReceipts.acknowledges("stop_exercise", response:["operation_status":status]))
        }
        for status in ["cancelled", "expired", "unsupported", "unknown", ""] {
            XCTAssertFalse(ActionReceipts.acknowledges("stop_exercise", response:["operation_status":status]))
        }
        XCTAssertFalse(ActionReceipts.acknowledges("stop_exercise", response:[:]))
    }
    func testReceiptsRemainIndependentUntilSessionEnds() {
        var receipts = ActionReceipts()
        let start = Feedback(target:"watch/panel", command:"start_exercise", label:"Activated")
        receipts.begin(start)
        XCTAssertEqual(receipts.feedback(target:start.target,command:start.command)?.phase,.pending)
        receipts.finish(start,accepted:true)
        let stop = Feedback(target:start.target, command:"stop_exercise",label:"Activated")
        receipts.begin(stop); receipts.finish(stop,accepted:false)
        XCTAssertEqual(receipts.feedback(target:start.target,command:start.command)?.phase,.accepted)
        XCTAssertEqual(receipts.feedback(target:stop.target,command:stop.command)?.phase,.unconfirmed)
        receipts.clear()
        XCTAssertNil(receipts.feedback(target:start.target,command:start.command))
    }
    func testStaleCallbacksAndOtherTargetsCannotRecolorNewRequest() {
        var receipts = ActionReceipts()
        let old = Feedback(target:"watchA/panelA", command:"honk", label:"Activated")
        let next = Feedback(target:old.target, command:old.command,label:"Activated")
        receipts.begin(old); receipts.begin(next); receipts.finish(old,accepted:true)
        XCTAssertEqual(receipts.feedback(target:next.target,command:next.command)?.phase,.pending)
        let other = Feedback(target:"watchB/panelB",command:"honk",label:"Activated")
        receipts.finish(other,accepted:true)
        XCTAssertNil(receipts.feedback(target:other.target,command:other.command))
        receipts.clear(); receipts.finish(next,accepted:true)
        XCTAssertNil(receipts.feedback(target:next.target,command:next.command))
    }
}
