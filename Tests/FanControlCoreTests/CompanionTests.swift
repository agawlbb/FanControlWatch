import XCTest
@testable import FanControlCore
final class CompanionTests: XCTestCase {
    func testPlaylistValidationAndOrderRoundTrip() throws {
        let a = ExerciseTrack(name: "a.mp3", sha256: String(repeating: "a", count: 64), size: 20)
        let b = ExerciseTrack(name: "b.m4a", sha256: String(repeating: "b", count: 64), size: 30)
        let list = try OfflinePlaylist(watchID: "watch", tracks: [b, a])
        XCTAssertEqual(try JSONDecoder().decode(OfflinePlaylist.self, from: JSONEncoder().encode(list)), list)
        XCTAssertThrowsError(try OfflinePlaylist(watchID: "watch", tracks: [a, a]))
        XCTAssertThrowsError(try OfflinePlaylist(watchID: "watch", tracks: Array(repeating: a, count: 26)))
        XCTAssertNoThrow(try OfflinePlaylist(watchID: "watch", tracks: []))
    }
}
