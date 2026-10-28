import Foundation

/// Nazca · iO (Perú) · Estado de cuenta de la tarjeta de crédito (PDF) — puerto de `bancos/io-tarjeta.js`.
/// «Detalle de movimientos» (Abonos · Consumos directos · Consumos en cuotas; columnas SOLES / DÓLARES) y «Tu pago del mes está compuesto por…».
enum NazcaIO {
    static let MES: [String: Int] = ["ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "set": 9, "sep": 9, "oct": 10, "nov": 11, "dic": 12]
    static let NUM = Rx(#"^-?[\d,]+\.\d{2}$"#)

    static let rTarjeta = Rx(#"tarjeta de credito io\b"#), rDetalle = Rx("detalle de movimientos"), rCiclo = Rx("ciclo de facturacion"), rMin = Rx("pago minimo")

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.norm(PDFx.flat(doc))
        return rTarjeta.test(t) && rDetalle.test(t) && rCiclo.test(t) && rMin.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"\*{4} \*{4} \*{4} (\d{4})"#), pmRx = Rx(#"del (\d{2})\/(\d{2})\/(\d{4}) hasta el (\d{2})\/(\d{2})\/(\d{4})"#, ci: true)
    static let solesRx = Rx(#"^S\/\s?([\d,]+\.\d{2})$"#), teaRx = Rx(#"TEA de Inter[eé]s compensatorio\s*(\d{1,3}(?:\.\d{1,2})?)\s?%"#, ci: true)
    static let dueRx = Rx(#"^(\d{1,2}) ([a-z]{3}) (\d{2})$"#, ci: true), rMinLine = Rx(#"^pago minimo\b"#)
    static let rResumen = Rx(#"^resumen de movimientos"#), rAbonos = Rx(#"^abonos$"#), rDir = Rx(#"^consumos directos"#), rCuo = Rx(#"^consumos en cuotas"#), rPlan = Rx(#"^plan de cuotas"#)
    static let fechaRx = Rx(#"^FECHA$"#), dolaresRx = Rx(#"^D[OÓ]LARES$"#, ci: true), rSubtotal = Rx(#"^subtotal"#)
    static let rowDate = Rx(#"^(\d{1,2})-([A-Za-zÁ-ú]{3})$"#), stopDesc = Rx(#"^[\d.,%\/ \-]+$"#), signRx = Rx(#"^[+\-=]$"#)
    static let rCompuesto = Rx("tu pago del mes esta compuesto")
    static let rPrev = Rx("saldo pendiente"), rAb = Rx("abonos"), rDir2 = Rx("consumos directos"), rCuo2 = Rx("consumos en cuotas"), rTot = Rx("pago total"), rMin2 = Rx("pago minimo")

    static func soles(_ s: String) -> Double? { solesRx.groups(s).map { PDFx.numSp($0[1]) } }

    struct Line { var it: [PdfItem]; var txt: String }

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let all = PDFx.flat(doc)
        var out = Nazca.StatementResult(bank: "io", kind: "tarjeta", label: "iO · Tarjeta de crédito", cur: "PEN", items: [])
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1] }
        guard let pm = pmRx.groups(all) else { out.error = "period"; out.card = .init(); return out }
        let f = (d: Int(pm[1])!, m: Int(pm[2])!, y: Int(pm[3])!), e = (d: Int(pm[4])!, m: Int(pm[5])!, y: Int(pm[6])!)
        let periodTo = PDFx.iso(e.y, e.m, e.d)
        out.period = .init(from: PDFx.iso(f.y, f.m, f.d), to: periodTo)
        var L: [Line] = []
        for pg in doc.pages { for l in NazcaPDF.lines(pg, 3) { L.append(Line(it: l.items, txt: PDFx.clean(l.items.map(\.str).joined(separator: " ")))) } }

        var card = Nazca.StatementResult.CardInfo()
        if let row3 = L.first(where: { $0.it.count >= 3 && $0.it.prefix(3).allSatisfy { soles($0.str) != nil } }) { card.limit = soles(row3.it[0].str) }
        if let tea = teaRx.groups(all) { card.apr = PDFx.parseFloat(tea[1]) }
        for x in L {
            if let m = dueRx.groups(x.txt), let mo = MES[m[2].lowercased()] {
                card.dueDate = "\(2000 + Int(m[3])!)-\(PDFx.pad(mo))-\(PDFx.pad(Int(m[1])!))"; card.dueDay = Int(m[1]); break
            }
        }
        if let iMin = L.firstIndex(where: { rMinLine.test(PDFx.norm($0.txt)) && $0.it.count <= 3 }) {
            if let nx = PDFx.slice(L, iMin + 1, iMin + 3).first(where: { !$0.it.isEmpty && soles($0.it[0].str) != nil }) { card.minPayment = soles(nx.it[0].str) }
        }

        // Movimientos: tablas con columnas SOLES / DÓLARES
        var sec = "", bound = 495.0, line = 0
        var buySum = Cur2(0.0, 0.0), paySum = Cur2(0.0, 0.0)
        for x in L {
            let nt = PDFx.norm(x.txt)
            if rResumen.test(nt) { break }
            if rAbonos.test(nt) { sec = "ab"; continue }
            if rDir.test(nt) { sec = "dir"; continue }
            if rCuo.test(nt) { sec = "cuo"; continue }
            if rPlan.test(nt) { sec = ""; continue }
            if x.it.contains(where: { fechaRx.test($0.str) }) { if let d = x.it.first(where: { dolaresRx.test($0.str) }) { bound = d.x - 14 }; continue }
            if sec.isEmpty { continue }
            if rSubtotal.test(nt) { continue }
            guard let dm = rowDate.groups(x.it[0].str.jsTrimmed), x.it[0].x <= 70, let mo = MES[PDFx.norm(dm[2])] else { continue }
            let rest = Array(x.it.dropFirst())
            let amt = rest.filter { NUM.test($0.str) }
            guard let lastI = amt.last else { out.unreadable += 1; continue }
            let cur = lastI.x >= bound ? "USD" : "PEN", v = abs(PDFx.numSp(lastI.str))
            var descIt: [String] = []
            for i in rest { if stopDesc.test(i.str.jsTrimmed) { break }; descIt.append(i.str) }
            let desc = PDFx.clean(descIt.joined(separator: " "))
            if desc.isEmpty { out.unreadable += 1; continue }
            if v == 0 || v.isNaN { out.zero += 1; continue }
            let y = f.y == e.y ? f.y : (mo >= f.m ? f.y : e.y), date = "\(y)-\(PDFx.pad(mo))-\(PDFx.pad(Int(dm[1])!))"
            let credit = sec == "ab"
            if credit { paySum[cur] += v } else { buySum[cur] += v }
            line += 1
            out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: credit ? v : -v, cur: cur))
        }

        // Resumen del mes
        var fees = Cur2(0.0, 0.0)
        var prevS: Cur2<Double>?, ab: Cur2<Double>?, dir: Cur2<Double>?, cuo: Cur2<Double>?, tot: Cur2<Double>?, mn: Cur2<Double>?
        var inSum = false
        for x in L {
            let nt = PDFx.norm(x.txt)
            if rCompuesto.test(nt) { inSum = true; continue }
            if !inSum { continue }
            let v = x.it.filter { NUM.test($0.str) }
            if v.count < 2 { continue }
            let labelItems = x.it.filter { !NUM.test($0.str) && !signRx.test($0.str.jsTrimmed) }
            let label = PDFx.norm(labelItems.map(\.str).joined(separator: " "))
            let p = PDFx.numSp(v[0].str), d = PDFx.numSp(v[1].str)
            let sign = signRx.test(x.it[0].str.jsTrimmed) ? x.it[0].str.jsTrimmed : ""
            let pair = Cur2(p, d)
            if rPrev.test(label) { prevS = pair }
            else if rAb.test(label) { ab = pair }
            else if rDir2.test(label) { dir = pair }
            else if rCuo2.test(label) { cuo = pair }
            else if rTot.test(label) { tot = pair }
            else if rMin2.test(label) { mn = pair }
            else if sign == "+" || sign == "-" {
                let k = sign == "-" ? -1.0 : 1.0
                let nm = PDFx.clean(labelItems.map(\.str).joined(separator: " "))
                for (cur, val) in [("PEN", p), ("USD", d)] where val != 0 {
                    fees[cur] += k * val
                    line += 1
                    out.items.append(Nazca.Item(line: line, date: periodTo, desc: String(nm.prefix(1)) + nm.dropFirst().lowercased(), amount: -k * val, cur: cur))
                }
            }
        }
        if card.minPayment == nil, let mn { card.minPayment = mn.pen }
        let main = out.items.contains { $0.cur == "PEN" } || !out.items.contains { $0.cur == "USD" } ? "PEN" : "USD"
        out.cur = main
        let have = prevS != nil && tot != nil && ab != nil && dir != nil
        func chk(_ cur: String) -> Bool {
            let buy = PDFx.r2(buySum[cur]), pay = PDFx.r2(paySum[cur]), fee = PDFx.r2(fees[cur])
            return PDFx.near(pay, ab![cur]) && PDFx.near(buy, dir![cur] + (cuo?[cur] ?? 0)) && PDFx.near(PDFx.r2(prevS![cur] + buy + fee - pay), tot![cur])
        }
        out.card = card
        out.check = .init(ok: have ? (chk("PEN") && chk("USD")) : nil, end: tot?[main])
        return out
    }
}
