import CryptoKit
import XCTest
@testable import PlataCore

final class CloudLinkTests: XCTestCase {
    private func vectors() throws -> JSONValue { try fixture("cloud")["link"]! }

    /// Compromiso, verificación y código de 6 dígitos: iguales a los de la web.
    func testCommitAndCodeMatchWeb() throws {
        let l = try vectors()
        let s = { (k: String) in l[k]!.stringValue! }
        XCTAssertEqual(CloudLink.commitHash(apub: s("apub"), na: s("na")), s("commit"))
        XCTAssertTrue(CloudLink.verify(commit: s("commit"), apub: s("apub"), na: s("na")))
        XCTAssertFalse(CloudLink.verify(commit: s("commit"), apub: s("apub"), na: s("nn")))
        XCTAssertFalse(CloudLink.verify(commit: nil, apub: s("apub"), na: s("na")))
        XCTAssertEqual(CloudLink.code(pub: s("npub"), apub: s("apub"), na: s("na"), nn: s("nn")), s("code"))
    }

    /// Las claves públicas salen en el mismo formato que la web (65 bytes sin comprimir, base64url).
    func testPublicKeyFormat() throws {
        let l = try vectors()
        let a = try CloudLink.Pair(priv: P256.KeyAgreement.PrivateKey(derRepresentation: Base64URL.decode(l["aPriv"]!.stringValue!)!))
        XCTAssertEqual(a.pub, l["apub"]!.stringValue!)
        XCTAssertEqual(Base64URL.decode(CloudLink.Pair().pub)?.count, 65)
    }

    /// El dispositivo nuevo abre la semilla que cifró la web, y Swift↔Swift también funciona.
    func testOpensSeedSealedByWeb() throws {
        let l = try vectors()
        let nPriv = try P256.KeyAgreement.PrivateKey(derRepresentation: Base64URL.decode(l["nPriv"]!.stringValue!)!)
        let seed = try CloudLink.open(priv: nPriv, apub: l["apub"]!.stringValue!, iv: l["iv"]!.stringValue!, ct: l["ct"]!.stringValue!)
        XCTAssertEqual(seed.map { String(format: "%02x", $0) }.joined(), l["seed"]!.stringValue!)
    }

    func testRoundTripAndTamper() throws {
        let active = CloudLink.Commit(), fresh = CloudLink.Pair()
        let seed = CloudCrypto.newSeed()
        let x = try CloudLink.seal(priv: active.pair.priv, reqPub: fresh.pub, seed: seed)
        XCTAssertEqual(try CloudLink.open(priv: fresh.priv, apub: active.apub, iv: x.iv, ct: x.ct), seed)
        let other = CloudLink.Pair()
        XCTAssertThrowsError(try CloudLink.open(priv: other.priv, apub: active.apub, iv: x.iv, ct: x.ct))
        XCTAssertTrue(CloudLink.verify(commit: active.c, apub: active.apub, na: active.na))
    }
}

/// Forma de las peticiones nuevas del cliente (ruta, método, cuerpo y encabezados).
final class CloudAPIShapeTests: XCTestCase {
    final class Rec: HTTPTransport, @unchecked Sendable {
        var last: URLRequest?
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            last = request
            return (Data("{\"ok\":true}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    private func body(_ r: Rec) -> JSONValue { try! JSONValue(jsonData: r.last!.httpBody!) }

    func testRequests() async throws {
        let r = Rec(), api = CloudAPI(transport: r)
        _ = try await api.waitlist(email: "a@b.co", lang: "es", platform: "ios")
        XCTAssertEqual(r.last?.url?.path, "/waitlist"); XCTAssertEqual(body(r)["website"], .string("")); XCTAssertEqual(body(r)["src"], .string("app"))
        _ = try await api.syncConfirm(kind: "delete", lang: "en", token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.url?.path, "/sync/confirm"); XCTAssertEqual(body(r)["kind"], .string("delete"))
        XCTAssertEqual(r.last?.value(forHTTPHeaderField: "Authorization"), "Bearer T"); XCTAssertEqual(r.last?.value(forHTTPHeaderField: "X-Plata-Write"), "W")
        _ = try await api.syncConfirm(lang: "es", token: "T", writeKey: nil)
        XCTAssertNil(body(r)["kind"])
        _ = try await api.syncCheck(code: "123456", token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.url?.path, "/sync/check"); XCTAssertEqual(body(r)["code"], .string("123456"))
        _ = try await api.replaceSync(base: 3, next: 4, blob: "B", device: "ios", code: "123456", token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.httpMethod, "PUT"); XCTAssertEqual(body(r)["replace"], .bool(true)); XCTAssertEqual(body(r)["code"], .string("123456")); XCTAssertEqual(body(r)["next"], .number(4))
        _ = try await api.logoutAll(device: "ios", token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.url?.path, "/auth/logout-all")
        _ = try await api.deleteAccount(code: "123456", token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.httpMethod, "DELETE"); XCTAssertEqual(r.last?.url?.path, "/account")
        _ = try await api.linkStart(email: "a@b.co", pub: "P", rid: "R", platform: "ios", tz: "America/Lima", lang: "es")
        XCTAssertEqual(r.last?.url?.path, "/link/start"); XCTAssertEqual(body(r)["tz"], .string("America/Lima"))
        _ = try await api.linkPoll(email: "a@b.co", rid: "R", nonce: "N")
        XCTAssertEqual(body(r)["step"], .string("nonce")); XCTAssertEqual(body(r)["nn"], .string("N"))
        _ = try await api.linkPoll(email: "a@b.co", rid: "R")
        XCTAssertNil(body(r)["step"])
        _ = try await api.linkPending(token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.url?.path, "/link/pending"); XCTAssertEqual(r.last?.httpMethod, "GET")
        _ = try await api.linkStep(["step": .string("commit")], token: "T", writeKey: "W")
        XCTAssertEqual(r.last?.url?.path, "/link/step")
    }
}
