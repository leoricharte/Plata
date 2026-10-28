import Foundation

/// Nazca · BCP · Estado de cuenta de ahorros (PDF) — puerto de `bancos/bcp-ahorros.js`.
/// Cada movimiento: FECHA PROC. (30SET) · FECHA VALOR + DESCRIPCIÓN · marca opcional · monto sin signo (cargo o abono según la columna en que cae).
enum NazcaBCP {
    static let MES: [String: Int] = ["ENE": 1, "FEB": 2, "MAR": 3, "ABR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AGO": 8, "SET": 9, "SEP": 9, "OCT": 10, "NOV": 11, "DIC": 12]
    static let amount = Rx(#"^[\d,]+\.\d{2}$"#), dateShort = Rx(#"^(\d{1,2})([A-Z]{3})$"#), dateFull = Rx(#"^(\d{2})\/(\d{2})\/(\d{2}|\d{4})$"#)

    static let titleRx = Rx(#"Estado de Cuenta de Ahorros"#, ci: true), bcpRx = Rx(#"\bBCP\b"#), cargosRx = Rx(#"CARGOS\s*\/\s*DEBE"#), abonosRx = Rx(#"ABONOS\s*\/\s*HABER"#)

    static func detect(_ doc: PdfDoc) -> Int {
        guard let first = doc.pages.first else { return 0 }
        let text = first.text
        return titleRx.test(text) && bcpRx.test(text) && cargosRx.test(text) && abonosRx.test(text) ? 1 : 0
    }

    struct YMD { var y: Int, m: Int, d: Int; var key: Int { y * 10000 + m * 100 + d } }

    static let stateLabel = Rx(#"FECHA DE ESTADO DE CUENTA"#)
    static func period(_ doc: PdfDoc) -> (from: YMD, to: YMD)? {
        let items = doc.pages[0].items
        let label = PDFx.find(items, stateLabel)
        let ds = items.enumerated().filter { dateFull.test($0.element.str) && (label == nil || $0.element.y <= label!.y + 2) }
            .sorted { a, b in a.element.y != b.element.y ? a.element.y > b.element.y : (a.element.x != b.element.x ? a.element.x < b.element.x : a.offset < b.offset) }
            .map(\.element)
        if ds.count < 2 { return nil }
        func p(_ s: String) -> YMD { let m = dateFull.groups(s)!; return YMD(y: m[3].count == 2 ? 2000 + Int(m[3])! : Int(m[3])!, m: Int(m[2])!, d: Int(m[1])!) }
        let from = p(ds[0].str), to = p(ds[1].str)
        if from.m < 1 || from.m > 12 || to.m < 1 || to.m > 12 || from.key > to.key { return nil }
        return (from, to)
    }

    /// 30SET → fecha completa: el año más reciente cuyo día no pasa de unos días después del fin del periodo.
    static func resolve(_ dd: Int, _ mon: String, _ to: YMD) -> String? {
        guard let m = MES[mon] else { return nil }
        let endKey = to.y * 372 + to.m * 31 + to.d + 7
        for y in [to.y, to.y - 1] {
            if dd < 1 || dd > PDFx.daysIn(y, m) { continue }
            if y * 372 + m * 31 + dd <= endKey { return PDFx.iso(y, m, dd) }
        }
        return nil
    }

    static let curWordRx = Rx(#"^(SOLES|DOLARES|DÓLARES|US ?DOLARES)$"#, ci: true), startS = Rx(#"^S"#, ci: true)
    static let acctRx = Rx(#"^\d{3}-\d{6,}-\d-\d{2}$"#), nonDigit = Rx(#"\D"#)
    static let cargosHead = Rx(#"^CARGOS\s*\/\s*DEBE$"#), abonosHead = Rx(#"^ABONOS\s*\/\s*HABER$"#), procHead = Rx(#"^FECHA PROC\.?$"#)
    static let totalMov = Rx(#"^TOTAL MOVIMIENTO$"#), saldoRx = Rx(#"^SALDO$"#), saldoAnt = Rx(#"^SALDO ANTERIOR$"#), mark = Rx(#"^[*\d]$"#), d2Rx = Rx(#"^(\d{1,2})([A-Z]{3})\s+(.+)$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let label = "BCP · Cuenta de ahorros"
        guard let per = period(doc) else {
            var r = Nazca.StatementResult(bank: "bcp", kind: "ahorros", label: label, cur: "", items: [])
            r.error = "period"; return r
        }
        let everything = PDFx.items(doc)
        let cur = PDFx.find(everything, curWordRx).map { startS.test($0.str) ? "PEN" : "USD" } ?? "PEN"
        let acct = PDFx.find(doc.pages[0].items, acctRx)
        let digits = acct.map { nonDigit.replace($0.str, "") } ?? ""
        var out = Nazca.StatementResult(bank: "bcp", kind: "ahorros", label: label, cur: cur, items: [])
        out.last4 = String(digits.suffix(4))
        out.period = .init(from: PDFx.iso(per.from.y, per.from.m, per.from.d), to: PDFx.iso(per.to.y, per.to.m, per.to.d))
        var prev: Double?, totC: Double?, totA: Double?, end: Double?
        var sumC = 0.0, sumA = 0.0, line = 0
        var mid: Double?

        for page in doc.pages {
            if let hc = PDFx.find(page.items, cargosHead), let ha = PDFx.find(page.items, abonosHead) { mid = ((hc.x + hc.w) + (ha.x + ha.w)) / 2 }
            guard let mid else { continue }
            func isCharge(_ it: PdfItem) -> Bool { !(it.x + it.w > mid) }
            let head = PDFx.find(page.items, procHead)
            let top = head?.y ?? .infinity
            let amounts = page.items.filter { amount.test($0.str) && $0.y < top - 2 }

            if let lt = page.items.first(where: { totalMov.test($0.str) }) {
                for a in amounts where abs(a.y - lt.y) <= 9 { if isCharge(a) { totC = PDFx.money(a.str) } else { totA = PDFx.money(a.str) } }
            }
            if let ls = page.items.first(where: { saldoRx.test($0.str) }), let a = amounts.first(where: { abs($0.y - ls.y) <= 10 }) { end = PDFx.money(a.str) * (isCharge(a) ? -1 : 1) }
            if let lp = page.items.first(where: { saldoAnt.test($0.str) }), let a = amounts.first(where: { abs($0.y - lp.y) <= 4 }) { prev = PDFx.money(a.str) * (isCharge(a) ? -1 : 1) }

            for l in NazcaPDF.lines(page) {
                if l.y >= top - 2 { continue }
                let its = l.items
                guard let d1 = dateShort.groups(its[0].str), its[0].x <= page.w * 0.2 else { continue }
                let rest = Array(its.dropFirst())
                let ai = rest.lastIndex { amount.test($0.str) }
                let body = PDFx.clean(rest.enumerated().filter { $0.offset != ai && !mark.test($0.element.str) }.map(\.element.str).joined(separator: " "))
                let d2 = d2Rx.groups(body)
                let date = resolve(Int(d1[1])!, d1[2], per.to)
                guard let ai, let d2, let date else { out.unreadable += 1; continue }
                let amt = rest[ai]
                let val = PDFx.money(amt.str)
                if val == 0 || val.isNaN { out.zero += 1; continue }
                let charge = isCharge(amt)
                if charge { sumC += val } else { sumA += val }
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: d2[3], amount: charge ? -val : val, cur: cur, balance: nil))
            }
        }
        sumC = PDFx.r2(sumC); sumA = PDFx.r2(sumA)
        if let end, !out.items.isEmpty { out.items[out.items.count - 1].balance = end }
        var ok: Bool?
        if let totC, let totA, let prev, let end { ok = PDFx.near(sumC, totC) && PDFx.near(sumA, totA) && PDFx.near(prev + sumA - sumC, end) }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
