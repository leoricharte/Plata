import Foundation

/// Nazca · BCP · Estado de cuenta de la tarjeta de crédito Visa (PDF) — puerto de `bancos/bcp-tarjeta.js`.
/// Va de arriba a abajo como «saldo anterior → movimientos → sub total → comisiones → monto total facturado», con dos columnas de monto (Soles y Dólares).
/// Pago → positivo; consumo, cuota y comisión → negativo. La cuota del mes se importa desglosada (plan de cuotas) a la fecha de cierre.
enum NazcaBCPTarjeta {
    static let MES: [String: Int] = ["ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "set": 9, "sep": 9, "oct": 10, "nov": 11, "dic": 12]
    static let AMT = Rx(#"^[\d,]+\.\d{2}-?$"#)

    static func sentence(_ s: String) -> String { let t = s.lowercased(); return t.prefix(1).uppercased() + t.dropFirst() }

    static let rTitle = Rx("estado de cuenta tarjeta"), rCiclo = Rx("ciclo de facturacion"), rLimite = Rx("fecha limite de pago"), rLinea = Rx("linea de credito"), rSaldo = Rx("saldo anterior"), rBcp = Rx("bcp")

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.norm(PDFx.flat(doc))
        return rTitle.test(t) && rCiclo.test(t) && rLimite.test(t) && rLinea.test(t) && rSaldo.test(t) && rBcp.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"\d{4}-\d{2}[X*]{2}-[X*]{4}-(\d{4})"#, ci: true)
    static let cycleRx = Rx(#"(\d{2})\/(\d{2})\/(\d{2})\s+(\d{2})\/(\d{2})\/(\d{2})"#)
    static let dateOnly = Rx(#"^(\d{2})\/(\d{2})\/(\d{2})$"#)
    static let limLine = Rx(#"^linea de credito s\/ - linea utilizada"#), limNum = Rx(#"^[\d,]+(\.\d{2})?$"#)
    static let minLine = Rx(#"^pago minimo s\/ pago total s\/"#), comprasLine = Rx(#"^compras\b"#), aprRx = Rx(#"(\d{1,3}\.\d{2})\s?%"#)
    static let rSaldoStart = Rx(#"^saldo anterior"#), rSub = Rx(#"^sub total"#), rTotal = Rx(#"^monto total facturado"#), rPlan = Rx(#"^detalle plan cuotas (soles|dolares)"#)
    static let rComo = Rx(#"^como esta compuesta su deuda"#), rPlanTot = Rx(#"^total (soles|dolares)"#)
    static let isDateRx = Rx(#"^\d{2}[A-Za-zÁ-ú]{3}$"#), cuotaNo = Rx(#"^\d{2}\/\d{2}$"#), typeRx = Rx(#"^(CONSUMO|PAGO|CARGO|ABONO)$"#), endsDash = Rx(#"-$"#), country = Rx(#"^[A-Z]{2}$"#)

    struct Line { var it: [PdfItem]; var txt: String }

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let all = PDFx.flat(doc)
        var out = Nazca.StatementResult(bank: "bcp", kind: "tarjeta", label: "BCP · Tarjeta de crédito", cur: "PEN", items: [])
        if let m = l4Rx.groups(all) { out.last4 = m[1] }
        guard let pm = cycleRx.groups(all) else { out.error = "period"; out.card = .init(); return out }
        let e = (d: Int(pm[4])!, m: Int(pm[5])!, y: 2000 + Int(pm[6])!)
        let periodTo = PDFx.iso(e.y, e.m, e.d)
        out.period = .init(from: PDFx.iso(2000 + Int(pm[3])!, Int(pm[2])!, Int(pm[1])!), to: periodTo)
        var card = Nazca.StatementResult.CardInfo()
        var used: Double?
        var L: [Line] = []
        for pg in doc.pages { for l in NazcaPDF.lines(pg, 3) { L.append(Line(it: l.items, txt: PDFx.clean(l.items.map(\.str).joined(separator: " ")))) } }
        func col(_ i: PdfItem) -> String { i.x + i.w > 540 ? "USD" : "PEN" }
        func uniq(_ its: [PdfItem]) -> [PdfItem] {
            its.enumerated().filter { (k, i) in !its.enumerated().contains { (q, j) in q < k && j.str == i.str && abs(j.x - i.x) < 1 && abs(j.w - i.w) < 1 } }.map(\.element)
        }

        for k in L.indices {
            let nt = PDFx.norm(L[k].txt)
            if rLimite.test(nt) && card.dueDate == nil {
                for x in PDFx.slice(L, k + 1, k + 3) {
                    if let m = dateOnly.groups(x.it[x.it.count - 1].str) { card.dueDate = "\(2000 + Int(m[3])!)-\(m[2])-\(m[1])"; card.dueDay = Int(m[1]); break }
                }
            }
            if limLine.test(nt) && (card.limit ?? 0) == 0, k + 1 < L.count {
                let v = uniq(L[k + 1].it).filter { limNum.test($0.str) && $0.x < 300 }.map { PDFx.numDash($0.str) }
                if v.count >= 2 { card.limit = v[0]; used = v[1] }
            }
            if minLine.test(nt) && card.minPayment == nil {
                for nx in PDFx.slice(L, k + 1, k + 4) {
                    let v = nx.it.filter { AMT.test($0.str) && $0.x < 250 }.map { PDFx.numDash($0.str) }
                    if let f = v.first { card.minPayment = f; break }
                }
            }
            if comprasLine.test(nt) && card.apr == nil && L[k].it.count >= 4, let m = aprRx.groups(L[k].txt) { card.apr = PDFx.parseFloat(m[1]) }
        }

        var prev = Cur2(0.0, 0.0), cargo = Cur2(0.0, 0.0)
        var buy = Cur2(0.0, 0.0), pay = Cur2(0.0, 0.0), cuo = Cur2(0.0, 0.0), fee = Cur2(0.0, 0.0)
        var planTot = Cur2<Double?>(nil, nil)
        var sub: Cur2<Double?>?, total: Cur2<Double?>?
        var sec = "", plan = "PEN", line = 0, seen = false
        func yearOf(_ mo: Int) -> Int { mo > e.m ? e.y - 1 : e.y }
        func isDate(_ i: PdfItem) -> Bool { isDateRx.test(i.str) && MES[PDFx.norm(i.str.jsSlice(2))] != nil && i.x < 70 }

        for x in L {
            let nt = PDFx.norm(x.txt)
            if rSaldoStart.test(nt) { sec = "mov"; seen = true; for i in x.it where AMT.test(i.str) { prev[col(i)] = PDFx.numDash(i.str) }; continue }
            if !seen { continue }
            if rSub.test(nt) { var s = Cur2<Double?>(nil, nil); for i in x.it where AMT.test(i.str) { s[col(i)] = PDFx.numDash(i.str) }; sub = s; sec = "fee"; continue }
            if rTotal.test(nt) { var s = Cur2<Double?>(nil, nil); for i in x.it where AMT.test(i.str) { s[col(i)] = PDFx.numDash(i.str) }; total = s; sec = ""; continue }
            if let pl = rPlan.groups(nt) { sec = "plan"; plan = pl[1] == "soles" ? "PEN" : "USD"; continue }
            if rComo.test(nt) { break }
            if sec == "plan" && rPlanTot.test(nt) {
                let a = x.it.filter { AMT.test($0.str) }
                if let l = a.last { planTot[plan] = PDFx.numDash(l.str) }
                continue
            }
            if sec == "plan" {
                if !isDate(x.it[0]) { continue }
                let a = x.it.filter { AMT.test($0.str) }
                guard let la = a.last else { out.unreadable += 1; continue }
                let v = PDFx.numDash(la.str)
                let nro = x.it.first { cuotaNo.test($0.str) }
                let desc = PDFx.clean(x.it.filter { $0.x > 130 && $0.x < 250 && !AMT.test($0.str) }.map(\.str).joined(separator: " "))
                if desc.isEmpty || v == 0 || v.isNaN { out.unreadable += 1; continue }
                var suffix = ""
                if let nro { let nn = nro.str.split(separator: "/").map { Int($0) ?? 0 }; suffix = " · cuota \(nn[0]) de \(nn[1])" }
                line += 1
                out.items.append(Nazca.Item(line: line, date: periodTo, desc: desc + suffix, amount: -v, cur: plan))
                cuo[plan] = PDFx.r2(cuo[plan] + v); continue
            }
            if sec == "mov" {
                if !isDate(x.it[0]) { continue }
                let a = x.it.filter { AMT.test($0.str) && $0.x > 465 }
                let type = x.it.first { typeRx.test($0.str) }?.str ?? ""
                guard let am = a.last else { out.unreadable += 1; continue }
                let cur = col(am), v = PDFx.numDash(am.str), credit = endsDash.test(am.str) || type == "PAGO" || type == "ABONO"
                if type == "CARGO" { cargo[cur] = PDFx.r2(cargo[cur] + v); continue }
                let second = x.it.dropFirst().first { isDateRx.test($0.str) }
                let dmy = (second ?? x.it[0]).str
                let mo = MES[PDFx.norm(dmy.jsSlice(2))] ?? 0
                let date = "\(yearOf(mo))-\(PDFx.pad(mo))-\(dmy.jsSlice(0, 2))"
                let parts = x.it.filter { $0.x >= 130 && $0.x < 400 && !($0.x >= 315 && country.test($0.str)) }.map(\.str)
                let desc = PDFx.clean(parts.joined(separator: " "))
                if desc.isEmpty { out.unreadable += 1; continue }
                if v == 0 || v.isNaN { out.zero += 1; continue }
                if credit { pay[cur] = PDFx.r2(pay[cur] + v) } else { buy[cur] = PDFx.r2(buy[cur] + v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: credit ? v : -v, cur: cur)); continue
            }
            if sec == "fee" {
                let a = x.it.filter { AMT.test($0.str) && $0.x > 465 }
                if a.isEmpty { continue }
                let desc = PDFx.clean(x.it.filter { $0.x >= 130 && $0.x < 465 && !AMT.test($0.str) }.map(\.str).joined(separator: " "))
                if desc.isEmpty { continue }
                for am in a {
                    let v = PDFx.numDash(am.str), cur = col(am)
                    if v == 0 || v.isNaN { continue }
                    fee[cur] = PDFx.r2(fee[cur] + v)
                    line += 1
                    out.items.append(Nazca.Item(line: line, date: periodTo, desc: sentence(desc), amount: -v, cur: cur))
                }
            }
        }
        let main = out.items.contains { $0.cur == "PEN" } || !out.items.contains { $0.cur == "USD" } ? "PEN" : "USD"
        out.cur = main
        let have = sub != nil && total != nil
        func chk(_ cur: String) -> Bool {
            let pre = PDFx.r2(prev[cur] + buy[cur] - pay[cur] + cuo[cur])
            let s = sub![cur] ?? 0, t = total![cur] ?? 0
            return PDFx.near(pre, s) && PDFx.near(PDFx.r2(s + fee[cur]), t) && PDFx.near(cuo[cur], cargo[cur]) && (planTot[cur] == nil || PDFx.near(planTot[cur]!, cuo[cur]))
        }
        let end: Double? = used != nil && main == "PEN" ? used : (total.flatMap { $0[main] })
        out.card = card
        out.check = .init(ok: have ? (chk("PEN") && chk("USD")) : nil, end: end)
        return out
    }
}
