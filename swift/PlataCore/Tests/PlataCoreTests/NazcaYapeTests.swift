import XCTest
@testable import PlataCore

/// Excel (.xlsx) y Yape: los resultados esperados salen de ejecutar `xlsx.js` y `bancos/yape-movimientos.js` de la web.
final class NazcaYapeTests: XCTestCase {
    private func golden() throws -> JSONValue { try fixture("nazca_csv") }

    private func rows(_ j: JSONValue) -> [[String]] { j.arrayValue!.map { $0.arrayValue!.map { $0.stringValue ?? "" } } }

    private func check(_ got: Nazca.StatementResult?, _ want: JSONValue, _ tag: String) throws {
        if want.isNull { XCTAssertNil(got, tag); return }
        let g = try XCTUnwrap(got, tag)
        XCTAssertEqual(g.bank, want["bank"]!.stringValue, tag)
        XCTAssertEqual(g.kind, want["kind"]!.stringValue, tag)
        XCTAssertEqual(g.label, want["label"]!.stringValue, tag)
        XCTAssertEqual(g.cur, want["cur"]!.stringValue, tag)
        if let p = want["period"], !p.isNull { XCTAssertEqual(g.period, .init(from: p["from"]!.stringValue!, to: p["to"]!.stringValue!), tag) } else { XCTAssertNil(g.period, tag) }
        let items = want["items"]!.arrayValue!
        XCTAssertEqual(g.items.count, items.count, tag)
        for (i, w) in items.enumerated() where i < g.items.count {
            XCTAssertEqual(g.items[i].line, w["line"]!.intValue, "\(tag)[\(i)] line")
            XCTAssertEqual(g.items[i].date, w["date"]!.stringValue, "\(tag)[\(i)] date")
            XCTAssertEqual(g.items[i].desc, w["desc"]!.stringValue, "\(tag)[\(i)] desc")
            XCTAssertEqual(g.items[i].amount, w["amount"]!.doubleValue!, "\(tag)[\(i)] amount")
            XCTAssertEqual(g.items[i].cur, w["cur"]!.stringValue, "\(tag)[\(i)] cur")
        }
        XCTAssertEqual(g.unreadable, want["skipped"]!["unreadable"]!.intValue, tag)
        XCTAssertEqual(g.zero, want["skipped"]!["zero"]!.intValue, tag)
    }

    func testXlsxFilesReadLikeTheWeb() throws {
        let cases = try golden()["xlsx"]!.arrayValue!
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            let name = c["name"]!.stringValue!
            let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/xlsx/\(name)")
            let got = try NazcaXLSX.read(Data(contentsOf: url))
            XCTAssertEqual(got, rows(c["rows"]!), name)
            XCTAssertEqual(NazcaYape.detect(got), c["detect"]!.boolValue, name)
            try check(NazcaYape.read(got), c["yape"]!, name)
        }
    }

    func testYapeSyntheticRows() throws {
        let g = try golden()
        let s = g["yapeSynth"]!
        let r = rows(s["rows"]!)
        XCTAssertEqual(NazcaYape.detect(r), s["detect"]!.boolValue)
        try check(NazcaYape.read(r), s["yape"]!, "synth")
        let no = g["yapeNo"]!.arrayValue!.map { $0.boolValue! }
        XCTAssertEqual([NazcaYape.detect([["a", "b"], ["1", "2"]]), NazcaYape.detect([])], no)
    }

    func testNotAZip() {
        XCTAssertThrowsError(try NazcaXLSX.read(Data("hola,mundo".utf8)))
    }
}
