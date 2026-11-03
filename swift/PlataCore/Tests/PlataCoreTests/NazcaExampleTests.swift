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

    /// Con uno de los dos fuera de la captura, Nazca aprende con el otro y lo marca como parcial.
    func testOneMissingIsPartial() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Nada que ver", amount: -999, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        XCTAssertEqual(t.partial, true)
    }

    func testTemplateHasNoUserData() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        let json = String(data: try JSONEncoder().encode(t), encoding: .utf8) ?? ""
        for s in ["Netflix", "Bodega", "44.9", "2026"] { XCTAssertFalse(json.contains(s)) }
    }

    func testSavedTemplateReadsAnotherCapture() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        var saved = NazcaTemplates.remember(t, into: [])
        saved = NazcaTemplates.remember(t, into: saved)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].uses, 2)
        let hit = NazcaTemplates.best(saved, boxes: headerLayout(), today: today)
        XCTAssertEqual(hit?.extraction.items.count, 4)
        XCTAssertNil(NazcaTemplates.best(saved, boxes: [B(text: "hola", x: 0.1, y: 0.1, w: 0.2, h: 0.02)], today: today))
    }

    func testSharePayloadIsClosedAndOff() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        let p = NazcaShare.payload(t, bank: "Mi Banco Secreto")
        XCTAssertEqual(p.bank, "otro")
        XCTAssertEqual(NazcaShare.payload(t, bank: "BCP").bank, "bcp")
        XCTAssertEqual(p.dateMode, "header")
        let json = String(data: try JSONEncoder().encode(p), encoding: .utf8) ?? ""
        for s in ["Netflix", "Bodega", "Secreto", "44.9"] { XCTAssertFalse(json.contains(s)) }
        XCTAssertFalse(NazcaShare.enabled)
    }

    func testInstitutionNamesAccountWithoutBankSeal() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        let x = NazcaExample.extract(t, boxes: headerLayout(), today: today)
        let st = NazcaExample.statement(x, institution: "bcp")
        XCTAssertNil(st.bank)
        XCTAssertEqual(st.name, "BCP")
        XCTAssertNil(NazcaExample.statement(x).bank)
        XCTAssertEqual(NazcaExample.statement(x).name, "")
    }

    // MARK: captura de Interbank, «Mi Cuenta» (plantilla verificada)

    /// Una captura de «Mi Cuenta» de una cuenta simple en soles, con nombres y montos inventados: descripción arriba, fecha y hora debajo,
    /// el monto a la derecha entre las dos líneas, los gastos con «-» en negro y los abonos sin signo en verde. Las posiciones siguen la captura real.
    func miCuentaBoxes() -> [B] {
        let w = 471.0, h = 1020.0
        func b(_ t: String, _ x: Double, _ cy: Double, _ bw: Double, _ bh: Double, _ tone: Int = 0) -> B {
            B(text: t, x: x / w, y: (cy - bh / 2) / h, w: bw / w, h: bh / h, tone: tone)
        }
        var out = [b("Mi Cuenta", 184, 91, 106, 22), b("Cuenta Simple Soles", 90, 167, 180, 18), b("S/ 3.57", 38, 251, 60, 17), b("Saldo disponible", 38, 275, 112, 15),
                   b("Movimientos", 52, 342, 98, 17), b("Movimientos alcancía", 252, 342, 180, 17)]
        let rows: [(String, String, String, Int, Double)] = [
            ("Plin-ana ru", "Lun 02 Nov | 10:01 pm", "S/ -20.00", 0, 394), ("Io*mercado", "Dom 01 Nov | 2:21 pm", "S/ -682.72", 0, 468),
            ("Dale-k21 sa", "Dom 01 Nov | 2:16 pm", "S/ 35.00", 1, 541), ("Dale-k21 sa", "Dom 01 Nov | 2:11 pm", "S/ 70.00", 1, 615),
            ("Dale-k21 sa", "Dom 01 Nov | 1:41 pm", "S/ 300.01", 1, 688), ("Dale-k21 sa", "Dom 01 Nov | 1:41 pm", "S/ 300.00", 1, 762),
            ("Plin-ana ru", "Jue 29 Oct | 11:15 pm", "S/ -1.00", 0, 835), ("Io*mercado", "Vie 02 Oct | 12:17 am", "S/ -45.00", 0, 908)]
        for (d, f, a, tone, cy) in rows {
            let aw = max(60.0, Double(a.count) * 8.4)
            out += [b(d, 38, cy, Double(d.count) * 8.2, 16), b(f, 38, cy + 24, Double(f.count) * 7.2, 14), b(a, 414 - aw, cy + 13, aw, 16, tone)]
        }
        return out
    }

    private let miCuentaToday = "2026-11-02"
    private let miCuentaWant: [(String, Double, String)] = [
        ("2026-11-02", -20, "Plin-ana ru"), ("2026-11-01", -682.72, "Io*mercado"), ("2026-11-01", 35, "Dale-k21 sa"), ("2026-11-01", 70, "Dale-k21 sa"),
        ("2026-11-01", 300.01, "Dale-k21 sa"), ("2026-11-01", 300, "Dale-k21 sa"), ("2026-10-29", -1, "Plin-ana ru"), ("2026-10-02", -45, "Io*mercado")]

    private func assertMiCuenta(_ x: NazcaExample.Extraction, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(x.items.count, miCuentaWant.count, file: file, line: line)
        XCTAssertTrue(x.flags.isEmpty, file: file, line: line)
        for (i, w) in miCuentaWant.enumerated() where i < x.items.count {
            XCTAssertEqual(x.items[i].date, w.0, "fecha de la fila \(i)", file: file, line: line)
            XCTAssertEqual(x.items[i].amount, w.1, accuracy: 0.005, "monto de la fila \(i)", file: file, line: line)
            XCTAssertEqual(x.items[i].desc, w.2, "descripción de la fila \(i)", file: file, line: line)
        }
    }

    func testMiCuentaFormats() {
        for (s, want) in [("Lun 02 Nov | 10:01 pm", "2026-11-02"), ("Dom 01 Nov | 2:21 pm", "2026-11-01"), ("Jue 29 Oct | 11:15 pm", "2026-10-29"), ("Vie 02 Oct | 12:17 am", "2026-10-02")] {
            XCTAssertEqual(NazcaExample.parseDate(s, today: miCuentaToday), want, s)
        }
        XCTAssertEqual(NazcaExample.parseMoney("S/ -20.00")?.value, 20)
        XCTAssertEqual(NazcaExample.parseMoney("S/ -20.00")?.marker, -1)
        XCTAssertEqual(NazcaExample.parseMoney("S/ 35.00")?.marker, 0)
    }

    func testMiCuentaIsLearnedFromTwoMovements() throws {
        let ex = [NazcaExample.Example(desc: "Plin-ana ru", amount: -20, date: "2026-11-02"), NazcaExample.Example(desc: "Io*mercado", amount: -682.72, date: "2026-11-01")]
        let t = try NazcaExample.learn(examples: ex, boxes: miCuentaBoxes(), today: miCuentaToday).get()
        XCTAssertTrue(t.rightAligned)
        XCTAssertEqual(t.descDy, -1)
        XCTAssertEqual(t.dateMode, .row(1))
        XCTAssertEqual(t.signMode, .marker(noMarker: 1))
        assertMiCuenta(NazcaExample.extract(t, boxes: miCuentaBoxes(), today: miCuentaToday))
        // la plantilla guardada es «la misma captura» que la verificada
        XCTAssertTrue(NazcaTemplates.similar(t, NazcaTemplates.verified[0].template))
    }

    func testVerifiedMiCuentaCapture() throws {
        // sin dar ningún ejemplo: la plantilla verificada lee la captura completa, sin tomar el saldo ni los encabezados por movimientos
        let hit = try XCTUnwrap(NazcaTemplates.best(NazcaTemplates.verified, boxes: miCuentaBoxes(), today: miCuentaToday))
        XCTAssertEqual(hit.index, 0)
        assertMiCuenta(hit.extraction)
        // la plantilla es de Interbank: nombra la cuenta, pero sin el sello de banco verificado (eso es solo de los lectores oficiales)
        XCTAssertEqual(NazcaTemplates.verified[0].bank, "interbank")
        let st = NazcaExample.statement(hit.extraction, institution: NazcaTemplates.verified[0].bank)
        XCTAssertEqual(st.name, "Interbank")
        XCTAssertNil(st.bank)
        XCTAssertEqual(st.kind, "corriente")
        // y no inventa movimientos en una captura con otra forma
        XCTAssertNil(NazcaTemplates.best(NazcaTemplates.verified, boxes: headerLayout(), today: today))
    }

    func testVerifiedTemplatesHoldNoUserData() throws {
        let json = String(data: try JSONEncoder().encode(NazcaTemplates.verified), encoding: .utf8) ?? ""
        for s in ["Plin", "Io*", "Dale", "898", "2026", "S/"] { XCTAssertFalse(json.contains(s), s) }
    }

    func testSavedTemplateRemembersBank() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        var saved = NazcaTemplates.remember(t, into: [], bank: "bcp")
        XCTAssertEqual(saved[0].bank, "bcp")
        saved = NazcaTemplates.remember(t, into: saved)
        XCTAssertEqual(saved[0].bank, "bcp")
        let back = try JSONDecoder().decode([NazcaTemplates.Saved].self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(back, saved)
        XCTAssertEqual(NazcaTemplates.verified.count, 1)   // «Mi Cuenta» (ver testVerifiedMiCuentaCapture)
        XCTAssertEqual(NazcaShare.payload(t, bank: "bcp").status, "pending")
    }

    func testSoftMatchByAmountAndDate() throws {
        // el usuario escribe otro nombre para el primer movimiento: se encuentra por monto y fecha
        let ex = [NazcaExample.Example(desc: "Suscripción de video", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        XCTAssertEqual(t.soft, 1)
        XCTAssertEqual(t.dateMode, .header)
        XCTAssertEqual(NazcaExample.extract(t, boxes: headerLayout(), today: today).items.count, 4)
        // si falta uno aprende con el otro (parcial); si faltan los dos, no hay de dónde aprender
        let none = [NazcaExample.Example(desc: "Nada", amount: -999, date: "2026-10-12"), NazcaExample.Example(desc: "Tampoco", amount: -998, date: "2026-10-11")]
        var err: NazcaExample.LearnError?
        if case .failure(let e) = NazcaExample.learn(examples: none, boxes: headerLayout(), today: today) { err = e }
        XCTAssertEqual(err, .notFound(0))
    }

    func testCardInstitutionMakesCardStatement() throws {
        let ex = [NazcaExample.Example(desc: "Netflix", amount: -44.9, date: "2026-10-12"),
                  NazcaExample.Example(desc: "Bodega Lupe", amount: -18, date: "2026-10-11")]
        let t = try NazcaExample.learn(examples: ex, boxes: headerLayout(), today: today).get()
        let x = NazcaExample.extract(t, boxes: headerLayout(), today: today)
        XCTAssertEqual(NazcaExample.statement(x, institution: "applecard").kind, "tarjeta")
        XCTAssertEqual(NazcaExample.statement(x, institution: "bcp").kind, "corriente")
        XCTAssertEqual(NazcaExample.statement(x).kind, "corriente")
    }

    func testCaptureDuplicatesIncludeImported() {
        let items = [Nazca.Item(line: 1, date: "2026-10-12", desc: "Netflix", amount: -44.9)]
        let have = [Nazca.Known(acc: "a", date: "2026-10-12", amount: -44.9, note: "NETFLIX.COM", imp: "abc")]
        XCTAssertEqual(Nazca.markDuplicates(items, existing: have, acc: "a")[0].dup, .none)
        XCTAssertEqual(Nazca.markDuplicates(items, existing: have, acc: "a", includeImported: true)[0].dup, .near)
        XCTAssertEqual(Nazca.markDuplicates(items, existing: have, acc: "b", includeImported: true)[0].dup, .none)
    }

    func testOrdinalDates() {
        XCTAssertEqual(NazcaExample.parseDate("Friday, October 23rd", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("Wednesday, October 21st", today: today), "2026-10-21")
        XCTAssertEqual(NazcaExample.parseDate("Thursday, October 22nd", today: today), "2026-10-22")
        XCTAssertEqual(NazcaExample.parseDate("Saturday, October 24th", today: today), "2026-10-24")
        XCTAssertEqual(NazcaExample.parseDate("3rd March 2026", today: today), "2026-03-03")
        XCTAssertNil(NazcaExample.parseDate("4:42 PM • Deposit", today: today))
        XCTAssertNil(NazcaExample.parseDate("Gusto, Payroll", today: today))
    }

    /// Una app con la fecha en inglés como encabezado, y nombres que no coinciden con los que la persona tiene anotados.
    func testChimeStyleBothExamplesBySoftMatch() throws {
        func row(_ y: Double, _ d: String, _ a: String, _ sub: String) -> [B] {
            [B(text: d, x: 0.2, y: y, w: 0.4, h: 0.02), B(text: a, x: 0.72, y: y, w: 0.2, h: 0.02), B(text: sub, x: 0.2, y: y + 0.03, w: 0.3, h: 0.015)]
        }
        func head(_ y: Double, _ t: String) -> [B] { [B(text: t, x: 0.05, y: y, w: 0.3, h: 0.015)] }
        let boxes = head(0.10, "Saturday, October 24th") + head(0.16, "Friday, October 23rd")
            + row(0.22, "Gusto, Payroll", "+$229.80", "4:42 PM • Deposit")
            + head(0.30, "Thursday, October 22nd") + row(0.36, "Wsmg22 Allcmicar, Payroll", "+$420.32", "1:09 AM • Deposit")
            + head(0.44, "Wednesday, October 21st") + row(0.50, "MyPay repayment", "-$35.00", "12:47 AM • MyPay")
            + row(0.58, "Gusto, Payroll", "+$602.14", "12:47 AM • Deposit")
        let ex = [NazcaExample.Example(desc: "Bonus Generations", amount: 229.8, date: "2026-10-23"),
                  NazcaExample.Example(desc: "Generations", amount: 602.14, date: "2026-10-21")]
        let t = try NazcaExample.learn(examples: ex, boxes: boxes, today: today).get()
        XCTAssertEqual(t.soft, 2)
        XCTAssertEqual(t.dateMode, .header)
        let x = NazcaExample.extract(t, boxes: boxes, today: today)
        XCTAssertEqual(x.items.map(\.amount), [229.8, 420.32, -35, 602.14])
        XCTAssertEqual(x.items.map(\.date), ["2026-10-23", "2026-10-22", "2026-10-21", "2026-10-21"])
        XCTAssertEqual(x.items[0].desc, "Gusto, Payroll")
    }

    func testMoreMoneyShapes() {
        let p = NazcaExample.parseMoney("($229.80)")
        XCTAssertEqual(p?.value, 229.8)
        XCTAssertEqual(p?.marker, -1)
        let tail = NazcaExample.parseMoney("35.00-")
        XCTAssertEqual(tail?.value, 35)
        XCTAssertEqual(tail?.marker, -1)
        XCTAssertNil(NazcaExample.parseMoney("(3)"))
        XCTAssertNil(NazcaExample.parseMoney("-"))
        XCTAssertEqual(NazcaExample.parseMoney("229.80 USD")?.cur, "USD")
    }

    func testMoreDateShapes() {
        XCTAssertEqual(NazcaExample.parseDate("10/23", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("23/10", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("10/23/2026", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("Vie 23/10", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("5/11", today: today), "2026-05-11")
        XCTAssertEqual(NazcaExample.parseDate("23 de octubre", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("5 items 23 oct", today: today), "2026-10-23")
        XCTAssertEqual(NazcaExample.parseDate("Friday", today: today), "2026-10-30")
        XCTAssertEqual(NazcaExample.parseDate("Sábado", today: today), "2026-10-24")
        XCTAssertEqual(NazcaExample.parseDate("Mon.", today: today), "2026-10-26")
        XCTAssertNil(NazcaExample.parseDate("Sunday Bakery", today: today))
        XCTAssertNil(NazcaExample.parseDate("12.50", today: today))
    }

    /// Una fila sin fecha propia toma la del encabezado de arriba, aunque la plantilla buscara la fecha en la fila.
    func testRowDateFallsBackToHeader() {
        let t = NazcaExample.Template(amountX: 0.92, rightAligned: true, tol: 0.06, descDy: 0, descLeft: 0.05, dateMode: .row(-2),
                                      signMode: .marker(noMarker: 1), cur: "", confidence: 1)
        let boxes = [B(text: "Friday, October 23rd", x: 0.05, y: 0.10, w: 0.3, h: 0.015),
                     B(text: "Gusto", x: 0.05, y: 0.16, w: 0.2, h: 0.02), B(text: "+$229.80", x: 0.72, y: 0.16, w: 0.2, h: 0.02)]
        let x = NazcaExample.extract(t, boxes: boxes, today: today)
        XCTAssertEqual(x.items.first?.date, "2026-10-23")
    }

    /// Si uno de los dos ejemplos no aparece, se aprende con el otro, con menos confianza y marcado como parcial.
    func testLearnsFromOneWhenOtherMissing() throws {
        func row(_ y: Double, _ d: String, _ a: String) -> [B] {
            [B(text: d, x: 0.05, y: y, w: 0.4, h: 0.02), B(text: a, x: 0.72, y: y, w: 0.2, h: 0.02)]
        }
        let boxes = row(0.2, "Starbucks", "-$5.40") + row(0.3, "Uber", "-$12.00") + row(0.4, "Sueldo", "+$900.00")
        let ex = [NazcaExample.Example(desc: "Starbucks", amount: -5.4, date: ""),
                  NazcaExample.Example(desc: "No existe", amount: -777.77, date: "")]
        let t = try NazcaExample.learn(examples: ex, boxes: boxes, today: today).get()
        XCTAssertEqual(t.partial, true)
        XCTAssertLessThan(t.confidence, 0.6)
        let x = NazcaExample.extract(t, boxes: boxes, today: today)
        XCTAssertEqual(x.items.map(\.amount), [-5.4, -12, 900])
        let none = [NazcaExample.Example(desc: "A", amount: -1.11, date: ""), NazcaExample.Example(desc: "B", amount: -2.22, date: "")]
        var err: NazcaExample.LearnError?
        if case .failure(let e) = NazcaExample.learn(examples: none, boxes: boxes, today: today) { err = e }
        XCTAssertEqual(err, .notFound(0))
    }

    /// Encerrar una fila: aprende de esa y lee las demás. Encerrar varias: aprende de dos que se distingan. El encabezado de arriba da la fecha.
    func testRegionSelection() throws {
        func row(_ y: Double, _ d: String, _ a: String) -> [B] {
            [B(text: d, x: 0.05, y: y, w: 0.4, h: 0.02), B(text: a, x: 0.72, y: y, w: 0.2, h: 0.02)]
        }
        let boxes = [B(text: "Friday, October 23rd", x: 0.05, y: 0.10, w: 0.3, h: 0.015)]
            + row(0.20, "Gusto, Payroll", "+$229.80") + row(0.30, "Starbucks", "-$5.40") + row(0.40, "Uber", "-$12.00")
        // una sola fila: parcial
        let one = NazcaExample.Region(x: 0.0, y: 0.19, w: 1.0, h: 0.05)
        XCTAssertEqual(NazcaExample.rows(in: one, boxes: boxes).count, 1)
        let ex1 = NazcaExample.examples(from: one, boxes: boxes, today: today)
        XCTAssertEqual(ex1.count, 1)
        XCTAssertEqual(ex1[0].amount, 229.8)
        XCTAssertEqual(ex1[0].desc, "Gusto, Payroll")
        XCTAssertEqual(ex1[0].date, "2026-10-23")
        let t1 = try NazcaExample.learn(examples: ex1, boxes: boxes, today: today).get()
        XCTAssertEqual(t1.partial, true)
        XCTAssertEqual(NazcaExample.extract(t1, boxes: boxes, today: today).items.count, 3)
        // varias filas: dos con signo distinto
        let all = try XCTUnwrap(NazcaExample.listRegion(boxes: boxes))
        XCTAssertEqual(NazcaExample.rows(in: all, boxes: boxes).count, 3)
        let ex2 = NazcaExample.examples(from: all, boxes: boxes, today: today)
        XCTAssertEqual(ex2.count, 2)
        XCTAssertNotEqual(ex2[0].amount < 0, ex2[1].amount < 0)
        let t2 = try NazcaExample.learn(examples: ex2, boxes: boxes, today: today).get()
        XCTAssertNil(t2.partial)
        let x = NazcaExample.extract(t2, boxes: boxes, today: today)
        XCTAssertEqual(x.items.map(\.amount), [229.8, -5.4, -12])
        XCTAssertEqual(Set(x.items.map(\.date)), ["2026-10-23"])
        // un cuadro sin montos
        let empty = NazcaExample.Region(x: 0, y: 0.0, w: 1, h: 0.05)
        XCTAssertTrue(NazcaExample.examples(from: empty, boxes: boxes, today: today).isEmpty)
    }
}
