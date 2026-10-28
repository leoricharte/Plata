import XCTest
@testable import PlataCore

final class ConfirmTests: XCTestCase {
    private func base() -> JSONValue {
        var p = Profile.empty.raw
        p["accounts"] = .array([.object(["id": .string("a1"), "name": .string("Banco"), "cur": .string("USD"), "balance": .number(100)])])
        p["cards"] = .array([.object(["id": .string("c1"), "name": .string("Visa"), "cur": .string("USD"), "balance": .number(200), "due_day": .number(15), "payment": .number(50),
                                      "auto": .object(["next": .string("2026-10-15"), "from": .string("a1")])])])
        return p
    }

    func testNextOccurrenceAndDueAfter() {
        XCTAssertEqual(Engine.nextOccurrence("2026-10-28", .number(14)), "2026-11-11")
        XCTAssertEqual(Engine.nextOccurrence("2026-01-31", .string("m")), "2026-02-28")
        XCTAssertEqual(Engine.dueAfter(day: 15, after: "2026-10-28"), "2026-11-15")
        XCTAssertEqual(Engine.dueAfter(day: 31, after: "2026-11-30"), "2026-12-31")
        XCTAssertEqual(Engine.dueAfter(day: 5, after: "2026-12-20"), "2027-01-05")
    }

    func testConfirmIncomeAddsMovementAndBalance() {
        var p = base()
        p["expected_income"] = .array([.object(["id": .number(1), "name": .string("Sueldo"), "amount": .number(500), "acc": .string("a1"), "date": .string("2026-10-28"), "repeat": .string("m")])])
        ProfileEditor.confirmIncome(&p, date: "2026-10-28", amount: 520, name: "Sueldo", account: .string("a1"), estimate: 500, job: nil, rate: 0, hours: 0, now: 1_000)
        XCTAssertEqual(p["accounts"]?.arrayValue?[0]["balance"]?.doubleValue, 620)
        let tx = p["transactions"]!.arrayValue![0]
        XCTAssertEqual(Engine.str(tx["category"]), "Ingreso")
        XCTAssertEqual(tx["est"]?.doubleValue, 500)
        ProfileEditor.finishExpected(&p, collection: "expected_income", id: .number(1), next: "2026-11-28")
        XCTAssertEqual(Engine.str(p["expected_income"]?.arrayValue?[0]["date"]), "2026-11-28")
        ProfileEditor.finishExpected(&p, collection: "expected_income", id: .number(1), next: nil)
        XCTAssertTrue(p["expected_income"]!.arrayValue!.isEmpty)
    }

    func testSnoozeHidesFromPending() {
        var p = base()
        p["expected_expense"] = .array([.object(["id": .number(2), "name": .string("Renta"), "amount": .number(80), "acc": .string("a1"), "date": .string("2026-10-20")])])
        let today = LocalDate(iso: "2026-10-28")!
        XCTAssertEqual(Engine(profile: Profile(raw: p), today: today).pendingItems().filter { $0.kind == "out" }.count, 1)
        ProfileEditor.snoozeExpected(&p, collection: "expected_expense", id: .number(2), until: "2026-10-29")
        XCTAssertTrue(Engine(profile: Profile(raw: p), today: today).pendingItems().filter { $0.kind == "out" }.isEmpty)
        ProfileEditor.snoozeCardAuto(&p, id: .string("c1"), until: "2026-10-29")
        XCTAssertTrue(Engine(profile: Profile(raw: p), today: today).pendingItems().filter { $0.kind == "pay" }.isEmpty)
    }

    func testCardPayAdvancesOrTurnsOff() {
        var p = base()
        ProfileEditor.registerPay(&p, card: .string("c1"), amount: 50, fromAmount: 50, date: "2026-10-28", from: .string("a1"), note: "Pago", now: 1_000, pair: "x")
        XCTAssertFalse(ProfileEditor.advanceCardAuto(&p, id: .string("c1"), from: "a1", today: "2026-10-28"))
        XCTAssertEqual(Engine.str(p["cards"]?.arrayValue?[0]["auto"]?["next"]), "2026-11-15")
        XCTAssertEqual(p["accounts"]?.arrayValue?[0]["balance"]?.doubleValue, 50)
        ProfileEditor.registerPay(&p, card: .string("c1"), amount: 150, fromAmount: 150, date: "2026-10-28", from: nil, note: "Pago", now: 2_000, pair: "y")
        XCTAssertTrue(ProfileEditor.advanceCardAuto(&p, id: .string("c1"), from: "", today: "2026-10-28"))
        XCTAssertNil(p["cards"]?.arrayValue?[0]["auto"])
    }

    func testJobHoursAndTax() {
        let j: JSONValue = .object(["mode": .string("h"), "hours": .number(40), "freq": .string("b")])
        XCTAssertEqual(Engine.jobHours(j), 80)
        XCTAssertEqual(Engine.taxPercent(amount: 800, rate: 20, hours: 50), 20)
        XCTAssertEqual(Engine.taxPercent(amount: 10, rate: 0, hours: 0), 0)
    }
}
