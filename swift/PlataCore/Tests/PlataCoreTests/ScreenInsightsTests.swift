import XCTest
@testable import PlataCore

final class ScreenInsightsTests: XCTestCase {
    private let today = LocalDate(iso: "2026-10-28")!
    private func money(_ x: Double, _ cur: String = "") -> String { "$" + String(Int(x.rounded())) }

    private func saving(goal: Double, balance: Double, monthly: Double, log: [(String, Double)] = []) -> JSONValue {
        .object(["goal": .number(goal), "balance": .number(balance), "monthly": .number(monthly), "cur": .string("USD"),
                 "log": .array(log.map { .object(["date": .string($0.0), "amount": .number($0.1)]) })])
    }

    func testSavingWithoutContributionsThisMonth() {
        let l = ScreenInsights.saving(saving(goal: 1000, balance: 200, monthly: 100), today: today, whole: money)
        XCTAssertEqual(l, ScreenInsights.Line("Aún no has aportado este mes (planeabas $100).", .warn))
    }

    func testSavingWithoutAnyPlan() {
        let l = ScreenInsights.saving(saving(goal: 1000, balance: 200, monthly: 0), today: today, whole: money)
        XCTAssertEqual(l, ScreenInsights.Line("Define un aporte mensual para ver cuándo llegas a tu meta.", .warn))
    }

    func testSavingSlowPace() {
        let sv = saving(goal: 1000, balance: 200, monthly: 100, log: [("2026-10-05", 30), ("2026-09-10", 30)])
        let l = ScreenInsights.saving(sv, today: today, whole: money)
        XCTAssertEqual(l, ScreenInsights.Line("Tu ritmo real es de ~$30/mes: la meta llegaría en ene 2029.", .warn))
    }

    func testSavingOnTrack() {
        let sv = saving(goal: 1000, balance: 200, monthly: 100, log: [("2026-10-05", 100)])
        XCTAssertEqual(ScreenInsights.saving(sv, today: today, whole: money), ScreenInsights.Line("Vas al día: ya aportaste $100 este mes.", .ok))
    }

    func testSavingGoalReachedOrMissing() {
        XCTAssertNil(ScreenInsights.saving(saving(goal: 1000, balance: 1000, monthly: 100), today: today, whole: money))
        XCTAssertNil(ScreenInsights.saving(saving(goal: 0, balance: 10, monthly: 100), today: today, whole: money))
    }

    private func card(balance: Double, apr: Double, payment: Double, limit: Double = 1000, kind: String = "card") -> JSONValue {
        .object(["balance": .number(balance), "apr": .number(apr), "payment": .number(payment), "limit": .number(limit), "kind": .string(kind), "cur": .string("USD")])
    }

    func testDebtUtilizationAndExtraPayment() {
        let c = card(balance: 2000, apr: 24, payment: 100, limit: 2500)
        let lines = ScreenInsights.debt(c, util: 80, primary: "USD", k: 1) { money($0) }
        let a = Engine.debtSim(balance: 2000, apr: 24, payment: 100)!, b = Engine.debtSim(balance: 2000, apr: 24, payment: 150)!
        XCTAssertGreaterThanOrEqual(a.interest - b.interest, 10)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], ScreenInsights.Line("Usas el 80% de tu límite: mantenerlo bajo 30% ayuda a tu historial crediticio.", .warn))
        XCTAssertEqual(lines[1], ScreenInsights.Line("Pagando $50 más al mes terminas \(a.months - b.months) meses antes y ahorras ~\(money(a.interest - b.interest)) en intereses.", .ok))
    }

    func testDebtPaymentBelowInterest() {
        let lines = ScreenInsights.debt(card(balance: 2000, apr: 24, payment: 30, kind: "loan"), util: 0, primary: "USD", k: 1) { money($0) }
        XCTAssertEqual(lines, [ScreenInsights.Line("Tu pago mensual no alcanza a cubrir los intereses.", .bad)])
    }

    func testDebtInOtherCurrencyHasNoPaymentTip() {
        let lines = ScreenInsights.debt(card(balance: 2000, apr: 24, payment: 100), util: 10, primary: "PEN", k: 3.5) { money($0) }
        XCTAssertTrue(lines.isEmpty)
    }
}
