import XCTest
@testable import PlataCore

final class NazcaExampleTests: XCTestCase {
    typealias B = NazcaExample.Box
    let today = "2026-10-30"

    func testMoney() {
        XCTAssertEqual(NazcaExample.parseMoney("S/ 25.50")?.value, 25.5)
        XCTAssertEqual(NazcaExample.parseMoney("- S/ 1,234.50")?.marker, -1)
        XCTAssertEqual(NazcaExample.parseMoney("+$12.00")?.marker, 1)
        XCTAssertEqual(NazcaExample.parseMoney("1.234,50")?.value, 1234.5)
        XCTAssertEqual(NazcaExample.parseMoney("1.234")?.value, 1234)
        XCTAssertEqual(NazcaExample.parseMoney("25,5")?.value, 25.5)
        XCTAssertNil(NazcaExample.parseMoney("Pago de luz"))
        XCTAssertNil(NazcaExample.parseMoney("12 oct"))
    }

    func testDates() {
        XCTAssertEqual(NazcaExample.parseDate("12/10/2026", today: today), "2026-10-12")
        XCTAssertEqual(NazcaExample.parseDate("12 oct", today: today), "2026-10-12")
        XCTAssertEqual(NazcaExample.parseDate("12 de octubre de 2025", today: today), "2025-10-12")
        XCTAssertEqual(NazcaExample.parseDate("Oct 12", today: today), "2026-10-12")
        XCTAssertEqual(NazcaExample.parseDate("Hoy", today: today), today)
        XCTAssertEqual(NazcaExample.parseDate("Ayer", today: today), "2026-10-29")
        XCTAssertEqual(NazcaExample.parseDate("20 dic", today: today), "2025-12-20")
        XCTAssertNil(NazcaExample.parseDate("Netflix", today: today))
    }

    /// Una app con la fecha como encabezado y el monto a la derecha, con el signo en el texto.
    func headerLayout() -> [B] {
        func row(_ y: Double, _ d: String, _ a: String) -> [B] {
            [B(text: d, x: 0.08, y: y, w: 0.4, h: 0.02), B(text: a, x: 0.7, y: y, w: 0.22, h: 0.02)]
        }
        return [B(text: "12 oct", x: 0.05, y: 0.10, w: 0.15, h: 0.02)]
            + row(0.15, "Netflix", "- S/ 44.90")
            + row(0.20, "Sueldo", "+ S/ 3,000.00")
            + [B(text: "11 oct", x: 0.05, y: 0.27, w: 0.15, h: 0.02)]
            + row(0.32, "Bodega Lupe", "- S/ 18.00")
            + row(0.37, "Uber", "- S/ 9.50")
    }

    func testHeaderLayout() throws {
        let ex = [
            NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
            NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11"),
        ]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        XCTAssertEqual(t.dateMode, .header)
        let x = NazcaExample.extract(t, boxes: headerLayout(), today: today)
        XCTAssertEqual(x.items.count, 4)
        XCTAssertEqual(x.items.map(\.amount), [-44.9, 3000, -18, -9.5])
        XCTAssertEqual(x.items.map(\.date), ["2026-10-12", "2026-10-12", "2026-10-11", "2026-10-11"])
        XCTAssertEqual(x.items[1].desc, "Sueldo")
        XCTAssertTrue(x.flags.isEmpty)
    }

    /// Descripción arriba, fecha debajo y el signo por color.
    func testToneAndTwoLines() throws {
        func row(_ y: Double, _ d: String, _ date: String, _ a: String, _ tone: Int) -> [B] {
            [B(text: d, x: 0.08, y: y, w: 0.4, h: 0.02), B(text: date, x: 0.08, y: y + 0.03, w: 0.2, h: 0.015),
             B(text: a, x: 0.72, y: y, w: 0.2, h: 0.02, tone: tone)]
        }
        let boxes = row(0.1, "Starbucks", "3 oct", "S/ 15.00", -1) + row(0.2, "Pago recibido", "2 oct", "S/ 200.00", 1) + row(0.3, "Farmacia", "1 oct", "S/ 32.00", -1)
        let ex = [NazcaExample.Example(desc: "Starbucks", amount: -15, date: "2026-10-03"),
                  NazcaExample.Example(desc: "Pago recibido", amount: 200, date: "2026-10-02")]
        let t = try NazcaExample.learn(examples: ex, boxes: boxes, today: today).get()
        XCTAssertEqual(t.signMode, .tone(expense: -1, income: 1))
        XCTAssertEqual(t.dateMode, .row(1))
        let x = NazcaExample.extract(t, boxes: boxes, today: today)
        XCTAssertEqual(x.items.count, 3)
        XCTAssertEqual(x.items[2].amount, -32)
        XCTAssertEqual(x.items[2].date, "2026-10-01")
    }

    func testNotFound() {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Nada que ver", amount: -999, date: "2026-10-11")]
        XCTAssertEqual({ () -> NazcaExample.LearnError? in
            if case .failure(let e) = NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today) { return e }
            return nil
        }(), .notFound(1))
    }

    func testTemplateHasNoUserData() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        let json = String(data: try JSONEncoder().encode(t), encoding: .utf8) ?? ""
        for s in ["Netflix", "Bodega", "44.9", "2026"] { XCTAssertFalse(json.contains(s)) }
    }
}
