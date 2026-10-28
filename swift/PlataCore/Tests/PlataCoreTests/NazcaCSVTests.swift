import XCTest
@testable import PlataCore

/// Nazca (CSV) debe dar lo mismo que la web: los resultados esperados salen de ejecutar `dev/app/src/core/nazca/csv.js`
/// (swift/tools/gen-nazca.mjs) sobre los archivos de dev/tests/csv y sobre muchos casos sueltos.
final class NazcaCSVTests: XCTestCase {
    private func golden() throws -> JSONValue { try fixture("nazca_csv") }

    private func csvData(_ name: String) throws -> Data {
        let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/csv/\(name)")
        return try Data(contentsOf: url)
    }

    func testFiles() throws {
        let g = try golden()
        for f in g["files"]!.arrayValue! {
            let name = f["name"]!.stringValue!
            let a = try Nazca.analyze(Nazca.decode(csvData(name)))
            XCTAssertEqual(a.delim, f["delim"]!.stringValue, name)
            XCTAssertEqual(a.headerRow, f["headerRow"]!.intValue, name)
            XCTAssertEqual(a.headers, f["headers"]!.arrayValue!.map { $0.stringValue! }, name)
            XCTAssertEqual(a.width, f["width"]!.intValue, name)
            XCTAssertEqual(a.dec, f["dec"]!.stringValue, name)
            XCTAssertEqual(a.order, f["order"]!.stringValue, name)
            XCTAssertEqual(a.rows.count, f["rows"]!.intValue, name)
            XCTAssertEqual(a.truncated, f["truncated"]!.boolValue, name)
            for (role, v) in f["cols"]!.objectValue! { XCTAssertEqual(a.cols[role], v.intValue, "\(name) col \(role)") }
            let e = Nazca.extract(a)
            XCTAssertEqual(e.skipped.blank, f["skipped"]!["blank"]!.intValue, name)
            XCTAssertEqual(e.skipped.unreadable, f["skipped"]!["unreadable"]!.intValue, name)
            XCTAssertEqual(e.skipped.total, f["skipped"]!["total"]!.intValue, name)
            let want = f["items"]!.arrayValue!
            XCTAssertEqual(e.items.count, want.count, name)
            for (i, w) in want.enumerated() where i < e.items.count {
                let it = e.items[i]
                XCTAssertEqual(it.line, w["line"]!.intValue, "\(name)[\(i)] line")
                XCTAssertEqual(it.date, w["date"]!.stringValue, "\(name)[\(i)] date")
                XCTAssertEqual(it.desc, w["desc"]!.stringValue, "\(name)[\(i)] desc")
                XCTAssertEqual(it.amount, w["amount"]!.doubleValue!, "\(name)[\(i)] amount")
                XCTAssertEqual(it.cur, w["cur"]!.stringValue, "\(name)[\(i)] cur")
                XCTAssertEqual(it.balance, w["balance"]!.doubleValue, "\(name)[\(i)] balance")
            }
        }
    }

    func testAmounts() throws {
        for c in try golden()["amounts"]!.arrayValue! {
            let v = c["v"]!.stringValue!, dec = c["dec"]!.stringValue!
            XCTAssertEqual(Nazca.parseAmount(v, dec), c["out"]!.doubleValue, "parseAmount(\(v), \(dec))")
        }
    }

    func testDates() throws {
        for c in try golden()["dates"]!.arrayValue! {
            let v = c["v"]!.stringValue!, order = c["order"]!.stringValue!
            XCTAssertEqual(Nazca.parseDate(v, order), c["out"]!.stringValue, "parseDate(\(v), \(order))")
            let p = Nazca.dateParts(v)
            if let w = c["parts"], !w.isNull {
                XCTAssertEqual(p, Nazca.DateParts(k: w["k"]!.stringValue!, a: w["a"]!.intValue!, b: w["b"]!.intValue!, c: w["c"]!.intValue!), "dateParts(\(v))")
            } else { XCTAssertNil(p, "dateParts(\(v))") }
        }
    }

    func testNormCurRole() throws {
        let g = try golden()
        for c in g["norms"]!.arrayValue! { XCTAssertEqual(Nazca.norm(c["v"]!.stringValue!), c["out"]!.stringValue, "norm(\(c["v"]!.stringValue!))") }
        for c in g["curs"]!.arrayValue! { XCTAssertEqual(Nazca.curOf(c["v"]!.stringValue!), c["out"]!.stringValue, "curOf(\(c["v"]!.stringValue!))") }
        for c in g["roles"]!.arrayValue! { XCTAssertEqual(Nazca.roleOf(c["v"]!.stringValue!), c["out"]!.stringValue, "roleOf(\(c["v"]!.stringValue!))") }
    }

    private func known(_ j: JSONValue) -> Nazca.Known {
        Nazca.Known(acc: j["acc"]?.stringValue ?? "", date: j["date"]?.stringValue ?? "", amount: j["amount"]?.doubleValue ?? 0,
                    note: j["note"]?.stringValue ?? "", category: j["category"]?.stringValue ?? "", imp: j["imp"]?.stringValue ?? "")
    }

    func testCategories() throws {
        let g = try golden()
        let sets = g["cats"]!.arrayValue!
        let fns = sets.map { s in Nazca.categorizer(s["cats"]!.arrayValue!.map { $0.stringValue! }, history: s["hist"]!.arrayValue!.map(known)) }
        for c in g["categories"]!.arrayValue! {
            let d = c["d"]!.stringValue!, am = c["am"]!.doubleValue!
            XCTAssertEqual(fns[c["set"]!.intValue!](d, am), c["out"]!.stringValue, "set \(c["set"]!.intValue!): \(d) \(am)")
        }
        for c in g["merchants"]!.arrayValue! { XCTAssertEqual(Nazca.merchant(c["d"]!.stringValue!), c["out"]!.stringValue, "merchant(\(c["d"]!.stringValue!))") }
    }

    func testDuplicates() throws {
        let fp = try golden()["fp"]!
        let items = fp["items"]!.arrayValue!.map { Nazca.Item(line: $0["line"]!.intValue!, date: $0["date"]!.stringValue!, desc: $0["desc"]!.stringValue!, amount: $0["amount"]!.doubleValue!) }
        XCTAssertEqual(Nazca.fingerprints(items), fp["prints"]!.arrayValue!.map { $0.stringValue! })
        let existing = fp["existing"]!.arrayValue!.map(known)
        for (key, acc) in [("dups", "a"), ("dupsMix", "otra")] {
            let got = Nazca.markDuplicates(items, existing: existing, acc: acc)
            let want = fp[key]!.arrayValue!
            XCTAssertEqual(got.count, want.count)
            for (i, w) in want.enumerated() where i < got.count {
                XCTAssertEqual(got[i].fp, w["fp"]!.stringValue, "\(key)[\(i)] fp")
                XCTAssertEqual(got[i].dup.rawValue, w["dup"]!.stringValue, "\(key)[\(i)] dup")
            }
        }
    }
}
