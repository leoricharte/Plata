import XCTest
@testable import PlataCore

final class CurrencyChangeTests: XCTestCase {
    private func base() -> JSONValue {
        var p = Profile.empty.raw
        p["settings"] = .object(["currency": .string("USD"), "currency2": .string("PEN"), "fx": .number(4)])
        p["accounts"] = .array([
            .object(["id": .string("a"), "name": .string("USD"), "cur": .string("USD"), "balance": .number(100)]),
            .object(["id": .string("b"), "name": .string("Soles"), "cur": .string("PEN"), "balance": .number(400)]),
            .object(["id": .string("c"), "name": .string("Euros"), "cur": .string("EUR"), "balance": .number(50)]),
        ])
        p["transactions"] = .array([.object(["id": .number(1), "acc": .string("c"), "amount": .number(-10), "date": .string("2026-10-01"), "category": .string("Comida")])])
        return p
    }

    func test_planFindsLostCurrency() {
        let plan = CurrencyChange.plan(base(), primary: "USD", secondary: "PEN")
        XCTAssertEqual(plan.lost, ["EUR"])
        XCTAssertTrue(plan.single)
        XCTAssertGreaterThan(plan.assigned, 0)
        XCTAssertFalse(CurrencyChange.plan(base(), primary: "USD", secondary: "EUR").lost.contains("USD"))
    }

    func test_swapInvertsFxAndKeepsAmounts() {
        var p = base()
        CurrencyChange.apply(&p, primary: "PEN", secondary: "USD", mode: .keep)
        XCTAssertEqual(p["settings"]?["currency"]?.stringValue, "PEN")
        XCTAssertEqual(p["settings"]?["fx"]?.doubleValue, 0.25)
        // EUR queda fuera: pasa a PEN con el mismo monto
        let accs = p["accounts"]?.arrayValue ?? []
        XCTAssertEqual(accs[2]["cur"]?.stringValue, "PEN")
        XCTAssertEqual(accs[2]["balance"]?.doubleValue, 50)
    }

    func test_manualRateScalesAccountAndItsTransactions() {
        var p = base()
        CurrencyChange.apply(&p, primary: "USD", secondary: "PEN", mode: .manual(2))
        let accs = p["accounts"]?.arrayValue ?? []
        XCTAssertEqual(accs[2]["cur"]?.stringValue, "USD")
        XCTAssertEqual(accs[2]["balance"]?.doubleValue, 100)
        XCTAssertEqual(p["transactions"]?.arrayValue?.first?["amount"]?.doubleValue, -20)
    }

    func test_normCustom() {
        XCTAssertEqual(Onboarding.normCustom(" abc d"), "ABC")
        XCTAssertEqual(Onboarding.normCustom("USD"), "")      // ya existe
        XCTAssertEqual(Onboarding.normCustom("!?"), "")
    }
}
