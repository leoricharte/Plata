import XCTest
@testable import PlataCore

/// La revisión y aplicación de una importación (`impBuild` / `impGoOne` / `impUndo` de la web).
final class NazcaImportTests: XCTestCase {
    private func base(cur: String = "PEN") -> JSONValue {
        var p = Profile.empty.raw
        p["settings"] = .object(["currency": .string("PEN"), "currency2": .string(""), "fx": .number(3.5), "nick": .string(""), "first": .string(""), "last": .string(""), "gender": .string("n"), "cushion": .number(0), "variable_weekly": .number(0)])
        p["accounts"] = .array([.object(["id": .string("a1"), "name": .string("Banco"), "cur": .string(cur), "balance": .number(1000), "last4": .string("1234")])])
        p["cats"] = .array(["Comida", "Proyectos", "Alquiler", "Ocio", "Transporte", "Otros"].map { .object(["name": .string($0), "color": .string("#C9CBD1")]) })
        p["transactions"] = .array([.object(["id": .number(1), "date": .string("2026-10-03"), "amount": .number(-23.4), "category": .string("Transporte"), "note": .string("Uber"), "acc": .string("a1")])])
        return p
    }

    private func engine(_ p: JSONValue) -> Engine { Engine(profile: Profile(raw: p), today: LocalDate(iso: "2026-10-28")!) }

    private func review(_ csv: String, _ p: JSONValue, account: String? = "a1") throws -> ImportReview {
        let a = try Nazca.analyze(csv)
        return try XCTUnwrap(ImportReview(name: "estado.csv", analysis: a, engine: engine(p), preferredAccount: account))
    }

    private let csv = """
    Fecha,Descripción,Monto,Saldo
    01/10/2026,SUELDO OCTUBRE,3500.00,4500.00
    03/10/2026,UBER *TRIP LIMA,-23.40,4476.60
    07/10/2026,NETFLIX.COM,-44.90,4431.70
    05/12/2026,COMPRA FUTURA,-10.00,4421.70
    """

    func testBuildMarksDuplicatesFutureAndCategories() throws {
        let r = try review(csv, base())
        XCTAssertEqual(r.rows.count, 4)
        XCTAssertEqual(r.rows.map(\.why), [.none, .near, .none, .future])
        XCTAssertEqual(r.rows.map(\.on), [true, false, true, false])
        XCTAssertEqual(r.rows[0].cat, "Ingreso")
        XCTAssertEqual(r.rows[2].cat, "Ocio")
        XCTAssertEqual(r.rows.map(\.dc), ["PEN", "PEN", "PEN", "PEN"])
        XCTAssertEqual(r.flip, false)
    }

    func testStatementBalanceIsDefaultWhenNewer() throws {
        let r = try review(csv, base())
        // la fila de la fecha más reciente (futura incluida) trae el saldo del archivo
        let st = try XCTUnwrap(r.statement(engine(base())))
        XCTAssertEqual(st.date, "2026-12-05")
        XCTAssertEqual(r.balanceMode, .stmt)
    }

    func testApplyAdjustAndUndo() throws {
        let p = base()
        var r = try review(csv, p)
        r.balanceMode = .adjust
        var q = p
        let done = try XCTUnwrap(r.apply(to: &q, now: 1_000, newAccountId: "zz"))
        XCTAssertEqual(done.total, 2)
        let txs = q["transactions"]!.arrayValue!
        XCTAssertEqual(txs.count, 3)
        XCTAssertEqual(txs.last?["note"]?.stringValue, "NETFLIX.COM")
        XCTAssertEqual(txs.last?["imp"]?.stringValue, r.rows[2].fp)
        XCTAssertEqual(q["accounts"]!.arrayValue![0]["balance"]!.doubleValue!, 1000 + 3500 - 44.9, accuracy: 0.001)
        XCTAssertEqual(done.parts[0].before, 1000)
        ImportReview.undo(done, in: &q)
        XCTAssertEqual(q, p)
    }

    func testApplyStatementBalance() throws {
        let p = base()
        var r = try review(csv, p)
        r.balanceMode = .stmt
        var q = p
        _ = try XCTUnwrap(r.apply(to: &q, now: 1_000, newAccountId: "zz"))
        XCTAssertEqual(q["accounts"]!.arrayValue![0]["balance"]!.doubleValue!, 4421.70, accuracy: 0.001)
    }

    func testToggleRules() throws {
        var r = try review(csv, base())
        XCTAssertEqual(r.toggle(3), .future)
        XCTAssertNil(r.toggle(1))
        XCTAssertTrue(r.rows[1].on)
        XCTAssertEqual(r.selection[1], true)
        r.setOn([0, 1, 2, 3], false)
        XCTAssertEqual(r.rows.map(\.on), [false, false, false, false])
        var q = base()
        XCTAssertNil(r.apply(to: &q, now: 1, newAccountId: "zz"))
    }

    func testCardFlipsConsumptionsAndUsesPaymentCategory() throws {
        var p = base()
        p["cards"] = .array([.object(["id": .string("c1"), "kind": .string("card"), "name": .string("Visa"), "cur": .string("PEN"), "balance": .number(500), "due_day": .number(15), "apr": .number(40)])])
        let card = """
        Fecha,Descripcion,Monto
        02/10/2026,RAPPI PEDIDO,35.00
        04/10/2026,TOTTUS SURCO,120.50
        06/10/2026,PAGO RECIBIDO GRACIAS,-200.00
        """
        let eng = engine(p)
        let r = try XCTUnwrap(ImportReview(name: "tarjeta.csv", analysis: Nazca.analyze(card), engine: eng, preferredAccount: "c1"))
        XCTAssertEqual(r.flip, true)
        XCTAssertEqual(r.rows.map(\.amount), [-35, -120.5, 200])
        XCTAssertEqual(r.rows[2].cat, Engine.payCategory)
        var q = p
        var rr = r
        rr.balanceMode = .adjust
        let done = try XCTUnwrap(rr.apply(to: &q, now: 5, newAccountId: "zz"))
        // consumos suben la deuda y el pago la baja: 500 + 35 + 120.5 - 200
        XCTAssertEqual(q["cards"]!.arrayValue![0]["balance"]!.doubleValue!, 455.5, accuracy: 0.001)
        XCTAssertTrue(done.dones[0].credit)
        ImportReview.undo(done, in: &q)
        XCTAssertEqual(q, p)
    }

    func testForeignCurrencySkipAndConvertAndSplit() throws {
        let p = base()
        let fx = """
        Fecha,Descripcion,Monto,Moneda
        02/10/2026,TIENDA LIMA,-50.00,PEN
        04/10/2026,AMAZON PRIME VIDEO,-10.00,USD
        06/10/2026,SPOTIFY P1,-5.00,USD
        """
        let a = try Nazca.analyze(fx)
        let eng = engine(p)
        var r = try XCTUnwrap(ImportReview(name: "fx.csv", analysis: a, engine: eng, preferredAccount: "a1"))
        XCTAssertEqual(r.foreignCurrency, "USD")
        // USD no es la moneda principal (PEN) ni hay secundaria: se puede abrir cuenta aparte; por defecto, ni principal ni secundaria → omitir
        XCTAssertEqual(r.fxMode, .skip)
        XCTAssertEqual(r.rows.map(\.why), [.none, .cur, .cur])
        XCTAssertEqual(r.rows.map(\.on), [true, false, false])

        r.setFxRate(3.5, engine: eng)
        r.setFxMode(.convert, engine: eng)
        XCTAssertEqual(r.rows.map(\.why), [.none, .fxc, .fxc])
        XCTAssertEqual(r.rows.map(\.on), [true, true, true])
        XCTAssertEqual(r.rows[1].amount, -35)
        XCTAssertEqual(r.rows[1].orig, ImportReview.Orig(amount: -10, cur: "USD"))
        var q = p
        r.balanceMode = .adjust
        let done = try XCTUnwrap(r.apply(to: &q, now: 9, newAccountId: "zz"))
        XCTAssertEqual(done.total, 3)
        XCTAssertEqual(q["transactions"]!.arrayValue!.last?["note"]?.stringValue, "SPOTIFY P1 ($5.00)")
        ImportReview.undo(done, in: &q)
        XCTAssertEqual(q, p)

        var s = try XCTUnwrap(ImportReview(name: "fx.csv", analysis: a, engine: eng, preferredAccount: "a1"))
        s.setFxMode(.split, engine: eng)
        XCTAssertEqual(s.rows.map(\.side), [false, true, true])
        XCTAssertEqual(s.rows.map(\.why), [.none, .fxs, .fxs])
        s.balanceMode = .adjust
        var w = p
        let d2 = try XCTUnwrap(s.apply(to: &w, now: 9, newAccountId: "zz"))
        XCTAssertEqual(d2.parts.count, 2)
        XCTAssertEqual(w["accounts"]!.arrayValue!.count, 2)
        XCTAssertEqual(w["accounts"]!.arrayValue![1]["name"]?.stringValue, "Banco Dólares")
        XCTAssertEqual(w["accounts"]!.arrayValue![1]["balance"]!.doubleValue!, -15, accuracy: 0.001)
        XCTAssertEqual(w["settings"]?["currency2"]?.stringValue, "USD")
        ImportReview.undo(d2, in: &w)
        XCTAssertEqual(w, p)
    }

    func testColumnOverrideRereads() throws {
        let weird = """
        Fecha,Texto,Importe
        02/10/2026,TAMBO,-12.00
        03/10/2026,METRO,-30.00
        """
        let p = base()
        let eng = engine(p)
        var r = try XCTUnwrap(ImportReview(name: "x.csv", analysis: Nazca.analyze(weird), engine: eng, preferredAccount: "a1"))
        XCTAssertEqual(r.rows.count, 2)
        r.setColumn("amount", -1, engine: eng)
        XCTAssertEqual(r.rows.count, 0)
    }
}
