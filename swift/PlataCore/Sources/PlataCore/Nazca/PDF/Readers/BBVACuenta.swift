import Foundation

/// Nazca · BBVA Perú · «Movimiento y saldo a la fecha» de una cuenta (PDF) — puerto de `bancos/bbva-cuenta.js`.
/// Fechas dd-mm (el año sale de la fecha del estado), monto en una sola columna (cargo con «-» al final), ITF aparte, saldo fila por fila.
enum NazcaBBVA {
    static let AMOUNT = Rx(#"^[\d,]+\.\d{2}-?$"#), DM = Rx(#"^(\d{2})-(\d{2})$"#), FULL = Rx(#"^(\d{2})-(\d{2})-(\d{4})$"#)

    static let rTitle = Rx("MOVIMIENTO Y SALDO A LA FECHA"), rCargo = Rx(#"CARGO\/ABONO"#), rSaldoC = Rx("SALDO CONTABLE"), rSaldoA = Rx("SALDO ANTERIOR"), rBbva = Rx(#"BBVA|bbva\.pe"#)

    static func detect(_ doc: PdfDoc) -> Int {
        guard let p = doc.pages.first else { return 0 }
        let t = p.text
        return rTitle.test(t) && rCargo.test(t) && rSaldoC.test(t) && rSaldoA.test(t) && rBbva.test(t) ? 1 : 0
    }

    static let prodRx = Rx(#"^CUENTA [A-ZÁÉÍÓÚÑ ]+$"#), acctRx = Rx(#"^\d{10}$"#), monedaRx = Rx(#"^MONEDA:?(\s|$)"#), dolarRx = Rx(#"D[ÓO]LAR|USD"#, ci: true)
    static let cardMask = Rx(#"\/\d{6}\*+\d{4}\s*$"#), endsDash = Rx(#"-$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let first = doc.pages[0]
        let prod = PDFx.find(first.items, prodRx)
        let kind = prod.map { PDFx.titleCase($0.str) } ?? "Cuenta"
        let acct = PDFx.find(first.items, acctRx)
        let mi = first.items.firstIndex { monedaRx.test($0.str) }
        let mon = mi.map { PDFx.slice(first.items, $0, $0 + 4).map(\.str).joined(separator: " ") } ?? ""
        let cur = dolarRx.test(mon) ? "USD" : "PEN"
        var out = Nazca.StatementResult(bank: "bbva", kind: "ahorros", label: "BBVA · " + kind, cur: cur, items: [])
        out.last4 = acct.map { String($0.str.suffix(4)) } ?? ""
        // Fecha del estado de cuenta (dd-mm-aaaa): de ahí sale el año de los movimientos.
        var st: (y: Int, m: Int, d: Int)?
        outer: for p in doc.pages { for it in p.items { if let m = FULL.groups(it.str), let mo = Int(m[2]), mo >= 1, mo <= 12 { st = (Int(m[3])!, mo, Int(m[1])!); break outer } } }
        guard let st else { out.error = "period"; return out }

        var prev: Double?, end: Double?, last: Double?
        var sumIn = 0.0, sumOut = 0.0, line = 0, running = true
        for page in doc.pages {
            let itfH = page.items.first { $0.str == "ITF" }, nuestro = page.items.first { $0.str == "SALDO A NUESTRO FAVOR" }, suyo = page.items.first { $0.str == "SALDO A SU FAVOR" }
            let itfX = itfH.map { $0.x - 12 } ?? page.w * 0.78
            for l in NazcaPDF.lines(page) {
                let its = l.items, amts = its.filter { AMOUNT.test($0.str) && $0.x > page.w * 0.55 }
                if its.contains(where: { $0.str == "SALDO ANTERIOR" }) { if let a = amts.last { prev = PDFx.numDash(a.str) }; continue }
                guard DM.test(its[0].str), its[0].x <= page.w * 0.15, its.count > 1, DM.test(its[1].str) else { continue }
                let d = DM.groups(its[0].str)!
                var body = its.dropFirst(2).filter { !AMOUNT.test($0.str) && $0.x > page.w * 0.1 && $0.x < page.w * 0.38 }.map(\.str).joined(separator: " ")
                body = PDFx.clean(cardMask.replace(body, ""))
                let bal: PdfItem? = amts.count >= 2 ? amts[amts.count - 1] : nil
                let rest: [PdfItem] = bal != nil ? Array(amts.dropLast()) : []
                let mov = rest.first { $0.x < itfX }, itf = rest.first { $0.x >= itfX }
                guard let bal, let mov, !body.isEmpty else { out.unreadable += 1; continue }
                let v = PDFx.numDash(mov.str), neg = endsDash.test(mov.str)
                let month = Int(d[2])!, year = month > st.m ? st.y - 1 : st.y
                let date = "\(year)-\(d[2])-\(d[1])"
                let b = PDFx.numDash(bal.str), tax = itf.map { PDFx.numDash($0.str) } ?? 0
                let amount = neg ? -v : v
                if v == 0 || v.isNaN { out.zero += 1; continue }
                let base: Double? = last ?? prev
                let expect = PDFx.r2((base ?? .nan) + amount - tax)
                if base != nil && !PDFx.near(expect, b) { running = false }
                last = b
                if neg { sumOut += v } else { sumIn += v }
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: body, amount: amount, cur: cur, balance: tax != 0 ? PDFx.r2(b + tax) : b))
                if tax != 0 { sumOut += tax; line += 1; out.items.append(Nazca.Item(line: line, date: date, desc: "ITF", amount: -tax, cur: cur, balance: b)) }
            }
            if let suyo {
                let below = page.items.filter { AMOUNT.test($0.str) && $0.y < suyo.y && $0.y > suyo.y - 25 }
                func c(_ i: PdfItem) -> Double { i.x + i.w / 2 }
                func pick(_ h: PdfItem) -> Int? {
                    var best: Int?
                    for (k, i) in below.enumerated() where best == nil || abs(c(i) - c(h)) < abs(c(below[best!]) - c(h)) { best = k }
                    return best
                }
                if let a = pick(suyo) {
                    let n = nuestro.flatMap { pick($0) }
                    end = PDFx.r2(PDFx.numDash(below[a].str) - (n != nil && n != a ? PDFx.numDash(below[n!].str) : 0))
                }
            }
        }
        sumIn = PDFx.r2(sumIn); sumOut = PDFx.r2(sumOut)
        if !out.items.isEmpty {
            let ds = out.items.map(\.date).sorted(), ms = PDFx.iso(st.y, st.m, 1)
            out.period = .init(from: ds[0] < ms ? ds[0] : ms, to: PDFx.iso(st.y, st.m, st.d))
        }
        var ok: Bool?
        if let prev, let end { ok = PDFx.near(PDFx.r2(prev + sumIn - sumOut), end) && running }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
