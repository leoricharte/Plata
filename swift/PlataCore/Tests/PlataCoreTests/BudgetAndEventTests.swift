import XCTest
@testable import PlataCore

final class BudgetAndEventTests: XCTestCase {
    private func empty() -> JSONValue { Profile.empty.raw }

    func testNewSetCopiesBaseLimits() throws {
        var p = empty()
        p["budget"] = .object(["Comida": .number(300)])
        try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: true, name: "  Rodaje ", from: "2026-11-01", to: "2026-11-30", cur: "", sourceSetId: nil)
        let sets = p["budgetSets"]!.arrayValue!
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(Engine.str(sets[0]["name"]), "Rodaje")
        XCTAssertEqual(sets[0]["budget"]?["Comida"]?.doubleValue, 300)
    }

    func testOverlappingSetIsRefused() throws {
        var p = empty()
        try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: true, name: "Uno", from: "2026-11-01", to: "2026-11-30", cur: "", sourceSetId: nil)
        XCTAssertThrowsError(try ProfileEditor.saveBudgetSet(&p, id: "b2", isNew: true, name: "Dos", from: "2026-11-15", to: "2026-12-15", cur: "", sourceSetId: nil)) {
            XCTAssertEqual($0 as? ProfileEditor.FormError, .setOverlap("Uno"))
        }
        // editar el mismo set con sus propias fechas sí se puede
        XCTAssertNoThrow(try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: false, name: "Uno", from: "2026-11-02", to: "2026-11-29", cur: "", sourceSetId: nil))
    }

    func testSetValidation() {
        var p = empty()
        XCTAssertThrowsError(try ProfileEditor.saveBudgetSet(&p, id: "x", isNew: true, name: "", from: "2026-11-01", to: "2026-11-02", cur: "", sourceSetId: nil)) {
            XCTAssertEqual($0 as? ProfileEditor.FormError, .missingName)
        }
        XCTAssertThrowsError(try ProfileEditor.saveBudgetSet(&p, id: "x", isNew: true, name: "N", from: "2026-11-05", to: "2026-11-02", cur: "", sourceSetId: nil)) {
            XCTAssertEqual($0 as? ProfileEditor.FormError, .endBeforeStart)
        }
    }

    func testDeleteSet() throws {
        var p = empty()
        try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: true, name: "Uno", from: "2026-11-01", to: "2026-11-30", cur: "", sourceSetId: nil)
        ProfileEditor.deleteBudgetSet(&p, id: "a1")
        XCTAssertEqual(p["budgetSets"]!.arrayValue!.count, 0)
    }

    func testViewSetSelection() throws {
        var p = empty()
        try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: true, name: "Uno", from: "2026-10-01", to: "2026-10-31", cur: "", sourceSetId: nil)
        let e = Engine(profile: Profile(raw: p), today: LocalDate(iso: "2026-10-28")!)
        XCTAssertEqual(Engine.str(e.viewSet(nil)?["id"]), "a1")      // el que rige hoy
        XCTAssertNil(e.viewSet("base"))
        XCTAssertEqual(Engine.str(e.viewSet("a1")?["id"]), "a1")
    }

    func testEventOverrideRoundTrip() {
        var p = empty()
        ProfileEditor.setEventOverride(&p, key: "sub:1:2026-11-03", entry: .object(["skip": .bool(true)]))
        XCTAssertEqual(p["ovr"]?["sub:1:2026-11-03"]?["skip"], .bool(true))
        ProfileEditor.setEventOverride(&p, key: "sub:1:2026-11-03", entry: nil)
        XCTAssertNil(p["ovr"]?["sub:1:2026-11-03"])
    }

    func testCategoryLimitGoesToChosenSet() throws {
        var p = empty()
        try ProfileEditor.saveBudgetSet(&p, id: "a1", isNew: true, name: "Uno", from: "2026-11-01", to: "2026-11-30", cur: "", sourceSetId: nil)
        try ProfileEditor.saveCategory(&p, original: nil, name: "Café", color: "#B98AE6", icon: "cup", limitUSD: 40, setId: .string("a1"))
        XCTAssertEqual(p["budgetSets"]!.arrayValue![0]["budget"]?["Café"]?.doubleValue, 40)
        XCTAssertNil(p["budget"]?["Café"])
        XCTAssertThrowsError(try ProfileEditor.saveCategory(&p, original: nil, name: "Café", color: "#fff", icon: "", limitUSD: 0, setId: nil)) {
            XCTAssertEqual($0 as? ProfileEditor.FormError, .duplicateCategory)
        }
    }
}
