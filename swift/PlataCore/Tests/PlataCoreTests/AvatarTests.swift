import XCTest
@testable import PlataCore

final class AvatarTests: XCTestCase {
    private let today = LocalDate(iso: "2026-10-28")!

    func testNoDataNoBadge() {
        let e = Engine(profile: Profile.empty, today: today)
        XCTAssertNil(e.avatarInfo())
        XCTAssertTrue(e.gradeCounts().isEmpty)
    }

    func testScoreOffHidesBadgeAndCounts() {
        var p = Profile.empty.raw
        p["settings"] = .object(["score": .bool(false)])
        let e = Engine(profile: Profile(raw: p), today: today)
        XCTAssertNil(e.avatarInfo())
        XCTAssertTrue(e.gradeCounts().isEmpty)
    }

    func testBadgeAfterTwoMonthsOfMovements() {
        var p = Profile.empty.raw
        p["accounts"] = .array([.object(["id": .string("a1"), "name": .string("Banco"), "cur": .string("USD"), "balance": .number(0)])])
        var tx: [JSONValue] = []
        var id = 1.0
        for (mk, d) in [("2026-08", 0), ("2026-09", 0)] {
            _ = d
            for day in 1...12 {
                let ds = mk + "-" + (day < 10 ? "0\(day)" : "\(day)")
                tx.append(.object(["id": .number(id), "date": .string(ds), "amount": .number(-10), "category": .string("Comida"), "note": .string("x"), "acc": .string("a1")])); id += 1
            }
            tx.append(.object(["id": .number(id), "date": .string(mk + "-02"), "amount": .number(1000), "category": .string("Ingreso"), "note": .string("sueldo"), "acc": .string("a1")])); id += 1
        }
        p["transactions"] = .array(tx)
        let e = Engine(profile: Profile(raw: p), today: today)
        let info = e.avatarInfo()
        XCTAssertNotNil(info)
        XCTAssertTrue(info!.label.hasPrefix(info!.letter) || info!.label == "S*")
        XCTAssertFalse(e.gradeCounts().isEmpty)
    }
}
