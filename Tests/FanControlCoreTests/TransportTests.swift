import XCTest
import CryptoKit
@testable import FanControlCore

final class MockProtocol: URLProtocol {
    static var handle: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handle!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class TransportTests: XCTestCase {
    private func client() throws -> Integration {
        let raw = """
        {"url":"https://local.example","remote_url":"https://remote.example","token":"\(String(repeating:"a",count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"fan.test","devices":[{"entity":"fan.test","title":"Test"}]}
        """
        let c = try JSONDecoder().decode(Connection.self, from:Data(raw.utf8)).validated()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockProtocol.self]
        return Integration(c,http:HTTP(configuration:config))
    }
    override func tearDown() { MockProtocol.handle = nil; super.tearDown() }
    func testPrivateMusicChunkUsesLargerBudgetWithoutRelaxingOrdinaryReads() async throws {
        let c = try client()
        MockProtocol.handle = { request in
            let packet = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let aad = "fan-control-v1:\(packet["watch_id"]!):\(packet["timestamp"]!):\(packet["nonce"]!):response"
            let plain = try JSONSerialization.data(withJSONObject: ["data":Data(repeating:42,count:196608).base64EncodedString(), "offset":0])
            let key = SymmetricKey(data:try Data(hex:String(repeating:"a",count:64)))
            let box = try AES.GCM.seal(plain,using:key,authenticating:Data(aad.utf8))
            let envelope = ["iv":Data(box.nonce).base64EncodedString(),"ciphertext":(box.ciphertext + box.tag).base64EncodedString()]
            return (200,try JSONSerialization.data(withJSONObject:envelope))
        }
        let chunk = try await c.request(["action":"exercise_music_chunk","name":"01 song.mp3","offset":0])
        XCTAssertEqual(Data(base64Encoded:chunk["data"] as! String)?.count,196608)
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Ordinary reads must retain the small limit") } catch {}
    }
    func testAmbiguousCommandNeverFallsBackToAnotherEndpoint() async throws {
        let c = try client(); var hosts = [String]()
        MockProtocol.handle = { request in hosts.append(request.url!.host!); throw URLError(.timedOut) }
        do { _ = try await c.request(["action":"command","entity":"fan.test","command":"turn_on"]); XCTFail("Expected timeout") } catch {}
        XCTAssertEqual(hosts,["local.example"])
    }
    func testSafeReadFallsBackButRejectionDoesNot() async throws {
        let c = try client(); var hosts = [String]()
        MockProtocol.handle = { request in hosts.append(request.url!.host!); throw URLError(.notConnectedToInternet) }
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(hosts,["local.example","remote.example"])
        hosts = []
        MockProtocol.handle = { request in hosts.append(request.url!.host!); return (403,Data()) }
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Expected rejection") } catch {}
        XCTAssertEqual(hosts,["local.example"])
    }
    func testPanelCommandAlsoNeverReplaysOnRemote() async throws {
        let c = try client(); var count = 0
        MockProtocol.handle = { _ in count += 1; throw URLError(.networkConnectionLost) }
        do { _ = try await c.request(["action":"panel_command","panel_id":"driving","command":"trunk_open"]); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(count,1)
    }
}
