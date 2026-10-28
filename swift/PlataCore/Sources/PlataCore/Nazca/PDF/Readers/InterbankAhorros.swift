import Foundation

/// Nazca · Interbank · Estado de cuenta de ahorros (PDF) — puerto de `bancos/interbank-ahorros.js`.
/// Cada movimiento: fecha completa · concepto · monto con signo · saldo de esa fila. La última página es una guía con movimientos de ejemplo: se ignora.
enum NazcaInterbank {
    static let MES: [String: Int] = ["ENERO": 1, "FEBRERO": 2, "MARZO": 3, "ABRIL": 4, "MAYO": 5, "JUNIO": 6, "JULIO": 7, "AGOSTO": 8, "SETIEMBRE": 9, "SEPTIEMBRE": 9, "OCTUBRE": 10, "NOVIEMBRE": 11, "DICIEMBRE": 12]
    static let amount = Rx(#"^[+-]?[\d,]+\.\d{2}$"#), date = Rx(#"^(\d{2})\/(\d{2})\/(\d{4})$"#), guide = Rx(#"Te ayudamos a conocer"#, ci: true)

    static func real(_ doc: PdfDoc) -> [PdfPage] { doc.pages.filter { !guide.test($0.text) } }

    static let estado = Rx(#"ESTADO DE CUENTA"#), detalle = Rx(#"DETALLE DE MOVIMIENTOS"#), saldoC = Rx(#"Saldo Contable"#, ci: true), ingresos = Rx(#"\bIngresos\b"#), gastos = Rx(#"\bGastos\b"#), ib = Rx(#"Interbank"#, ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        let pages = real(doc)
        guard let p0 = pages.first else { return 0 }
        let t = p0.text, all = doc.pages.map(\.text).joined(separator: " ")
        return estado.test(t) && detalle.test(t) && saldoC.test(t) && ingresos.test(t) && gastos.test(t) && ib.test(all) ? 1 : 0
    }

    struct Span { var fd: Int, fm: Int, td: Int, tm: Int }
    static let spanRx = Rx(#"^DEL (\d{1,2})(?: DE ([A-ZÁÉÍÓÚ]+))? AL (\d{1,2}) DE ([A-ZÁÉÍÓÚ]+)$"#)

    static func span(_ page: PdfPage) -> Span? {
        for it in page.items {
            guard let m = spanRx.groups(it.str) else { continue }
            guard let to = MES[m[4]], let from = m[2].isEmpty ? Optional(to) : MES[m[2]] else { continue }
            return Span(fd: Int(m[1])!, fm: from, td: Int(m[3])!, tm: to)
        }
        return nil
    }

    static let dollars = Rx(#"D[ÓO]LARES"#, ci: true), prodRx = Rx(#"^CUENTA [A-ZÁÉÍÓÚ ]+$"#), prodCur = Rx(#"\s+(SOLES|D[ÓO]LARES)$"#, ci: true)
    static let acctRx = Rx(#"^\d{3}-\d{10}$"#), nonDigit = Rx(#"\D"#), openRx = Rx(#"^EMPEZASTE .+ CON$"#), totRx = Rx(#"^SALDO CONTABLE AL \d{2}\/\d{2}$"#), signed = Rx(#"^[+-]"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let pages = real(doc), first = pages[0]
        let sp = span(first)
        let head = first.text
        let before = head.components(separatedBy: "DETALLE DE MOVIMIENTOS")[0]
        let cur = dollars.test(before) ? "USD" : "PEN"
        let prod = PDFx.find(first.items, prodRx)
        let kind = prod.map { PDFx.titleCase(prodCur.replace($0.str, "")) } ?? ""
        let label = "Interbank" + (kind.isEmpty ? "" : " · " + kind)
        let acct = PDFx.find(first.items, acctRx)
        var out = Nazca.StatementResult(bank: "interbank", kind: "ahorros", label: label, cur: cur, items: [])
        out.last4 = acct.map { String(nonDigit.replace($0.str, "").suffix(4)) } ?? ""
        guard let sp else { out.error = "period"; return out }

        var prev: Double?, totIn: Double?, totOut: Double?, end: Double?
        var sumIn = 0.0, sumOut = 0.0, line = 0, running = true
        var last: Double?
        for page in pages {
            let hi = page.items.first { $0.str == "Ingresos" }, hg = page.items.first { $0.str == "Gastos" }
            let mid: Double? = hi != nil && hg != nil ? ((hi!.x + hi!.w) + (hg!.x + hg!.w)) / 2 : nil
            for l in NazcaPDF.lines(page) {
                let its = l.items
                let amts = its.filter { amount.test($0.str) && $0.x > page.w * 0.3 }
                if its.contains(where: { openRx.test($0.str) }) { if let a = amts.last { prev = PDFx.money(a.str) }; continue }
                if its.contains(where: { totRx.test($0.str) }) {
                    if amts.count >= 3 { totIn = abs(PDFx.money(amts[0].str)); totOut = abs(PDFx.money(amts[1].str)); end = PDFx.money(amts[amts.count - 1].str) }
                    continue
                }
                guard let d = date.groups(its[0].str), its[0].x <= page.w * 0.2 else { continue }
                let body = PDFx.clean(its.dropFirst().filter { !amount.test($0.str) || $0.x <= page.w * 0.3 }.map(\.str).joined(separator: " "))
                if amts.count < 2 || body.isEmpty { out.unreadable += 1; continue }
                let bal = amts[amts.count - 1], mov = amts[amts.count - 2]
                var v = PDFx.money(mov.str)
                let neg = signed.test(mov.str) ? mov.str.hasPrefix("-") : (mid != nil ? mov.x + mov.w < mid! : v < 0)
                v = abs(v)
                let dt = "\(d[3])-\(d[2])-\(d[1])"
                if v == 0 || v.isNaN { out.zero += 1; continue }
                let amt = neg ? -v : v
                if neg { sumOut += v } else { sumIn += v }
                let b = PDFx.money(bal.str)
                if let last, !PDFx.near(PDFx.r2(last + amt), b) { running = false }
                if last == nil, let prev, !PDFx.near(PDFx.r2(prev + amt), b) { running = false }
                last = b
                line += 1
                out.items.append(Nazca.Item(line: line, date: dt, desc: body, amount: amt, cur: cur, balance: b))
            }
        }
        sumIn = PDFx.r2(sumIn); sumOut = PDFx.r2(sumOut)

        // Año: el de las fechas de los movimientos
        if !out.items.isEmpty {
            let ds = out.items.map(\.date).sorted()
            let lastD = ds[ds.count - 1]
            let ly = Int(lastD.jsSlice(0, 4))!, lk = Int(lastD.jsSlice(5, 7))! * 100 + Int(lastD.jsSlice(8, 10))!
            let ty = sp.tm * 100 + sp.td >= lk ? ly : ly + 1, fy = sp.fm > sp.tm ? ty - 1 : ty
            out.period = .init(from: PDFx.iso(fy, sp.fm, sp.fd), to: PDFx.iso(ty, sp.tm, sp.td))
        }
        var ok: Bool?
        if let prev, let totIn, let totOut, let end { ok = PDFx.near(sumOut, totOut) && PDFx.near(sumIn, totIn) && PDFx.near(PDFx.r2(prev + sumIn - sumOut), end) && running }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
