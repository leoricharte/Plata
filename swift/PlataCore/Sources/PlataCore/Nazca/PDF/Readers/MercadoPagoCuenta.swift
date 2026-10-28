import Foundation

/// Nazca · Mercado Pago (Chile) · Estado de cuenta (PDF) — puerto de `bancos/mercadopago-cuenta.js`.
/// Tabla horizontal con FECHA DE ACREDITACIÓN · TIPO DE MOVIMIENTO (Abono / Cargo) · … · MONTO (135.000,00); el nombre del comercio puede ir en dos líneas.
enum NazcaMercadoPago {
    static let DT = Rx(#"^(\d{2})-(\d{2})-(\d{4}) \d{2}:\d{2}:\d{2}$"#), MONEY = Rx(#"^-?\d{1,3}(\.\d{3})*,\d{2}$"#), dateOnly = Rx(#"^(\d{2})-(\d{2})-(\d{4})"#)

    /// `String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim().toUpperCase()`
    static func norm(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { out.append(u) }
        return PDFx.clean(String(out)).uppercased()
    }
    static func money(_ s: String) -> Double { PDFx.r2(PDFx.parseFloat(s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))) }
    static func iso(_ s: String) -> String {
        guard let m = DT.groups(s) ?? dateOnly.groups(s) else { return "" }
        return m[3] + "-" + m[2] + "-" + m[1]
    }

    static let rBrand = Rx(#"MERCADO ?PAGO"#), rF = Rx("FECHA DE ACREDITACION"), rM = Rx("TIPO DE MOVIMIENTO"), rI = Rx("ID DE TRANSACCION"), rIni = Rx("BALANCE INICIAL"), rFin = Rx("BALANCE FINAL")

    static func detect(_ doc: PdfDoc) -> Int {
        guard let p = doc.pages.first else { return 0 }
        let t = norm(p.text)
        return rBrand.test(t) && rF.test(t) && rM.test(t) && rI.test(t) && rIni.test(t) && rFin.test(t) ? 1 : 0
    }

    /// El valor de un título del encabezado o del resumen: el texto que está justo debajo, alineado a su izquierda.
    static func below(_ page: PdfPage, _ title: String, _ re: Rx) -> String? {
        guard let h = page.items.first(where: { norm($0.str) == title }) else { return nil }
        var best: PdfItem?
        for i in page.items where i.y < h.y - 3 && i.y > h.y - 70 && abs(i.x - h.x) < 8 && re.test(i.str) && (best == nil || i.y > best!.y) { best = i }
        return best?.str
    }

    static let uidRx = Rx(#"^\d{4,}$"#), cur3 = Rx(#"^[A-Z]{3}$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let first = doc.pages[0]
        let from = iso(below(first, "DESDE", DT) ?? ""), to = iso(below(first, "HASTA", DT) ?? "")
        let uid = below(first, "ID DE USUARIO", uidRx)
        func num(_ t: String) -> Double? { below(first, t, MONEY).map(money) }
        let prev = num("BALANCE INICIAL"), dep = num("DEPOSITOS"), deb = num("DEBITOS"), com = num("COMISIONES"), ret = num("RETENCIONES POR"), end = num("BALANCE FINAL")
        var out = Nazca.StatementResult(bank: "mercadopago", kind: "corriente", label: "Mercado Pago · Cuenta", cur: "CLP", items: [])
        out.last4 = uid.map { String($0.suffix(4)) } ?? ""
        if from.isEmpty || to.isEmpty { out.error = "period"; return out }
        out.period = .init(from: from, to: to)

        var sumIn = 0.0, sumOut = 0.0, line = 0
        var curs: [(String, Int)] = []
        for page in doc.pages {
            func H(_ t: String) -> PdfItem? { page.items.first { norm($0.str) == t } }
            guard let hf = H("FECHA DE ACREDITACION"), let hm = H("TIPO DE MOVIMIENTO"), let ht = H("TIPO DE TRANSACCION"), let hi = H("ID DE TRANSACCION"), let hc = H("MONEDA"),
                  let ha = H("MONTO DE TRANSACCION"), let hn = H("NOMBRE DEL COMERCIO") else { continue }
            let ho = H("OTROS CONCEPTOS")
            func cells(_ row: PdfItem, _ lo: Double, _ hi2: Double) -> String {
                PDFx.stableSortedByX(page.items.filter { abs($0.y - row.y) < 3 && $0.x >= lo - 4 && $0.x < hi2 - 4 }).map(\.str).joined(separator: " ").jsTrimmed
            }
            let rows = page.items.enumerated().filter { $0.element.y < hf.y - 3 && abs($0.element.x - hf.x) < 8 && DT.test($0.element.str) }
                .sorted { a, b in a.element.y != b.element.y ? a.element.y > b.element.y : a.offset < b.offset }.map(\.element)
            var names = rows.map { _ in [PdfItem]() }
            for i in page.items {
                if i.y >= hf.y - 3 || i.x < hn.x - 6 || rows.isEmpty { continue }
                var k = 0
                for j in 1..<max(rows.count, 1) where abs(rows[j].y - i.y) < abs(rows[k].y - i.y) { k = j }
                if abs(rows[k].y - i.y) < 20 { names[k].append(i) }
            }
            for (k, row) in rows.enumerated() {
                let mov = norm(cells(row, hm.x, ht.x)), trx = cells(row, ht.x, hi.x), cur = cells(row, hc.x, ha.x), amt = cells(row, ha.x, ho?.x ?? hn.x)
                let nm = PDFx.clean(names[k].enumerated().sorted { a, b in a.element.y != b.element.y ? a.element.y > b.element.y : (a.element.x != b.element.x ? a.element.x < b.element.x : a.offset < b.offset) }.map(\.element.str).joined(separator: " "))
                let sign = mov == "ABONO" ? 1.0 : mov == "CARGO" ? -1.0 : 0
                if sign == 0 || !MONEY.test(amt) || !cur3.test(cur) { out.unreadable += 1; continue }
                let v = money(amt)
                if v != 0 && (v < 0) != (sign < 0) { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                let amount = sign * abs(v)
                if amount > 0 { sumIn += amount } else { sumOut += -amount }
                if let i = curs.firstIndex(where: { $0.0 == cur }) { curs[i].1 += 1 } else { curs.append((cur, 1)) }
                let base = trx.isEmpty ? "Movimiento" : trx
                let desc = (nm.isEmpty ? base : (norm(trx) == "PAGO" ? nm : base + " · " + nm)).jsSlice(0, 90)
                line += 1
                out.items.append(Nazca.Item(line: line, date: iso(row.str), desc: desc, amount: amount, cur: cur))
            }
        }
        var top: (String, Int)?
        for c in curs where top == nil || c.1 > top!.1 { top = c }
        if let top { out.cur = top.0 }
        sumIn = PDFx.r2(sumIn); sumOut = PDFx.r2(sumOut)
        var ok: Bool?
        if let prev, let end, let dep, let deb { ok = PDFx.near(PDFx.r2(prev + dep - deb - (com ?? 0) - (ret ?? 0)), end) && PDFx.near(sumIn, dep) && PDFx.near(sumOut, deb) }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
