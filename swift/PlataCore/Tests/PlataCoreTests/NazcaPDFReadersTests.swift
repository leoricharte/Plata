import XCTest
@testable import PlataCore

/// Los lectores de PDF contra la web: mismo documento (los textos que vio pdf.js) → mismo resultado. Luego lo mismo con los textos que arma PDFKit.
final class NazcaPDFReadersTests: XCTestCase {
    static func close(_ a: Double?, _ b: JSONValue?) -> Bool {
        let want = (b == nil || b!.isNull) ? nil : b!.doubleValue
        if let a, let want { return abs(a - want) < 0.005 }
        return a == nil && want == nil
    }

    /// Diferencias entre lo que dice la web y lo que lee Swift (vacío = igual).
    static func diff(_ name: String, _ want: JSONValue, _ got: Nazca.StatementResult?) -> [String] {
        guard let got else { return ["\(name): Swift no lo leyó"] }
        var d: [String] = []
        func eq<T: Equatable>(_ k: String, _ a: T, _ b: T) { if a != b { d.append("\(name): \(k) = \(a), debía \(b)") } }
        eq("bank", got.bank ?? "", want["bank"]?.stringValue ?? "")
        eq("kind", got.kind, want["kind"]?.stringValue ?? "")
        eq("label", got.label, want["label"]?.stringValue ?? "")
        eq("last4", got.last4, want["last4"]?.stringValue ?? "")
        eq("error", got.error ?? "", (want["error"]?.isNull ?? true) ? "" : want["error"]!.stringValue!)
        if !(want["error"]?.isNull ?? true) { return d }
        eq("cur", got.cur, want["cur"]?.stringValue ?? "")
        if let p = want["period"], !p.isNull { eq("period", "\(got.period?.from ?? "")…\(got.period?.to ?? "")", "\(p["from"]!.stringValue!)…\(p["to"]!.stringValue!)") }
        else if got.period != nil { d.append("\(name): periodo de más") }
        let items = want["items"]?.arrayValue ?? []
        eq("items", got.items.count, items.count)
        for (k, w) in items.enumerated() where k < got.items.count {
            let g = got.items[k]
            var bad: [String] = []
            if g.line != w["line"]!.intValue! { bad.append("line \(g.line)") }
            if g.date != w["date"]!.stringValue! { bad.append("date \(g.date) vs \(w["date"]!.stringValue!)") }
            if g.desc != w["desc"]!.stringValue! { bad.append("desc «\(g.desc)» vs «\(w["desc"]!.stringValue!)»") }
            if abs(g.amount - w["amount"]!.doubleValue!) > 0.005 { bad.append("amount \(g.amount) vs \(w["amount"]!.doubleValue!)") }
            if g.cur != (w["cur"]?.stringValue ?? "") { bad.append("cur \(g.cur)") }
            if !close(g.balance, w["balance"]) { bad.append("balance \(String(describing: g.balance)) vs \(String(describing: w["balance"]?.doubleValue))") }
            if !bad.isEmpty { d.append("\(name): fila \(k + 1): " + bad.joined(separator: ", ")) }
        }
        eq("unreadable", got.unreadable, want["skipped"]?["unreadable"]?.intValue ?? 0)
        eq("zero", got.zero, want["skipped"]?["zero"]?.intValue ?? 0)
        if let c = want["check"], !c.isNull {
            if let gc = got.check {
                let wok = (c["ok"]?.isNull ?? true) ? nil : c["ok"]!.boolValue
                if gc.ok != wok { d.append("\(name): check.ok = \(String(describing: gc.ok)), debía \(String(describing: wok))") }
                if !close(gc.end, c["end"]) { d.append("\(name): check.end = \(String(describing: gc.end)), debía \(String(describing: c["end"]?.doubleValue))") }
            } else { d.append("\(name): falta check") }
        } else if got.check != nil { d.append("\(name): check de más") }
        if let c = want["card"], !c.isNull {
            if let gc = got.card {
                if !close(gc.limit, c["limit"]) { d.append("\(name): card.limit \(String(describing: gc.limit)) vs \(String(describing: c["limit"]?.doubleValue))") }
                if !close(gc.apr, c["apr"]) { d.append("\(name): card.apr \(String(describing: gc.apr)) vs \(String(describing: c["apr"]?.doubleValue))") }
                if !close(gc.minPayment, c["minPayment"]) { d.append("\(name): card.minPayment \(String(describing: gc.minPayment)) vs \(String(describing: c["minPayment"]?.doubleValue))") }
                if !close(gc.dueDay.map(Double.init), c["dueDay"]) { d.append("\(name): card.dueDay \(String(describing: gc.dueDay))") }
                let wd = (c["dueDate"]?.isNull ?? true) ? nil : c["dueDate"]!.stringValue
                if gc.dueDate != wd { d.append("\(name): card.dueDate \(String(describing: gc.dueDate)) vs \(String(describing: wd))") }
            } else { d.append("\(name): falta card") }
        } else if got.card != nil { d.append("\(name): card de más") }
        return d
    }

    static func docs() throws -> [JSONValue] { try NazcaPDFTests.golden()["docs"]!.arrayValue!.filter { $0["pages"] != nil } }

    /// Cada documento lo reconoce el mismo lector que en la web y se lee igual.
    func testReadersMatchTheWebOnPdfJsText() throws {
        var report: [String] = []
        var n = 0
        for d in try Self.docs() {
            let name = d["name"]!.stringValue!
            let doc = NazcaPDFTests.jsDoc(d)
            let hits = NazcaPDFBancos.readers.filter { $0.detect(doc) >= 1 }.map(\.id)
            let want = d["detects"]!.arrayValue!.map { $0.stringValue! }
            if hits != want { report.append("\(name): detecta \(hits), debía \(want)") }
            let rd = NazcaPDFBancos.detect(doc)
            let wantReader = (d["reader"]?.isNull ?? true) ? nil : d["reader"]!.stringValue
            if rd?.id != wantReader { report.append("\(name): lector \(rd?.id ?? "nil"), debía \(wantReader ?? "nil")"); continue }
            guard let rd, let r = d["read"], !r.isNull else { continue }
            n += 1
            report += Self.diff(name, r, rd.read(doc))
        }
        XCTAssertGreaterThan(n, 30)
        XCTAssertTrue(report.isEmpty, "\n" + report.prefix(25).joined(separator: "\n") + (report.count > 25 ? "\n… y \(report.count - 25) más" : ""))
    }

    /// Lector genérico: la tabla CSV que arma y los datos de la tarjeta.
    func testGenericReaderMatchesTheWeb() throws {
        var report: [String] = []
        for d in try Self.docs() {
            let name = d["name"]!.stringValue!
            guard let g = d["gen"], !g.isNull else { continue }
            let r = NazcaPDFGen.read(NazcaPDFTests.jsDoc(d))
            if r.text != g["text"]!.stringValue! { report.append("\(name): texto\n\(r.text)\n---\n\(g["text"]!.stringValue!)") }
            if r.count != g["count"]!.intValue! { report.append("\(name): count \(r.count) vs \(g["count"]!.intValue!)") }
            if r.cur != g["cur"]!.stringValue! { report.append("\(name): cur \(r.cur)") }
            if r.name != g["name"]!.stringValue! { report.append("\(name): nombre «\(r.name)» vs «\(g["name"]!.stringValue!)»") }
            if r.isCard != g["isCard"]!.boolValue! { report.append("\(name): isCard \(r.isCard)") }
            if r.last4 != g["last4"]!.stringValue! { report.append("\(name): last4 \(r.last4)") }
            let c = g["card"]!
            if !Self.close(r.card.limit, c["limit"]) || !Self.close(r.card.apr, c["apr"]) || !Self.close(r.card.minPayment, c["minPayment"]) || !Self.close(r.card.dueDay.map(Double.init), c["dueDay"]) {
                report.append("\(name): tarjeta \(r.card)")
            }
            let wd = (c["dueDate"]?.isNull ?? true) ? nil : c["dueDate"]!.stringValue
            if r.card.dueDate != wd { report.append("\(name): dueDate \(String(describing: r.card.dueDate)) vs \(String(describing: wd))") }
        }
        XCTAssertTrue(report.isEmpty, "\n" + report.prefix(10).joined(separator: "\n"))
    }

    func testNameFromFile() throws {
        for f in try NazcaPDFTests.golden()["fromFile"]!.arrayValue! {
            XCTAssertEqual(NazcaPDFGen.nameFromFile(f["v"]!.stringValue!), f["out"]!.stringValue!, f["v"]!.stringValue!)
        }
    }

    #if canImport(WebKit)
    /// Lo mismo, pero abriendo el PDF de verdad con el lector de la web (pdf.js en un WKWebView): es el camino que usa la app.
    @MainActor func testReadersOnWebBridgeText() async throws {
        var report: [String] = []
        for d in try Self.docs() {
            let name = d["name"]!.stringValue!
            guard let r = d["read"], !r.isNull else { continue }
            let doc: PdfDoc
            do { doc = try await NazcaPDFWeb.read(NazcaPDFTests.pdfData(name), password: d["key"]?.stringValue) } catch { report.append("\(name): no abrió (\(error))"); continue }
            guard let rd = NazcaPDFBancos.detect(doc) else {
                let flat = PDFx.flat(doc)
                func around(_ k: String) -> String { guard let r = flat.range(of: k, options: .caseInsensitive) else { return "«\(k)»: NO está" }; let a = flat.index(r.lowerBound, offsetBy: -12, limitedBy: flat.startIndex) ?? flat.startIndex; let b = flat.index(r.upperBound, offsetBy: 12, limitedBy: flat.endIndex) ?? flat.endIndex; return "«\(flat[a..<b])»" }
                let firsts = doc.pages.first?.items.prefix(6).map { "[\($0.str)|\(Int($0.x))|\(Int($0.y))]" }.joined() ?? ""
                report.append("\(name): el lector web no lo reconoce (debía \(d["reader"]!.stringValue!)) · \(doc.pages.count)p \(PDFx.items(doc).count) textos · \(firsts) · \(["Customer", "issued by", "Total Balance", "SALDO ANTERIOR", "MOVIMIENTO"].map(around).joined(separator: " "))"); continue }
            if rd.id != d["reader"]!.stringValue! { report.append("\(name): lector \(rd.id)"); continue }
            report += Self.diff(name, r, rd.read(doc))
        }
        XCTAssertTrue(report.isEmpty, "\n" + report.prefix(25).joined(separator: "\n") + (report.count > 25 ? "\n… y \(report.count - 25) más" : ""))
    }

    /// El lector web entrega exactamente lo que vio pdf.js en la web (textos y posiciones), y los mismos errores.
    @MainActor func testWebBridgeIsIdenticalToTheWeb() async throws {
        var report: [String] = []
        for d in try NazcaPDFTests.golden()["docs"]!.arrayValue! {
            let name = d["name"]!.stringValue!
            let key = d["key"]?.stringValue
            if let e = d["error"], !e.isNull {
                do { _ = try await NazcaPDFWeb.read(NazcaPDFTests.pdfData(name), password: key); report.append("\(name): debía fallar con \(e.stringValue!)") }
                catch let f as NazcaPDF.Failure { if f.rawValue != e.stringValue! { report.append("\(name): falló con \(f.rawValue), debía \(e.stringValue!)") } }
                catch { report.append("\(name): error raro \(error)") }
                continue
            }
            let want = NazcaPDFTests.jsDoc(d)
            let got: PdfDoc
            do { got = try await NazcaPDFWeb.read(NazcaPDFTests.pdfData(name), password: key) } catch { report.append("\(name): no abrió (\(error))"); continue }
            if got.pages.count != want.pages.count || got.total != want.total || got.truncated != want.truncated { report.append("\(name): páginas \(got.pages.count)/\(got.total), debían \(want.pages.count)/\(want.total)"); continue }
            var bad = 0
            for (pi, wp) in want.pages.enumerated() {
                let gp = got.pages[pi]
                if gp.items.count != wp.items.count { bad += 1; continue }
                for (k, w) in wp.items.enumerated() { let g = gp.items[k]; if g.str != w.str || abs(g.x - w.x) > 0.01 || abs(g.y - w.y) > 0.01 || abs(g.w - w.w) > 0.01 { bad += 1 } }
            }
            if bad > 0 { report.append("\(name): \(bad) diferencias con pdf.js de la web") }
        }
        XCTAssertTrue(report.isEmpty, "\n" + report.prefix(15).joined(separator: "\n"))
    }
    #endif
}
