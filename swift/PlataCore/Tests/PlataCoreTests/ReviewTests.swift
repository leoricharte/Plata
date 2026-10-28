import XCTest
@testable import PlataCore

final class ReviewTests: XCTestCase {
    private func close(_ a: Double?, _ b: JSONValue?, _ tag: String) {
        switch (a, b) {
        case (nil, nil), (nil, .some(.null)): break
        case (let x?, let y?): XCTAssertEqual(x, y.doubleValue ?? .nan, accuracy: 1e-6, tag)
        default: XCTFail("\(tag): \(String(describing: a)) vs \(String(describing: b))")
        }
    }

    private func check(_ got: [ReviewCard], _ want: [JSONValue], _ tag: String) {
        XCTAssertEqual(got.map(\.k), want.map { $0["k"]!.stringValue! }, tag + " claves")
        for (g, w) in zip(got, want) {
            let t = tag + " " + g.k
            XCTAssertEqual(g.kind, w["kind"]!.stringValue, t)
            XCTAssertEqual(g.txIds, w["txs"]!.arrayValue!.map { $0.stringValue! }, t + " txs")
            close(g.score, w["score"], t + " score")
            XCTAssertEqual(g.hi, w["hi"]!.boolValue, t + " hi")
            XCTAssertEqual(g.far, w["far"]!.boolValue, t + " far")
            XCTAssertEqual(g.label, w["label"]?.stringValue, t + " label")
            XCTAssertEqual(g.cur, w["cur"]?.stringValue, t + " cur")
            close(g.out, w["out"], t + " out"); close(g.inn, w["inn"], t + " inn"); close(g.med, w["med"], t + " med")
            XCTAssertEqual(g.card, w["card"]?.stringValue, t + " card")
            XCTAssertEqual(g.acc, w["acc"]?.stringValue, t + " acc")
            XCTAssertEqual(g.miss, w["miss"]?.arrayValue?.map { $0.stringValue! }, t + " miss")
            close(g.diff, w["diff"], t + " diff")
            XCTAssertEqual(g.type, w["type"]?.stringValue, t + " type")
            XCTAssertEqual(g.name, w["name"]?.stringValue, t + " name")
            close(g.amt, w["amt"], t + " amt")
            XCTAssertEqual(g.fixed, w["fixed"]?.boolValue, t + " fixed")
            XCTAssertEqual(g.cad, w["cad"]?.stringValue, t + " cad")
            XCTAssertEqual(g.neg, w["neg"]?.boolValue, t + " neg")
            XCTAssertEqual(g.q, w["q"]?.arrayValue?.map { $0.intValue! }, t + " q")
            XCTAssertEqual(g.brand, w["brand"]?.stringValue, t + " brand")
        }
    }

    func testReviewScanMatchesWeb() throws {
        let f = try fixture("review")
        var kinds = Set<String>()
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = Engine(profile: Profile(raw: c["profile"]!), today: LocalDate(iso: c["today"]!.stringValue!)!)
            var table: [String: ReviewBrand] = [:]
            for (note, b) in c["brands"]!.objectValue! where !b.isNull { table[note] = ReviewBrand(id: b["id"]!.stringValue!, key0: b["key0"]!.stringValue!) }
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            let first = e.reviewScan(skip: [], brandOf: { table[$0] })
            check(first, c["first"]!.arrayValue!, tag)
            first.forEach { kinds.insert($0.kindKey) }
            let skip = c["skip"]!.arrayValue!.map { $0.stringValue! }
            check(e.reviewScan(skip: skip, brandOf: { table[$0] }), c["second"]!.arrayValue!, tag + " con descartadas")
        }
        XCTAssertTrue(kinds.isSuperset(of: ["xfer", "pay2", "dup", "own", "card", "big", "gap", "rec_job", "rec_sub", "rec_fix"]), "\(kinds)")
    }
}
