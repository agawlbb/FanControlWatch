import Foundation
import CryptoKit
import Security

public final class HTTP: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6; c.timeoutIntervalForResource = 6
        c.urlCache = nil; c.httpCookieStorage = nil
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    public func post(_ base: String, path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        let url = try Connection.address(base).appendingPathComponent(path)
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { r.setValue(token, forHTTPHeaderField: "X-Fan-Control-Pairing") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: r)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ControlError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw ControlError.rejected(response.statusCode) }
        guard data.count <= 24576, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ControlError.invalidResponse }
        return json
    }
}
public actor Integration {
    private let http = HTTP()
    public let connection: Connection
    private var endpoint: String
    public init(_ connection: Connection) { self.connection = connection; endpoint = connection.url }
    public func request(_ body: [String: Any]) async throws -> [String: Any] {
        do { return try await exchange(body, endpoint) }
        catch {
            try Task.checkCancellation()
            if case ControlError.rejected = error { throw error }
            guard !["command", "panel_command"].contains(body["action"] as? String ?? ""), let remote = connection.remote_url, !remote.isEmpty, remote != connection.url else { throw error }
            let fallback = endpoint == remote ? connection.url : remote
            let result = try await exchange(body, fallback); endpoint = fallback; return result
        }
    }
    private func exchange(_ body: [String: Any], _ address: String) async throws -> [String: Any] {
        let nonce = try random(16).hex
        let timestamp = Int(Date().timeIntervalSince1970)
        let aad = "fan-control-v1:\(connection.watch_id):\(timestamp):\(nonce)"
        let key = SymmetricKey(data: try Data(hex: connection.token))
        let box = try AES.GCM.seal(JSONSerialization.data(withJSONObject: body), using: key, authenticating: Data(aad.utf8))
        let result = try await http.post(address, path: "api/fan_control/watch/request", body: ["watch_id": connection.watch_id, "timestamp": timestamp, "nonce": nonce, "iv": Data(box.nonce).base64EncodedString(), "ciphertext": (box.ciphertext + box.tag).base64EncodedString()])
        let plain = try open(result, key: key, aad: aad + ":response")
        guard let json = try JSONSerialization.jsonObject(with: plain) as? [String: Any] else { throw ControlError.invalidResponse }
        return json
    }
}
public enum Vault {
    private static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "dev.fancontrol.watch", kSecAttrAccount as String: "connection"] }
    public static func save(_ connection: Connection) throws {
        let data = try JSONEncoder().encode(connection.validated())
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw ControlError.invalidConfiguration }
        } else if status != errSecSuccess { throw ControlError.invalidConfiguration }
    }
    public static func load() -> Connection? {
        var result: CFTypeRef?
        let q = query.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Connection.self, from: data).validated()
    }
    public static func clear() { SecItemDelete(query as CFDictionary) }
}
public func random(_ count: Int) throws -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw ControlError.invalidResponse }
    return Data(bytes)
}
public func open(_ envelope: [String: Any], key: SymmetricKey, aad: String) throws -> Data {
    guard let ivText = envelope["iv"] as? String, let iv = Data(base64Encoded: ivText), iv.count == 12,
          let text = envelope["ciphertext"] as? String, let data = Data(base64Encoded: text), data.count >= 16 else { throw ControlError.invalidResponse }
    let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: data.dropLast(16), tag: data.suffix(16))
    return try AES.GCM.open(box, using: key, authenticating: Data(aad.utf8))
}
extension Data {
    public var hex: String { map { String(format: "%02x", $0) }.joined() }
    public init(hex: String) throws {
        guard hex.count % 2 == 0 else { throw ControlError.invalidConfiguration }
        var bytes = [UInt8](); var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            guard let b = UInt8(hex[i..<j], radix: 16) else { throw ControlError.invalidConfiguration }
            bytes.append(b); i = j
        }
        self.init(bytes)
    }
}
