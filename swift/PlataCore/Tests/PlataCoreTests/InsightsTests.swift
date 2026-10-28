import XCTest
@testable import PlataCore

final class InsightsTests: XCTestCase {
    private func close(_ a: Double, _ b: Double, _ tol: Double = 1e-7) -> Bool { abs(a - b) <= tol * max(1, abs(b)) }

    private func engine(_ c: JSONValue) -> Engine {
        var raw = c["migrated"]!
        raw["subHist"] = c["ins"]!["subHist"]
        return Engine(profile: Profile(raw: raw), today: LocalDate(iso: c["today"]!.stringValue!)!, variable: c["variable"]!.boolValue!)
    }

    private func level(_ v: JSONValue) -> StreakLevel {
        if v == .string("d") { return .diamond }
        return v == .bool(true) ? .plus : .none
    }

    private func check(_ m: InsightsModel, _ w: JSONValue, _ tag: String) {
        XCTAssertEqual(m.mk, w["mk"]!.stringValue, tag)
        XCTAssertEqual(m.pmk, w["pmk"]!.stringValue, tag)
        XCTAssertEqual(m.isCur, w["isCur"]!.boolValue, tag)
        XCTAssertEqual(m.day, w["day"]!.intValue, "\(tag): día")
        XCTAssertEqual(m.dim, w["dim"]!.intValue, tag)
        XCTAssertEqual(m.est, w["est"]!.boolValue, "\(tag): estimado")
        XCTAssertEqual(m.hasPrev, w["hasPrev"]!.boolValue, tag)
        XCTAssertEqual(m.within, w["within"]!.intValue, "\(tag): topes respetados")
        XCTAssertEqual(m.limCount, w["lim"]!.intValue, tag)
        XCTAssertEqual(m.contrib, w["contrib"]!.boolValue, tag)
        XCTAssertEqual(m.score, w["score"]!.intValue, "\(tag): nota")
        XCTAssertEqual(m.letter, w["letter"]!.stringValue, "\(tag): letra")
        XCTAssertEqual(m.streak, w["streak"]!.intValue, "\(tag): racha")
        XCTAssertEqual(m.plus, level(w["plus"]!), "\(tag): nivel de racha")
        XCTAssertTrue(close(m.delta, w["delta"]!.doubleValue!), "\(tag): delta")
        for (name, got, want) in [("ps", m.ps, w["ps"]), ("rateC", m.rateC, w["rateC"]), ("rateP", m.rateP, w["rateP"])] {
            if let v = want?.doubleValue, let g = got { XCTAssertTrue(close(g, v), "\(tag): \(name)") }
            else { XCTAssertEqual(got == nil, want?.isNull ?? true, "\(tag): \(name) nulo") }
        }
        for (name, got, want) in [("cur", m.cur, w["cur"]!), ("prev", m.prev, w["prev"]!)] {
            XCTAssertEqual(got.n, want["n"]!.intValue, "\(tag): \(name).n")
            for (k, g) in [("inc", got.inc), ("exp", got.exp), ("expV", got.expV), ("sub", got.sub)] {
                XCTAssertTrue(close(g, want[k]!.doubleValue!), "\(tag): \(name).\(k) \(g) ≠ \(want[k]!.doubleValue!)")
            }
            let wc = want["cat"]!.objectValue!
            XCTAssertEqual(Set(got.cat.keys), Set(wc.keys), "\(tag): \(name).cat")
            for (k, v) in wc { XCTAssertTrue(close(got.cat[k] ?? .nan, v.doubleValue!), "\(tag): \(name).cat.\(k)") }
        }
        if let ws = w["sg"], !ws.isNull {
            guard let sg = m.sg else { XCTFail("\(tag): la web da crecimiento de suscripciones y Swift no"); return }
            XCTAssertEqual(sg.n, ws["n"]!.intValue, tag)
            for (k, g) in [("cur", sg.cur), ("base", sg.base), ("d", sg.d), ("pct", sg.pct), ("pts", sg.pts)] {
                XCTAssertTrue(close(g, ws[k]!.doubleValue!), "\(tag): sg.\(k)")
            }
        } else {
            XCTAssertNil(m.sg, "\(tag): sg")
        }
    }

    func testScoresAndModelsMatchWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let e = engine(c), ins = c["ins"]!
            let tag = "caso \(i) (\(c["today"]!.stringValue!))"
            check(e.insightsModel(), ins["model"]!, tag + " modelo")
            check(e.insightsModel(month: ins["mks"]!.arrayValue![1].stringValue!), ins["prev"]!, tag + " mes anterior")
            check(e.insightsModel(upTo: 15), ins["half"]!, tag + " half-time")
            for (mk, want) in ins["scores"]!.objectValue! {
                let got = e.monthScore(mk)
                if want.isNull { XCTAssertNil(got, "\(tag) nota de \(mk)"); continue }
                guard let got else { XCTFail("\(tag) nota de \(mk): la web la da y Swift no"); continue }
                XCTAssertEqual(got.score, want["score"]!.intValue, "\(tag) \(mk)")
                XCTAssertEqual(got.letter, want["letter"]!.stringValue, "\(tag) \(mk)")
                XCTAssertEqual(got.streak, want["streak"]!.intValue, "\(tag) \(mk)")
                XCTAssertEqual(got.plus, level(want["plus"]!), "\(tag) \(mk)")
            }
            XCTAssertEqual(e.insightsLocked(e.insightsModel()), ins["locked"]!.stringValue, "\(tag): bloqueo")
            XCTAssertEqual(e.insightsLocked(e.insightsModel(month: ins["mks"]!.arrayValue![1].stringValue!)), ins["lockedPrev"]!.stringValue, "\(tag): bloqueo anterior")
            XCTAssertEqual(e.insightsLocked(e.insightsModel(upTo: 15)), ins["lockedHalf"]!.stringValue, "\(tag): bloqueo half-time")
        }
    }

    func testGoalsAndDebtMatchWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let ins = c["ins"]!
            for sv in c["migrated"]!["savings"]!.arrayValue! {
                let want = ins["svGoal"]![JS.string(sv["id"]!)]!
                let got = Engine.savingGoal(sv)
                XCTAssertTrue(close(got.goal, want["goal"]!.doubleValue!) && close(got.rem, want["rem"]!.doubleValue!) && close(got.pct, want["pct"]!.doubleValue!), "caso \(i): meta")
                XCTAssertEqual(got.done, want["done"]!.boolValue, "caso \(i)")
                XCTAssertEqual(got.mo, want["mo"]!.intValue, "caso \(i)")
            }
            let cards = c["migrated"]!["cards"]!.arrayValue!
            for (k, want) in ins["debtSim"]!.arrayValue!.enumerated() {
                let card = cards[k]
                let got = Engine.debtSim(balance: Engine.num(card["balance"]), apr: Engine.num(card["apr"]), payment: Engine.num(card["payment"]))
                if want["r"]!.isNull { XCTAssertNil(got, "caso \(i) deuda \(k)"); continue }
                XCTAssertEqual(got?.months, want["r"]!["months"]!.intValue, "caso \(i) deuda \(k)")
                XCTAssertTrue(close(got?.interest ?? .nan, want["r"]!["interest"]!.doubleValue!), "caso \(i) deuda \(k): interés")
            }
        }
    }
}
