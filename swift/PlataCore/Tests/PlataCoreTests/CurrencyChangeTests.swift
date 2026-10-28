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
        p["settings"] = .object(["currency": .string("USD"), "currency2": .string(""), "fx": .number(4)])   // la segunda moneda cambia a PEN: EUR queda fuera
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

final class FormCurrencySwitchTests: XCTestCase {
    private func base() -> JSONValue {
        var p = Profile.empty.raw
        p["settings"] = .object(["currency": .string("PEN"), "currency2": .string("USD"), "fx": .number(0.27)])
        p["accounts"] = .array([.object(["id": .string("a"), "name": .string("Soles"), "cur": .string("PEN"), "balance": .number(100)])])
        p["transactions"] = .array([.object(["id": .number(1), "acc": .string("a"), "amount": .number(-30), "date": .string("2026-10-01"), "category": .string("Comida")])])
        return p
    }

    func testAsksOnlyBetweenTheProfilesTwoCurrenciesWithAmounts() {
        let p = base()
        XCTAssertTrue(CurrencyChange.asksOnFormSwitch(p, from: "PEN", to: "USD", hasMoney: true, linked: false))
        XCTAssertTrue(CurrencyChange.asksOnFormSwitch(p, from: "PEN", to: "USD", hasMoney: false, linked: true))
        XCTAssertFalse(CurrencyChange.asksOnFormSwitch(p, from: "PEN", to: "USD", hasMoney: false, linked: false))   // nada que convertir
        XCTAssertFalse(CurrencyChange.asksOnFormSwitch(p, from: "PEN", to: "PEN", hasMoney: true, linked: false))
        XCTAssertFalse(CurrencyChange.asksOnFormSwitch(p, from: "PEN", to: "EUR", hasMoney: true, linked: false))    // EUR no es una de las dos
        var one = p; one["settings"] = .object(["currency": .string("PEN")])
        XCTAssertFalse(CurrencyChange.asksOnFormSwitch(one, from: "PEN", to: "USD", hasMoney: true, linked: false))   // sin segunda moneda
    }

    func testAssignedRateUsesTheProfileFxBothWays() {
        let p = base()
        XCTAssertEqual(CurrencyChange.assignedRate(p, from: "PEN", to: "USD"), 0.27)
        XCTAssertEqual(CurrencyChange.assignedRate(p, from: "USD", to: "PEN"), 3.704)   // 1 / 0.27 con 4 cifras
    }

    func testScaledRoundsToTheCurrencysDecimals() {
        XCTAssertEqual(CurrencyChange.scaled(30, factor: 0.27, cur: "USD"), 8.1)
        XCTAssertEqual(CurrencyChange.scaled(0, factor: 3, cur: "USD"), 0)
        XCTAssertEqual(CurrencyChange.scaled(100, factor: 0.333, cur: "CLP"), 33)   // CLP no usa decimales
    }

    func testScaleLinkedConvertsTheAccountsMovements() {
        var p = base()
        CurrencyChange.scaleLinked(&p, id: "a", factor: 0.27, cur: "USD")
        XCTAssertEqual(p["transactions"]!.arrayValue![0]["amount"]!.doubleValue!, -8.1)
    }
}
