import XCTest
@testable import PlataCore

final class AccountMenuTests: XCTestCase {
    private func acc(_ id: String, _ name: String, cur: String = "USD", balance: Double, last4: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["id": .string(id), "name": .string(name), "type": .string("checking"), "cur": .string(cur), "balance": .number(balance)]
        if let last4 { o["last4"] = .string(last4) }
        return .object(o)
    }
    private func card(_ id: String, _ name: String, kind: String = "card", cur: String = "USD", balance: Double, limit: Double, last4: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["id": .string(id), "name": .string(name), "kind": .string(kind), "cur": .string(cur),
                                      "balance": .number(balance), "limit": .number(limit), "apr": .number(20)]
        if let last4 { o["last4"] = .string(last4) }
        return .object(o)
    }
    private func tx(_ date: String, _ acc: String?) -> JSONValue {
        var o: [String: JSONValue] = ["id": .number(1), "date": .string(date), "amount": .number(-5), "category": .string("Comida")]
        if let acc { o["acc"] = .string(acc) }
        return .object(o)
    }
    private func engine(accounts: [JSONValue], cards: [JSONValue], txs: [JSONValue], today: String = "2026-11-02") -> Engine {
        var p = Profile.empty.raw
        p["accounts"] = .array(accounts)
        p["cards"] = .array(cards)
        p["transactions"] = .array(txs)
        return Engine(profile: Profile(raw: p), today: LocalDate(iso: today)!)
    }
    private func ids(_ items: [JSONValue]) -> [String] { items.map { Engine.str($0["id"]) } }

    func testMostUsedInTheLast90DaysComesFirst() {
        let e = engine(accounts: [acc("a", "A", balance: 1), acc("b", "B", balance: 1), acc("c", "C", balance: 1)], cards: [],
                       txs: [tx("2026-10-30", "c"), tx("2026-10-01", "c"), tx("2026-09-15", "b"),
                             tx("2026-01-01", "a"), tx("2026-01-02", "a"), tx("2026-01-03", "a")])   // «a» tiene muchos, pero viejos
        XCTAssertEqual(ids(e.accountsByUse), ["c", "b", "a"])
    }

    func testTiesKeepTheOriginalOrder() {
        let e = engine(accounts: [acc("a", "A", balance: 1), acc("b", "B", balance: 1)], cards: [], txs: [])
        XCTAssertEqual(ids(e.accountsByUse), ["a", "b"])
        let e2 = engine(accounts: [acc("a", "A", balance: 1), acc("b", "B", balance: 1)], cards: [], txs: [tx("2026-10-30", "a"), tx("2026-10-30", "b")])
        XCTAssertEqual(ids(e2.accountsByUse), ["a", "b"])
    }

    func testFutureAndEdgeDays() {
        // hoy 2 nov: hace 90 días es el 4 ago (cuenta); el 3 ago ya no; un movimiento de mañana no cuenta
        let e = engine(accounts: [acc("a", "A", balance: 1), acc("b", "B", balance: 1)], cards: [],
                       txs: [tx("2026-08-04", "b"), tx("2026-08-03", "a"), tx("2026-08-03", "a"), tx("2026-11-03", "a"), tx("2026-11-03", "a")])
        XCTAssertEqual(e.recentUse()["b"], 1)
        XCTAssertNil(e.recentUse()["a"])
        XCTAssertEqual(ids(e.accountsByUse), ["b", "a"])
    }

    func testMovementWithoutAccountCountsForTheFirstOne() {
        let e = engine(accounts: [acc("a", "A", balance: 1), acc("b", "B", balance: 1)], cards: [], txs: [tx("2026-10-30", nil), tx("2026-10-31", nil)])
        XCTAssertEqual(e.recentUse()["a"], 2)
    }

    func testCardsAndAccountsCanBeMixedByUse() {
        let e = engine(accounts: [acc("a", "A", balance: 1)], cards: [card("k", "K", balance: 10, limit: 100)],
                       txs: [tx("2026-10-30", "k"), tx("2026-10-29", "k"), tx("2026-10-28", "a")])
        XCTAssertEqual(ids(e.accountsAndCardsByUse), ["k", "a"])
        XCTAssertEqual(ids(e.accountsByUse), ["a"])
        XCTAssertEqual(ids(e.cardsByUse), ["k"])
    }

    func testDebitShowsBalanceInItsOwnCurrency() {
        let e = engine(accounts: [acc("a", "QuickSilverOne", balance: 1240.4, last4: "9695"), acc("p", "Sueldo", cur: "PEN", balance: 3500)], cards: [], txs: [])
        XCTAssertEqual(e.menuLabel(e.allAccounts[0], available: "disponible", owed: "pendiente"), "QuickSilverOne · ● 9695 · $1,240")
        XCTAssertEqual(e.menuLabel(e.allAccounts[1], available: "disponible", owed: "pendiente"), "Sueldo · S/\u{00A0}3,500")
    }

    func testNegativeBalanceKeepsItsSign() {
        let e = engine(accounts: [acc("a", "A", balance: -50)], cards: [], txs: [])
        XCTAssertEqual(e.menuLabel(e.allAccounts[0], available: "disponible", owed: "pendiente"), "A · −$50")
    }

    func testCreditShowsWhatIsAvailable() {
        let e = engine(accounts: [acc("a", "A", balance: 1)], cards: [card("k", "Apple Card", balance: 640, limit: 1500, last4: "7203")], txs: [])
        XCTAssertEqual(e.menuLabel(e.allCards[0], available: "disponible", owed: "pendiente"), "Apple Card · ● 7203 · $860 disponible")
    }

    func testCreditOverTheLimitShowsZeroAvailable() {
        let e = engine(accounts: [acc("a", "A", balance: 1)], cards: [card("k", "K", balance: 1700, limit: 1500)], txs: [])
        XCTAssertEqual(e.menuLabel(e.allCards[0], available: "disponible", owed: "pendiente"), "K · $0 disponible")
    }

    func testLoanAndCardWithoutLimitShowWhatIsOwed() {
        let e = engine(accounts: [acc("a", "A", balance: 1)],
                       cards: [card("l", "Préstamo", kind: "loan", balance: 500, limit: 0), card("k", "Sin límite", balance: 120, limit: 0)], txs: [])
        XCTAssertEqual(e.menuLabel(e.allCards[0], available: "disponible", owed: "pendiente"), "Préstamo · $500 pendiente")
        XCTAssertEqual(e.menuLabel(e.allCards[1], available: "disponible", owed: "pendiente"), "Sin límite · $120 pendiente")
    }

    func testTranslatedWordsAreUsed() {
        let e = engine(accounts: [acc("a", "A", balance: 1)], cards: [card("k", "K", balance: 10, limit: 100)], txs: [])
        XCTAssertEqual(e.menuLabel(e.allCards[0], available: "available", owed: "owed"), "K · $90 available")
    }
}
