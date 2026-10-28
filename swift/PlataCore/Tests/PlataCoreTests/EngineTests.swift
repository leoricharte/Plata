import XCTest
@testable import PlataCore

final class EngineTests: XCTestCase {
    private func close(_ a: Double, _ b: Double, _ tol: Double = 1e-7) -> Bool {
        if a.isNaN && b.isNaN { return true }
        return abs(a - b) <= tol * max(1, abs(b))
    }

    private func engine(_ c: JSONValue) -> Engine {
        Engine(profile: Profile(raw: c["migrated"]!), today: LocalDate(iso: c["today"]!.stringValue!)!, variable: c["variable"]!.boolValue!)
    }

    func testLocalDateMatchesJSDates() {
        XCTAssertEqual(LocalDate(iso: "2026-10-28")!.iso, "2026-10-28")
        XCTAssertEqual(LocalDate(iso: "2026-10-28")!.weekday, 3)                       // miércoles
        XCTAssertEqual(LocalDate(year: 2026, month0: 12, day: 1).iso, "2027-01-01")    // el mes 12 desborda al año siguiente
        XCTAssertEqual(LocalDate(year: 2026, month0: 2, day: 0).iso, "2026-02-28")     // día 0 = último del mes anterior
        XCTAssertEqual(LocalDate(year: 2026, month0: -1, day: 15).iso, "2025-12-15")
        XCTAssertEqual(LocalDate.daysInMonth(year: 2028, month0: 1), 29)
        XCTAssertEqual(LocalDate(iso: "2026-01-31")!.adding(days: 1).iso, "2026-02-01")
        XCTAssertEqual(LocalDate(iso: "1970-01-01")!.days, 0)
    }

    func testCalcMatchesWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let w = c["calc"]!
            let got = engine(c).calc()
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            XCTAssertEqual(got.mk, w["mk"]!.stringValue, tag)
            XCTAssertEqual(got.dim, w["dim"]!.intValue, tag)
            XCTAssertEqual(got.incomeCount, w["incomeCount"]!.intValue, tag)
            for k in ["income", "expense", "balance", "debt", "interest", "saved", "savedMonthly", "budgetTotal", "subsTotal", "expV", "subSpent"] {
                let g: Double
                switch k {
                case "income": g = got.income
                case "expense": g = got.expense
                case "balance": g = got.balance
                case "debt": g = got.debt
                case "interest": g = got.interest
                case "saved": g = got.saved
                case "savedMonthly": g = got.savedMonthly
                case "budgetTotal": g = got.budgetTotal
                case "subsTotal": g = got.subsTotal
                case "expV": g = got.expV
                default: g = got.subSpent
                }
                XCTAssertTrue(close(g, w[k]!.doubleValue!), "\(tag): \(k) \(g) ≠ \(w[k]!.doubleValue!)")
            }
            XCTAssertTrue(close(got.subHist, w["subHist"]!.doubleValue!), "\(tag): subHist")
            XCTAssertEqual(got.txIds, w["txIds"]!.arrayValue!.map { $0.stringValue! }, "\(tag): orden de movimientos")
            XCTAssertEqual(got.monthTxIds, w["monthTxIds"]!.arrayValue!.map { $0.stringValue! }, "\(tag): movimientos del mes")

            let wc = w["cats"]!.arrayValue!
            XCTAssertEqual(got.cats.count, wc.count, "\(tag): categorías")
            for (a, b) in zip(got.cats, wc) {
                XCTAssertEqual(a.name, b["name"]!.stringValue, tag)
                XCTAssertEqual(a.color, b["color"]!.stringValue, tag)
                XCTAssertTrue(close(a.v, b["v"]!.doubleValue!), "\(tag): \(a.name)")
            }
            let wt = w["catTot"]!.objectValue!
            XCTAssertEqual(Set(got.catTot.keys), Set(wt.keys), "\(tag): claves de catTot")
            for (k, v) in wt { XCTAssertTrue(close(got.catTot[k] ?? .nan, v.doubleValue!), "\(tag): catTot \(k)") }

            let wm = w["months"]!.arrayValue!
            XCTAssertEqual(got.months.count, wm.count, "\(tag): meses")
            for (a, b) in zip(got.months, wm) {
                XCTAssertEqual(a.label, b["label"]!.stringValue, tag)
                XCTAssertEqual(a.cur, b["cur"]!.boolValue, tag)
                XCTAssertTrue(close(a.income, b["income"]?.doubleValue ?? 0) && close(a.expense, b["expense"]?.doubleValue ?? 0), "\(tag): barras")
            }
            let wk = w["cards"]!.arrayValue!
            XCTAssertEqual(got.cards.count, wk.count, tag)
            for (a, b) in zip(got.cards, wk) {
                XCTAssertEqual(a.id, b["id"]!.stringValue, tag)
                XCTAssertEqual(a.color, b["color"]!.stringValue, tag)
                XCTAssertTrue(close(a.ub, b["ub"]!.doubleValue!) && close(a.util, b["util"]!.doubleValue!) && close(a.interest, b["interest"]!.doubleValue!), "\(tag): tarjeta \(a.id)")
            }
            let ws = w["savings"]!.arrayValue!
            XCTAssertEqual(got.savings.count, ws.count, tag)
            for (a, b) in zip(got.savings, ws) {
                XCTAssertEqual(a.id, b["id"]!.stringValue, tag)
                XCTAssertEqual(a.color, b["color"]!.stringValue, tag)
                XCTAssertTrue(close(a.ub, b["ub"]!.doubleValue!), "\(tag): meta \(a.id)")
            }
        }
    }

    func testEventsMatchWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c)
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            let want = c["events"]!.arrayValue!
            let got = e.genEvents()
            XCTAssertEqual(got.count, want.count, "\(tag): cantidad de eventos")
            for (n, (a, b)) in zip(got, want).enumerated() {
                let t = "\(tag) evento \(n)"
                XCTAssertEqual(a.date.iso, b["date"]!.stringValue, t)
                XCTAssertEqual(a.name, b["name"]!.stringValue, t)
                XCTAssertEqual(a.type, b["type"]!.stringValue, t)
                XCTAssertEqual(a.key, b["key"]!.stringValue, t)
                XCTAssertEqual(a.pending, b["pending"]!.boolValue, t)
                XCTAssertEqual(a.skipped, b["skipped"]!.boolValue, t)
                XCTAssertEqual(a.edited, b["edited"]!.boolValue, t)
                XCTAssertTrue(close(a.amt, b["amt"]!.doubleValue!), "\(t): monto \(a.amt) ≠ \(b["amt"]!.doubleValue!)")
            }
            let skipped = e.genEvents(keepSkipped: true).filter { $0.skipped }
            let wantSkipped = c["keepSkipped"]!.arrayValue!
            XCTAssertEqual(skipped.map { $0.key ?? "" }, wantSkipped.map { $0["key"]?.stringValue ?? "" }, "\(tag): omitidos")
            let ns = e.genEvents(noSim: true)
            XCTAssertEqual(ns.count, c["noSim"]!["count"]!.intValue, "\(tag): sin simulaciones")
            XCTAssertTrue(close(ns.reduce(0) { $0 + $1.amt }, c["noSim"]!["sum"]!.doubleValue!), "\(tag): suma sin simulaciones")
        }
    }

    func testProjectionAndDailyMatchWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c)
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            let w = c["projection"]!
            let p = e.projection()
            XCTAssertTrue(close(p.V, w["V"]!.doubleValue!), "\(tag): V")
            XCTAssertTrue(close(p.minV, w["minV"]!.doubleValue!), "\(tag): minV")
            XCTAssertEqual(p.firstRed ?? -1, w["firstRed"]!.intValue, "\(tag): primera semana en rojo")
            let ws = w["series"]!.arrayValue!
            XCTAssertEqual(p.series.count, ws.count, tag)
            for (a, b) in zip(p.series, ws) {
                XCTAssertEqual(a.date.iso, b["date"]!.stringValue, tag)
                XCTAssertTrue(close(a.v, b["v"]!.doubleValue!), "\(tag): serie \(a.date.iso)")
            }
            let wt = w["timeline"]!.arrayValue!
            XCTAssertEqual(p.timeline.count, wt.count, "\(tag): línea de tiempo")
            for (a, b) in zip(p.timeline, wt) {
                XCTAssertEqual(a.name, b["name"]!.stringValue, tag)
                XCTAssertEqual(a.date, b["date"]!.stringValue, tag)
                XCTAssertEqual(a.type, b["type"]!.stringValue, tag)
                XCTAssertEqual(a.key, b["key"]!.stringValue, tag)
                XCTAssertEqual(a.edited, b["edited"]!.boolValue, tag)
                XCTAssertEqual(a.skipped, b["skipped"]!.boolValue, tag)
                XCTAssertTrue(close(a.amt, b["amt"]!.doubleValue!) && close(a.after, b["after"]!.doubleValue!), "\(tag): \(a.name)")
            }
            let wd = c["daily"]!.arrayValue!
            let d = e.dailySeries()
            XCTAssertEqual(d.count, wd.count, "\(tag): días")
            for (n, (a, b)) in zip(d, wd).enumerated() { XCTAssertTrue(close(a.v, b.doubleValue!), "\(tag): día \(n)") }
        }
    }

    func testSimImpactMatchesWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c)
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            for p in c["migrated"]!["planned"]?.arrayValue ?? [] {
                let id = JS.string(p["id"]!)
                let want = c["simImpact"]![id]!
                let got = e.simImpact(p)
                if want.isNull { XCTAssertNil(got, "\(tag) \(id)"); continue }
                guard let got else { XCTFail("\(tag) \(id): la web da impacto y Swift no"); continue }
                XCTAssertEqual(got.start, want["start"]!.stringValue, "\(tag) \(id)")
                XCTAssertEqual(got.end, want["end"]!.stringValue, "\(tag) \(id)")
                XCTAssertEqual(got.status, want["status"]!.stringValue, "\(tag) \(id)")
                XCTAssertEqual(got.withDate.iso, want["withDate"]!.stringValue, "\(tag) \(id)")
                XCTAssertTrue(close(got.withMin, want["withMin"]!.doubleValue!) && close(got.withoutMin, want["withoutMin"]!.doubleValue!), "\(tag) \(id)")
            }
        }
    }

    func testPayoffMatchesWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c)
            for (key, want) in c["payoff"]!.objectValue! {
                let parts = key.split(separator: "|").map(String.init)
                let kind: String? = parts[0] == "undefined" ? nil : parts[0]
                let got = e.payoff(extra: Double(parts[1])!, kind: kind)
                XCTAssertEqual(got.months, want["months"]!.intValue, "caso \(i) \(key)")
                XCTAssertEqual(got.ok, want["ok"]!.boolValue, "caso \(i) \(key)")
                XCTAssertTrue(close(got.interest, want["interest"]!.doubleValue!), "caso \(i) \(key): interés \(got.interest) ≠ \(want["interest"]!.doubleValue!)")
            }
        }
    }

    func testPendingAndNextIncomeMatchWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c)
            let tag = "caso \(i)"
            let want = c["pending"]!.arrayValue!
            let got = e.pendingItems()
            XCTAssertEqual(got.map { $0.date }, want.map { $0["date"]!.stringValue! }, "\(tag): fechas pendientes")
            // Con la misma fecha, la web no garantiza el orden: se compara el conjunto.
            XCTAssertEqual(Set(got.map { "\($0.kind)|\($0.id)" }), Set(want.map { "\($0["k"]!.stringValue!)|\(JS.string($0["id"]!))" }), "\(tag): pendientes")
            let ni = e.nextIncome()
            let wn = c["nextIncome"]!
            if wn.isNull { XCTAssertNil(ni, tag) } else {
                XCTAssertEqual(ni?.id, JS.string(wn["id"]!), tag)
                XCTAssertEqual(ni?.date, wn["date"]!.stringValue, tag)
                XCTAssertTrue(close(ni?.amount ?? .nan, wn["amount"]!.doubleValue!), tag)
            }
        }
    }
}
