import Foundation

/// Nazca · Interbank · Estado de cuenta de la tarjeta de crédito (PDF) — puerto de `bancos/interbank-tarjeta.js`.
/// «DETALLE DE PAGO DEL MES» con dos columnas de monto (S/ y US$) y secciones con su SUBTOTAL: estado anterior, pagos, consumos, consumos en cuotas, otros cobros.
enum NazcaInterbankTarjeta {
    static let MES: [String: Int] = ["ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "set": 9, "sep": 9, "oct": 10, "nov": 11, "dic": 12]
    static let NUM = Rx(#"^-?[\d,]+\.\d{2}$"#)

    static let rDetalle = Rx("detalle de pago del mes"), rTarjeta = Rx("tarjeta de credito"), rMin = Rx("pago minimo"), rLinea = Rx("linea de credito"), rIb = Rx("interbank")

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.norm(PDFx.flat(doc))
        return rDetalle.test(t) && rTarjeta.test(t) && rMin.test(t) && rLinea.test(t) && rIb.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"(\d{4}) - (SOLES|D[ÓO]LARES)"#, ci: true), startD = Rx(#"^D"#, ci: true)
    static let pmRx = Rx(#"del (\d{2})\/(\d{2})\/(\d{4}) al cierre de (\d{2})\/(\d{2})\/(\d{4})"#, ci: true)
    static let limRx = Rx(#"Tu L[ií]nea de Cr[eé]dito es de:.*?S\/\s?([\d,]+\.\d{2})"#, ci: true)
    static let sMoney = Rx(#"^S\/\s?[\d,]+\.\d{2}"#), moneyIn = Rx(#"([\d,]+\.\d{2})"#)
    static let rDue = Rx(#"^ultimo dia de pago"#), dmyRx = Rx(#"(\d{2})\/(\d{2})\/(\d{4})"#)
    static let rTea = Rx(#"^\*?\s*tea de consumos soles y dolares"#), teaRx = Rx(#"^soles\s+(\d{1,3}(?:\.\d{1,2})?)\s?%$"#, ci: true)
    static let SEC: [(String, Rx)] = [("pay", Rx(#"^pagos realizados"#)), ("buy", Rx(#"^tus consumos(?! en cuotas)"#)), ("cuo", Rx(#"^tus consumos en cuotas"#)), ("otr", Rx(#"^otros cobros"#))]
    static let rDetalleStart = Rx(#"^detalle de pago del mes"#)
    static let rInfo = Rx(#"^informacion sobre tu tarjeta"#), rPrevTitle = Rx(#"^tu estado de cuenta anterior"#), rSubtotal = Rx(#"^subtotal"#), rPagoMes = Rx(#"^pago del mes"#), rMinMes = Rx(#"^pago minimo del mes"#), rDebias = Rx(#"^deb[ií]as"#)
    static let rowDate = Rx(#"^(\d{1,2})-([A-Za-zÁ-ú]{3})$"#), stopDesc = Rx(#"^[\d.,%\/ \-]+$"#), threeDigits = Rx(#"^\d{3}$"#)
    static let parenTail = Rx(#"\s*\([^)]*$"#), paseRx = Rx(#"\s*\(PASE A CUOT\)?"#, ci: true)

    struct Line { var it: [PdfItem]; var txt: String }

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let all = PDFx.flat(doc)
        var out = Nazca.StatementResult(bank: "interbank", kind: "tarjeta", label: "Interbank · Tarjeta de crédito", cur: "PEN", items: [])
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1]; if startD.test(l4[2]) { out.cur = "USD" } }
        guard let pm = pmRx.groups(all) else { out.error = "period"; out.card = .init(); return out }
        let f = (d: Int(pm[1])!, m: Int(pm[2])!, y: Int(pm[3])!), e = (d: Int(pm[4])!, m: Int(pm[5])!, y: Int(pm[6])!)
        let periodTo = PDFx.iso(e.y, e.m, e.d)
        out.period = .init(from: PDFx.iso(f.y, f.m, f.d), to: periodTo)
        var L: [Line] = []
        for pg in doc.pages { for l in NazcaPDF.lines(pg, 3) { L.append(Line(it: l.items, txt: PDFx.clean(l.items.map(\.str).joined(separator: " ")))) } }

        var card = Nazca.StatementResult.CardInfo()
        var debt: Double?
        let lim = limRx.groups(PDFx.squash(all))
        if let row3 = L.first(where: { $0.it.filter { sMoney.test($0.str) }.count >= 3 }) {
            let v = row3.it.filter { sMoney.test($0.str) }.map { PDFx.numSp(moneyIn.groups($0.str)![1]) }
            card.limit = v[0]; debt = v[2]
        } else if let lim { card.limit = PDFx.numSp(lim[1]) }
        if let iDue = L.firstIndex(where: { rDue.test(PDFx.norm($0.txt)) }) {
            for x in PDFx.slice(L, iDue + 1, iDue + 6) { if let m = dmyRx.groups(x.txt) { card.dueDate = "\(m[3])-\(m[2])-\(m[1])"; card.dueDay = Int(m[1]); break } }
        }
        if let iTea = L.firstIndex(where: { rTea.test(PDFx.norm($0.txt)) }) {
            for x in PDFx.slice(L, iTea + 1, iTea + 3) { if let m = teaRx.groups(x.txt) { card.apr = PDFx.parseFloat(m[1]); break } }
        }

        func isUsd(_ i: PdfItem) -> Bool { i.x + i.w > 520 }
        func col(_ items: [PdfItem]) -> Cur2<Double?> {
            var v = Cur2<Double?>(nil, nil)
            for i in items where NUM.test(i.str) { v[isUsd(i) ? "USD" : "PEN"] = PDFx.numSp(i.str) }
            return v
        }
        var sec = "", line = 0, started = false
        var prev = Cur2<Double?>(nil, nil)
        var sums: [String: Cur2<Double>] = ["pay": Cur2(0, 0), "buy": Cur2(0, 0), "cuo": Cur2(0, 0), "otr": Cur2(0, 0)]
        var sub: [String: Cur2<Double?>] = [:]
        var total: Cur2<Double?>?, minPay: Cur2<Double?>?
        for x in L {
            let nt = PDFx.norm(x.txt)
            if rDetalleStart.test(nt) { started = true; continue }
            if !started { continue }
            if rInfo.test(nt) { break }
            if rPrevTitle.test(nt) { sec = "prev"; continue }
            if let hit = SEC.first(where: { $0.1.test(nt) && x.it[0].x < 70 }) { sec = hit.0; continue }
            if rSubtotal.test(nt) { if !sec.isEmpty && sec != "prev" { sub[sec] = col(x.it) }; continue }
            if rPagoMes.test(nt) { total = col(x.it); sec = ""; continue }
            if rMinMes.test(nt) { minPay = col(x.it); continue }
            if sec == "prev" { if rDebias.test(nt) { prev = col(x.it) }; continue }
            if sec.isEmpty { continue }
            guard let dm = rowDate.groups(x.it[0].str.jsTrimmed), x.it[0].x <= 70, let mo = MES[PDFx.norm(dm[2])] else { continue }
            let rest = Array(x.it.dropFirst())
            let a = col(rest)
            let y = f.y == e.y ? f.y : (mo >= f.m ? f.y : e.y)
            var date = "\(y)-\(PDFx.pad(mo))-\(PDFx.pad(Int(dm[1])!))"
            var descIt: [String] = []
            for i in rest { if stopDesc.test(i.str.jsTrimmed) { break }; descIt.append(i.str) }
            var desc = PDFx.clean(descIt.joined(separator: " "))
            if desc.isEmpty { out.unreadable += 1; continue }
            if sec == "cuo" {
                let nums = rest.filter { threeDigits.test($0.str.jsTrimmed) }
                let pact = nums.count > 0 ? Int(nums[0].str) ?? 0 : 0, por = nums.count > 1 ? Int(nums[1].str) ?? 0 : 0
                desc = paseRx.replace(parenTail.replace(desc, ""), "").jsTrimmed
                if pact != 0 && por != 0 && pact >= por { desc += " · cuota \(pact - por + 1) de \(pact)" }
                date = periodTo
            }
            var any = false
            for cur in ["PEN", "USD"] {
                guard let v = a[cur] else { continue }
                if v == 0 { if cur == "PEN" || a.pen == nil { out.zero += 1 }; continue }
                any = true
                sums[sec]![cur] = PDFx.r2(sums[sec]![cur] + v)
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: sec == "pay" ? abs(v) : -abs(v), cur: cur))
            }
            if !any && a.pen == nil && a.usd == nil { out.unreadable += 1 }
        }
        var pays = Cur2(0.0, 0.0)
        for cur in ["PEN", "USD"] { pays[cur] = -out.items.filter { $0.cur == cur && $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
        let main = out.items.contains { $0.cur == "PEN" } || !out.items.contains { $0.cur == "USD" } ? "PEN" : "USD"
        out.cur = main
        let have = total != nil && sub["pay"] != nil && prev.pen != nil
        func rowsOk(_ cur: String) -> Bool {
            guard let sp = sub["pay"], let pv = prev[cur], let spc = sp[cur] else { return false }
            var ok = PDFx.near(PDFx.r2(pv + pays[cur]), spc)
            for s in ["buy", "cuo", "otr"] {
                if let st = sub[s].flatMap({ $0[cur] }) { if !PDFx.near(st, sums[s]![cur]) { ok = false } }
                else if sums[s]![cur] != 0 { ok = false }
            }
            var st = 0.0
            for s in ["pay", "buy", "cuo", "otr"] { if let v = sub[s].flatMap({ $0[cur] }) { st += v } }
            guard let tot = total, let tc = tot[cur] else { return false }
            return ok && PDFx.near(PDFx.r2(st), tc)
        }
        if let mp = minPay, let v = mp.pen { card.minPayment = v }
        let end: Double? = debt != nil && main == "PEN" ? debt : total.flatMap { $0[main] }
        out.card = card
        out.check = .init(ok: have ? (rowsOk("PEN") && rowsOk("USD")) : nil, end: end)
        return out
    }
}
