import XCTest
@testable import PlataCore

final class DemoTests: XCTestCase {
    /// Los perfiles de demostración, movidos a distintos "hoy", deben quedar igual que con `rebaseProfile` + `migrate` de la web.
    func testMatchesWebRebase() throws {
        let f = try fixture("demo")
        let demos = f["demos"]!.objectValue!
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let id = c["id"]!.stringValue!
            let today = LocalDate(iso: c["today"]!.stringValue!)!
            let data = try demos[id]!.jsonData()
            let got = try DemoProfile.load(data, today: today)
            XCTAssertTrue(got.isDemo)
            var raw = got.raw
            raw["demo"] = nil
            let want = c["want"]!
            XCTAssertEqual(raw.objectValue?.keys.sorted(), want.objectValue?.keys.sorted(), "caso \(i) (\(id) \(today.iso)): claves")
            for (k, v) in want.objectValue! where raw[k] != v {
                XCTAssertEqual(raw[k], v, "caso \(i) (\(id) \(today.iso)): \(k)")
            }
        }
    }

    func testDemoRunsInEngine() throws {
        let f = try fixture("demo")
        let src = f["demos"]!["shawn"]!
        let today = LocalDate(iso: "2026-10-28")!
        let p = try DemoProfile.load(src.jsonData(), today: today)
        let e = Engine(profile: p, today: today)
        let c = e.calc()
        XCTAssertFalse(e.allTransactions.isEmpty)
        XCTAssertTrue(c.months.count > 0)
        XCTAssertTrue(e.allTransactions.allSatisfy { Engine.text($0["date"]) <= today.iso })
    }
}
