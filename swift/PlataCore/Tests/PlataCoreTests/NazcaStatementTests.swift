import XCTest
@testable import PlataCore

/// Revisión de un estado de cuenta ya leído (Yape, tarjeta): cuenta nueva o fusionar, saldo del estado, unir varios archivos.
final class NazcaStatementTests: XCTestCase {
    private func base() -> JSONValue {
        var p = Profile.empty.raw
        p["settings"] = .object(["currency": .string("PEN"), "currency2": .string(""), "fx": .number(3.5), "nick": .string(""), "first": .string(""), "last": .string(""), "gender": .string("n"), "cushion": .number(0), "variable_weekly": .number(0)])
        p["accounts"] = .array([.object(["id": .string("a1"), "name": .string("Banco"), "cur": .string("PEN"), "balance": .number(1000), "last4": .string("1234")])])
        p["cats"] = .array(["Comida", "Proyectos", "Alquiler", "Ocio", "Transporte", "Otros"].map { .object(["name": .string($0), "color": .string("#C9CBD1")]) })
        p["transactions"] = .array([])
        return p
    }
    private func engine(_ p: JSONValue) -> Engine { Engine(profile: Profile(raw: p), today: LocalDate(iso: "2026-10-28")!) }

    private let yapeRows: [[String]] = [
        ["Tipo de Transacción", "Origen", "Destino", "Monto", "Mensaje", "Fecha de operación"],
        ["PAGASTE", "Yo", "Tambo+ Miraflores", "S/ 16.08", "", "20/10/2026 13:10:26"],
        ["TE PAGÓ", "Sara Ron*", "Yo", "250.00", "", "21/10/2026"],
    ]

    func testYapeCreatesNewAccountAndUndoes() throws {
        let p = base()
        let res = try XCTUnwrap(NazcaYape.read(yapeRows))
        var r = try XCTUnwrap(ImportReview(name: "yape.xlsx", statement: res, engine: engine(p)))
        // no hay cuenta de Yape: se sugiere crear una nueva
        XCTAssertEqual(r.account, ImportReview.newId)
        XCTAssertEqual(r.source?.newAcc["name"]?.stringValue, "Yape Soles")
        XCTAssertEqual(r.mergeTarget(engine(p)), "a1")
        XCTAssertEqual(r.rows.count, 2)
        // sin saldo en el archivo → se suma
        XCTAssertEqual(r.balanceMode, .adjust)
        var q = p
        let done = try XCTUnwrap(r.apply(to: &q, now: 7, newAccountId: "yp"))
        XCTAssertEqual(q["accounts"]!.arrayValue!.count, 2)
        XCTAssertEqual(q["accounts"]!.arrayValue![1]["balance"]!.doubleValue!, 250 - 16.08, accuracy: 0.001)
        XCTAssertEqual(q["transactions"]!.arrayValue!.count, 2)
        XCTAssertTrue(done.dones[0].created)
        ImportReview.undo(done, in: &q)
        XCTAssertEqual(q, p)
        // fusionar con la cuenta que ya existe
        r.chooseAccount("a1", engine: engine(p))
        let d2 = try XCTUnwrap(r.apply(to: &q, now: 7, newAccountId: "yp"))
        XCTAssertEqual(q["accounts"]!.arrayValue!.count, 1)
        XCTAssertEqual(q["accounts"]!.arrayValue![0]["balance"]!.doubleValue!, 1000 + 250 - 16.08, accuracy: 0.001)
        ImportReview.undo(d2, in: &q)
        XCTAssertEqual(q, p)
    }

    func testSuggestsExistingAccountOfTheSameBank() throws {
        var p = base()
        p["accounts"] = .array([.object(["id": .string("y1"), "name": .string("Yape"), "cur": .string("PEN"), "balance": .number(50), "last4": .string("")])])
        let res = try XCTUnwrap(NazcaYape.read(yapeRows))
        let r = try XCTUnwrap(ImportReview(name: "yape.xlsx", statement: res, engine: engine(p)))
        XCTAssertEqual(r.account, "y1")
        XCTAssertEqual(r.mergeTarget(engine(p)), "y1")
    }

    func testCardStatementUsesStatementDebtAndCardInfo() throws {
        var p = base()
        p["cards"] = .array([])
        var res = Nazca.StatementResult(bank: "io", kind: "tarjeta", label: "iO · Tarjeta de crédito", cur: "PEN", items: [
            Nazca.Item(line: 1, date: "2026-10-02", desc: "RAPPI", amount: -35), Nazca.Item(line: 2, date: "2026-10-06", desc: "PAGO", amount: 200)])
        var ci = Nazca.StatementResult.CardInfo(); ci.limit = 5000; ci.apr = 45.5; ci.dueDay = 40; ci.minPayment = 120
        res.card = ci; res.last4 = "9876"; res.period = Nazca.StatementResult.Period(from: "2026-09-10", to: "2026-10-09"); res.check = Nazca.StatementResult.Check(ok: true, end: 830.5)
        let r = try XCTUnwrap(ImportReview(name: "io.pdf", statement: res, engine: engine(p)))
        XCTAssertEqual(r.account, ImportReview.newId)
        let n = try XCTUnwrap(r.source?.newAcc)
        XCTAssertEqual(n["kind"]?.stringValue, "card")
        XCTAssertEqual(n["limit"]?.doubleValue, 5000)
        XCTAssertEqual(n["due_day"]?.doubleValue, 31)
        XCTAssertEqual(n["last4"]?.stringValue, "9876")
        XCTAssertEqual(r.rows[1].cat, Engine.payCategory)
        XCTAssertEqual(r.balanceMode, .stmt)
        XCTAssertEqual(r.statement(credit: true), ImportReview.Statement(balance: 830.5, date: "2026-10-09"))
        var q = p
        let done = try XCTUnwrap(r.apply(to: &q, now: 9, newAccountId: "tc"))
        XCTAssertEqual(q["cards"]!.arrayValue!.count, 1)
        XCTAssertEqual(q["cards"]!.arrayValue![0]["balance"]!.doubleValue!, 830.5, accuracy: 0.001)
        XCTAssertTrue(done.dones[0].credit)
        ImportReview.undo(done, in: &q)
        XCTAssertEqual(q, p)
    }

    func testMergeTwoStatements() throws {
        let p = base()
        func st(_ items: [Nazca.Item], _ from: String, _ to: String, _ end: Double) -> Nazca.StatementResult {
            var r = Nazca.StatementResult(bank: "io", kind: "tarjeta", label: "iO", cur: "PEN", items: items)
            r.period = Nazca.StatementResult.Period(from: from, to: to); r.check = Nazca.StatementResult.Check(ok: true, end: end); r.card = Nazca.StatementResult.CardInfo()
            return r
        }
        let a = st([Nazca.Item(line: 1, date: "2026-09-02", desc: "UBER", amount: -10), Nazca.Item(line: 2, date: "2026-09-20", desc: "NETFLIX", amount: -44.9)], "2026-08-10", "2026-09-09", 100)
        let b = st([Nazca.Item(line: 1, date: "2026-09-20", desc: "netflix", amount: -44.9), Nazca.Item(line: 2, date: "2026-10-03", desc: "WONG", amount: -80)], "2026-09-10", "2026-10-09", 220)
        let e = engine(p)
        var x = try XCTUnwrap(ImportReview(name: "a.pdf", statement: a, engine: e))
        let y = try XCTUnwrap(ImportReview(name: "b.pdf", statement: b, engine: e))
        XCTAssertTrue(x.isSame(as: y))
        x.merge(y, engine: e)
        XCTAssertEqual(x.rows.count, 3)
        XCTAssertEqual(x.mdup, 1)
        XCTAssertEqual(x.names, ["a.pdf", "b.pdf"])
        XCTAssertEqual(x.source?.period, Nazca.StatementResult.Period(from: "2026-08-10", to: "2026-10-09"))
        XCTAssertEqual(x.source?.stmtEnd, ImportReview.Statement(balance: 220, date: "2026-10-09"))
        XCTAssertEqual(x.source?.check?.n, 2)
        XCTAssertEqual(x.source?.check?.ok, true)
    }

    func testCatalogAndCsvSignature() {
        let pe = Nazca.bankCatalog.first { $0.id == "PE" }!
        XCTAssertEqual(pe.banks.map(\.id), ["bcp", "bbva", "interbank", "io", "yape", "scotiabank"])
        XCTAssertEqual(Nazca.bankShort("bcp"), "BCP")
        XCTAssertEqual(Nazca.bankShort("yape"), "Yape")
        XCTAssertEqual(Nazca.countryName("mercadopago"), "Chile")
        let h = ["Transaction Date", "Clearing Date", "Description", "Merchant", "Category", "Type", "Amount (USD)", "Purchased By"]
        XCTAssertEqual(Nazca.detectCsv(h)?.bank, "applecard")
        XCTAssertNil(Nazca.detectCsv(["Fecha", "Monto"]))
        XCTAssertEqual(Nazca.bankKeys(ofName: "Mi BCP Ahorros")?.first, "bcp")
        XCTAssertNil(Nazca.bankKeys(ofName: "Efectivo"))
    }
}
