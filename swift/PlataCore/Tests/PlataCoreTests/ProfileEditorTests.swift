import XCTest
@testable import PlataCore

final class ProfileEditorTests: XCTestCase {
    private func base() -> JSONValue {
        var p = Profile.empty.raw
        p["accounts"] = .array([.object(["id": .string("bank"), "name": .string("Cuenta"), "type": .string("checking"), "cur": .string("USD"), "balance": .number(100)]),
                                .object(["id": .string("sav"), "name": .string("Ahorro"), "type": .string("savings"), "cur": .string("USD"), "balance": .number(10)])])
        p["cards"] = .array([.object(["id": .string("c1"), "name": .string("Tarjeta"), "kind": .string("card"), "cur": .string("USD"), "balance": .number(200), "limit": .number(1000), "apr": .number(20)])])
        return p
    }
    private func bal(_ p: JSONValue, _ col: String, _ i: Int) -> Double { p[col]!.arrayValue![i]["balance"]!.doubleValue! }

    func testExpenseLowersAccountAndRaisesCardDebt() throws {
        var p = base()
        try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: -30.5, category: "Comida", note: "x", account: "bank", now: 1_790_000_000_000, jitter: 1)
        XCTAssertEqual(bal(p, "accounts", 0), 69.5)
        try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: -50, category: "Ocio", note: "y", account: "c1", now: 1_790_000_000_000, jitter: 2)
        XCTAssertEqual(bal(p, "cards", 0), 250)
        XCTAssertEqual(p["transactions"]!.arrayValue!.count, 2)
    }

    func testIncomeOnCardIsRefused() {
        var p = base()
        XCTAssertThrowsError(try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: 20, category: "Ingreso", note: "", account: "c1", now: 1, jitter: 0)) {
            XCTAssertEqual($0 as? ProfileEditor.EditError, .incomeOnCard)
        }
    }

    func testIdsAlwaysGrow() throws {
        var p = base()
        let a = try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: -1, category: "Otros", note: "", account: "bank", now: 1_790_000_000_000, jitter: 5)
        let b = try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: -1, category: "Otros", note: "", account: "bank", now: 1_000, jitter: 0)   // reloj atrasado
        XCTAssertGreaterThan(b, a)
    }

    func testDeleteRestoresBalances() throws {
        var p = base()
        let id = try ProfileEditor.addTransaction(&p, date: "2026-10-28", amount: -40, category: "Comida", note: "", account: "bank", now: 1, jitter: 0)
        try ProfileEditor.deleteTransaction(&p, id: .number(id))
        XCTAssertEqual(bal(p, "accounts", 0), 100)
        XCTAssertEqual(p["transactions"], .array([]))
        XCTAssertThrowsError(try ProfileEditor.deleteTransaction(&p, id: .number(id)))
    }

    func testEditMovesTheEffectBetweenAccounts() throws {
        var p = base()
        let id = try ProfileEditor.addTransaction(&p, date: "2026-10-27", amount: -40, category: "Comida", note: "cena", account: "bank", now: 1, jitter: 0)
        try ProfileEditor.updateTransaction(&p, id: .number(id), amount: 25, isOut: true, category: "Ocio", account: "sav", date: "2026-10-28", note: " ")
        XCTAssertEqual(bal(p, "accounts", 0), 100)       // se devolvieron los 40
        XCTAssertEqual(bal(p, "accounts", 1), -15)       // 10 − 25
        let t = p["transactions"]!.arrayValue![0]
        XCTAssertEqual(t["amount"], .number(-25))
        XCTAssertEqual(t["category"], .string("Ocio"))
        XCTAssertEqual(t["note"], .string("cena"))       // una nota vacía conserva la anterior
        // pasar de gasto a ingreso
        try ProfileEditor.updateTransaction(&p, id: .number(id), amount: 25, isOut: false, category: "", account: "sav", date: "2026-10-28", note: "")
        XCTAssertEqual(bal(p, "accounts", 1), 35)
        XCTAssertEqual(p["transactions"]!.arrayValue![0]["category"], .string("Ingreso"))
    }

    func testPairedTransactionsAreDeletedTogether() throws {
        var p = base()
        p["transactions"] = .array([
            .object(["id": .number(1), "date": .string("2026-10-28"), "amount": .number(-20), "category": .string("Transferencia"), "note": .string(""), "acc": .string("bank"), "pair": .string("a")]),
            .object(["id": .number(2), "date": .string("2026-10-28"), "amount": .number(20), "category": .string("Transferencia"), "note": .string(""), "acc": .string("sav"), "pair": .string("a")]),
        ])
        try ProfileEditor.deleteTransaction(&p, id: .number(1))
        XCTAssertEqual(p["transactions"], .array([]))
        XCTAssertEqual(bal(p, "accounts", 0), 120)
        XCTAssertEqual(bal(p, "accounts", 1), -10)
    }
}
