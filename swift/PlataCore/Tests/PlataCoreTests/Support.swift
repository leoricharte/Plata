import Foundation
import XCTest
@testable import PlataCore

/// Lee un vector de prueba generado por swift/tools/gen-vectors.mjs (ejecutando el código real de la web).
func fixture(_ name: String) throws -> JSONValue {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw XCTSkip("falta Fixtures/\(name).json: corre `node swift/tools/gen-vectors.mjs`")
    }
    return try JSONValue(jsonData: Data(contentsOf: url))
}

func hexData(_ s: String) -> Data {
    var d = Data(), i = s.startIndex
    while i < s.endIndex { let j = s.index(i, offsetBy: 2); d.append(UInt8(s[i..<j], radix: 16)!); i = j }
    return d
}

/// Un servidor de Plata Cloud falso con las mismas reglas que dev/worker/worker.js para /sync:
/// revisión que solo sube, `next` verificado, 409 en conflicto, 401 sin sesión, 403 si la llave de escritura no es la de la cuenta.
/// Nunca descifra: guarda el texto cifrado tal cual, como el servidor real.
final class FakeCloud: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var rev = 0
    private(set) var blob: String?
    private var writeKey: String?
    var tokenValid = true
    private(set) var puts = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock(); defer { lock.unlock() }
        let path = request.url!.path, method = request.httpMethod ?? "GET"
        let body = request.httpBody.flatMap { try? JSONValue(jsonData: $0) } ?? .null
        func reply(_ status: Int, _ json: JSONValue) -> (Data, HTTPURLResponse) {
            (try! json.jsonData(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        guard tokenValid, request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true else { return reply(401, .object(["ok": .bool(false), "error": .string("auth")])) }
        let wk = request.value(forHTTPHeaderField: "X-Plata-Write")
        guard path == "/sync" else { return reply(404, .object([:])) }
        switch method {
        case "GET":
            var o: [String: JSONValue] = ["ok": .bool(true), "rev": .number(Double(rev)), "next": .number(Double(rev + 1))]
            if let blob { o["blob"] = .string(blob) }
            return reply(200, .object(o))
        case "PUT":
            if let writeKey, wk != writeKey { return reply(403, .object(["ok": .bool(false), "error": .string("wk")])) }
            if writeKey == nil { writeKey = wk }
            let base = body["base"]?.intValue ?? -1, next = body["next"]?.intValue
            if base != rev { return reply(409, .object(["ok": .bool(false), "error": .string("conflict"), "rev": .number(Double(rev))])) }
            if let next, next != rev + 1 { return reply(409, .object(["ok": .bool(false), "error": .string("conflict")])) }
            rev += 1; blob = body["blob"]?.stringValue; puts += 1
            return reply(200, .object(["ok": .bool(true), "rev": .number(Double(rev))]))
        default:
            return reply(405, .object([:]))
        }
    }
}

func makeEngine(cloud: FakeCloud, seed: Data, device: String, clock: @escaping @Sendable () -> Double = { 1_790_000_000_000 }) -> (SyncEngine, MemoryCloudStore) {
    let store = MemoryCloudStore()
    var st = CloudState()
    st.token = "tok" + String(repeating: "x", count: 30); st.email = "a@b.co"; st.seed = Base64URL.encode(seed); st.mode = .cloud
    store.saveState(st)
    let api = CloudAPI(baseURL: URL(string: "https://example.test")!, transport: cloud)
    return (SyncEngine(api: api, store: store, device: device, now: clock), store)
}

func profile(_ txs: [(Int, Double)] = [], mod: Double = 1_789_000_000_000) -> Profile {
    var p = Profile.empty.raw
    p["transactions"] = .array(txs.map { .object(["id": .number(Double($0.0)), "date": .string("2026-10-01"), "amount": .number($0.1), "category": .string("Comida"), "note": .string(""), "acc": .string("bank"), "mod": .number(mod)]) })
    return Profile(raw: p)
}
