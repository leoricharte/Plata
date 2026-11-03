import XCTest
@testable import PlataCore

/// El pago mensual de una tarjeta o préstamo termina cuando se acaba la deuda (con intereses): los números de cada caso
/// salen del motor de la web (`genEvents` de dev/app/src/app.html), que es la referencia.
final class CardPaymentEndTests: XCTestCase {
    private func engine(_ card: JSONValue, today: String = "2026-11-02") throws -> Engine {
        let acc: JSONValue = .object(["id": .string("bank"), "name": .string("Banco"), "type": .string("checking"), "cur": .string("USD"), "balance": .number(5000)])
        let raw: JSONValue = .object(["version": .number(3),
                                      "settings": .object(["currency": .string("USD"), "cushion": .number(0), "variable_weekly": .number(0)]),
                                      "accounts": .array([acc]), "cards": .array([card]), "transactions": .array([])])
        return Engine(profile: try Migration.migrate(Profile(raw: raw)), today: LocalDate(iso: today)!)
    }

    private func card(kind: String = "card", balance: Double, apr: Double = 0, payment: Double, day: Int) -> JSONValue {
        .object(["id": .string("k"), "kind": .string(kind), "name": .string("Visa"), "cur": .string("USD"), "limit": .number(kind == "loan" ? 0 : 5000),
                 "balance": .number(balance), "apr": .number(apr), "payment": .number(payment), "due_day": .number(Double(day))])
    }

    /// Los cobros de tarjeta del calendario: (fecha, monto).
    private func payments(_ e: Engine) -> [(date: String, amount: Double)] {
        e.genEvents().filter { $0.type == "card" }.map { (date: $0.date.iso, amount: -$0.amt) }
    }

    private func check(_ got: [(date: String, amount: Double)], _ want: [(String, Double)], _ tag: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(got.count, want.count, "\(tag): cantidad de cobros", file: file, line: line)
        for (g, w) in zip(got, want) {
            XCTAssertEqual(g.date, w.0, "\(tag): fecha", file: file, line: line)
            XCTAssertEqual(g.amount, w.1, accuracy: 0.005, "\(tag): monto del \(w.0)", file: file, line: line)
        }
    }

    func testLastPaymentIsWhatIsLeft() throws {
        let e = try engine(card(balance: 150, payment: 100, day: 10))
        check(payments(e), [("2026-11-10", 100), ("2026-12-10", 50)], "deuda 150, pago 100")
    }

    func testPaidOffDebtHasNoPayments() throws {
        let e = try engine(card(balance: 0, payment: 100, day: 10))
        XCTAssertTrue(payments(e).isEmpty)
    }

    func testLoanEndsAfterItsInstallments() throws {
        let e = try engine(card(kind: "loan", balance: 300, payment: 100, day: 5))
        check(payments(e), [("2026-11-05", 100), ("2026-12-05", 100), ("2027-01-05", 100)], "préstamo de 300")
    }

    func testInterestAddsToTheDebtEveryMonth() throws {
        // 1000 al 24 % anual (2 % al mes) pagando 100: no se acaba en 10 cuotas; la 12.ª es lo que queda
        let e = try engine(card(balance: 1000, apr: 24, payment: 100, day: 10))
        let p = payments(e)
        XCTAssertEqual(p.count, 12)
        for x in p.prefix(11) { XCTAssertEqual(x.amount, 100, accuracy: 0.005) }
        XCTAssertEqual(p[11].date, "2027-10-10")
        XCTAssertEqual(p[11].amount, 27.04, accuracy: 0.005)
    }

    func testFinalInstallmentWithInterestAndDay31() throws {
        // 250 al 12 % anual, pago 100, día 31 (febrero cae el 28)
        let e = try engine(card(kind: "loan", balance: 250, apr: 12, payment: 100, day: 31), today: "2027-01-30")
        check(payments(e), [("2027-01-31", 100), ("2027-02-28", 100), ("2027-03-31", 54.57)], "préstamo con interés")
    }

    func testPaymentBelowInterestKeepsGoing() throws {
        // 10.000 al 24 %: el interés (200) supera el pago (100), la deuda no baja y el pago sigue todo el calendario
        let e = try engine(card(balance: 10000, apr: 24, payment: 100, day: 10))
        let p = payments(e)
        XCTAssertEqual(p.count, 12)
        for x in p { XCTAssertEqual(x.amount, 100, accuracy: 0.005) }
    }
}
