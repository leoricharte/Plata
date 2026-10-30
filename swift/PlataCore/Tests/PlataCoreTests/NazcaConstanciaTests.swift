import XCTest
@testable import PlataCore

/// Constancias de Yape y Plin: los resultados esperados salen de ejecutar `core/nazca/constancia.js` de la web (`swift/tools/gen-nazca-constancia.mjs`).
final class NazcaConstanciaTests: XCTestCase {
    private func golden() throws -> JSONValue { try fixture("nazca_constancia") }

    func testReadsLikeTheWeb() throws {
        let g = try golden()
        let today = g["today"]!.stringValue!
        let cases = g["cases"]!.arrayValue!
        XCTAssertGreaterThan(cases.count, 200)
        for (n, c) in cases.enumerated() {
            let text = c["text"]!.stringValue!
            let tag = "caso \(n): \(text.prefix(60).replacingOccurrences(of: "\n", with: " ⏎ "))"
            XCTAssertEqual(NazcaConstancia.detect(text), c["detect"]!.intValue, tag + " · detect")
            let want = c["read"]!
            let got = NazcaConstancia.read(text, today: today)
            if let e = want["error"], !e.isNull { XCTAssertNil(got, tag + " · debía ser nil"); continue }
            guard let r = got else { XCTFail(tag + " · devolvió nil"); continue }
            let st = r.statement
            XCTAssertEqual(st.bank ?? "", want["bank"]!.stringValue!, tag + " · bank")
            XCTAssertEqual(st.kind, want["kind"]!.stringValue, tag + " · kind")
            XCTAssertEqual(st.label, want["label"]!.stringValue, tag + " · label")
            XCTAssertEqual(st.name, want["name"]!.stringValue, tag + " · name")
            XCTAssertEqual(st.cur, want["cur"]!.stringValue, tag + " · cur")
            if let p = want["period"], !p.isNull { XCTAssertEqual(st.period, .init(from: p["from"]!.stringValue!, to: p["to"]!.stringValue!), tag + " · period") } else { XCTAssertNil(st.period, tag + " · period") }
            let items = want["items"]!.arrayValue!
            XCTAssertEqual(st.items.count, items.count, tag + " · items")
            for (i, w) in items.enumerated() where i < st.items.count {
                XCTAssertEqual(st.items[i].line, w["line"]!.intValue, tag + " · line")
                XCTAssertEqual(st.items[i].date, w["date"]!.stringValue, tag + " · date")
                XCTAssertEqual(st.items[i].desc, w["desc"]!.stringValue, tag + " · desc")
                XCTAssertEqual(st.items[i].amount, w["amount"]!.doubleValue!, tag + " · amount")
                XCTAssertEqual(st.items[i].cur, w["cur"]!.stringValue, tag + " · item cur")
                XCTAssertEqual(st.items[i].ref ?? "", w["ref"]!.stringValue!, tag + " · ref")
            }
            XCTAssertEqual(r.brand, want["brand"]!.stringValue, tag + " · brand")
            XCTAssertEqual(r.op, want["op"]!.stringValue, tag + " · op")
            XCTAssertEqual(r.time, want["time"]!.stringValue, tag + " · time")
            XCTAssertEqual(r.flags, want["flags"]!.arrayValue!.map { $0.stringValue! }, tag + " · flags")
            XCTAssertEqual(r.auto, want["auto"]!.boolValue, tag + " · auto")
        }
    }

    func testNilAndEmpty() {
        XCTAssertEqual(NazcaConstancia.detect(nil), 0)
        XCTAssertNil(NazcaConstancia.read(nil))
        XCTAssertNil(NazcaConstancia.read("   \n  "))
    }

    /// El número de operación entra en la huella: reenviar la misma constancia es «exact»; otro pago igual con otro número no lo es (igual que en la web).
    func testFingerprintUsesRef() throws {
        let a = try XCTUnwrap(NazcaConstancia.read("Yapeaste S/ 10\nDestino\nBodega Rosa\n02/10/2026 12:00\nN° de operación 12121212", today: "2026-10-29")).statement.items
        let b = try XCTUnwrap(NazcaConstancia.read("Yapeaste S/ 10\nDestino\nBodega Rosa\n02/10/2026 12:00\nN° de operación 12121299", today: "2026-10-29")).statement.items
        let pa = Nazca.fingerprints(a)[0], pb = Nazca.fingerprints(b)[0]
        XCTAssertNotEqual(pa, pb)
        let known = Nazca.Known(acc: "x", date: "2026-10-02", amount: -10, imp: pa)
        XCTAssertEqual(Nazca.markDuplicates(a, existing: [known], acc: "x")[0].dup, Nazca.Duplicate.exact)
        XCTAssertEqual(Nazca.markDuplicates(b, existing: [known], acc: "x")[0].dup, Nazca.Duplicate.none)
    }
}
