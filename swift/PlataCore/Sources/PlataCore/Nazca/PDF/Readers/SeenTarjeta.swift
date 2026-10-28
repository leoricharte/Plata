import Foundation

/// Nazca · Seen · «Credit Card Statement» (PDF) — puerto de `bancos/seen-tarjeta.js`.
/// Secciones: Payments, Refunds and Other Credits · Purchases · Fees · Interest Charged; todo positivo, el signo lo da la sección.
enum NazcaSeen {
    static let D = Rx(#"^(\d{2})\/(\d{2})\/(\d{4})$"#), moneyRx = Rx(#"^(-)?\$([\d,]+\.\d{2})$"#), dashes = Rx(#"[−–]"#), card4 = Rx(#"^\*\d{4}$"#)
    static func iso(_ m: [String]) -> String { m[3] + "-" + m[1] + "-" + m[2] }
    static func money(_ s: String) -> Double? {
        guard let m = moneyRx.groups(s.jsTrimmed) else { return nil }
        return PDFx.r2((m[1].isEmpty ? 1 : -1) * PDFx.parseFloat(m[2].replacingOccurrences(of: ",", with: "")))
    }
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(l.items.map(\.str).joined(separator: " ")) }

    static let rSeen = Rx("Seen Credit Card", ci: true), rStmt = Rx("Credit Card Statement", ci: true), rBill = Rx("Bill Period", ci: true), rPosted = Rx("Posted Date", ci: true), rPrev = Rx("Previous Balance", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = doc.pages.map(\.text).joined(separator: " ")
        return rSeen.test(t) && rStmt.test(t) && rBill.test(t) && rPosted.test(t) && rPrev.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"Account Number \*(\d{4})"#, ci: true), bpRx = Rx(#"Bill Period:\s*(\d{2})\/(\d{2})\/(\d{4}) - (\d{2})\/(\d{2})\/(\d{4})"#)
    static let gPrev = Rx(#"Previous Balance\s+(\$[\d,]+\.\d{2})"#), gPay = Rx(#"Payments\s+(\$[\d,]+\.\d{2})"#), gOth = Rx(#"Other Credits\s+(\$[\d,]+\.\d{2})"#), gBuy = Rx(#"Purchases\s+(\$[\d,]+\.\d{2})"#)
    static let gInt = Rx(#"Interest Charged\s+(\$[\d,]+\.\d{2})"#), gFee = Rx(#"Fee Charged\s+(\$[\d,]+\.\d{2})"#), gEnd = Rx(#"New Balance\s+(\$[\d,]+\.\d{2})"#), gLim = Rx(#"Credit Limit\s+(\$[\d,]+\.\d{2})"#)
    static let aprRx = Rx(#"Purchases\s+(\d{1,3}\.\d{1,2})%"#), cardAcct = Rx("Card Account Number"), dueHead = Rx("Payment Due Date")
    static let secCr = Rx(#"^Payments, Refunds, and Other Credits$"#, ci: true), secBuy = Rx(#"^Purchases$"#, ci: true), secFee = Rx(#"^Fees$"#, ci: true), secInt = Rx(#"^Interest Charged$"#, ci: true)
    static let endSec = Rx(#"^2026 Totals|^Interest Charge Calculation"#, ci: true), intRow = Rx(#"^Interest Charge"#, ci: true)
    static let notDesc = Rx(#"^(Payments, Refunds|Purchases$|Fees$|Interest Charged$|Total |TOTAL )"#, ci: true)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let L = doc.pages.map { NazcaPDF.lines($0, 3) }
        let all = dashes.replace(L.map { $0.map(lineText).joined(separator: " ") }.joined(separator: " "), "-")
        var out = Nazca.StatementResult(bank: "seen", kind: "tarjeta", label: "Seen · Tarjeta de crédito", cur: "USD", items: [])
        out.card = .init()
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1] }
        guard let bp = bpRx.groups(all) else { out.error = "period"; return out }
        let periodTo = bp[6] + "-" + bp[4] + "-" + bp[5]
        out.period = .init(from: bp[3] + "-" + bp[1] + "-" + bp[2], to: periodTo)

        func g(_ re: Rx) -> Double? { re.groups(all).flatMap { money($0[1]) } }
        let smPrev = g(gPrev), smPay = g(gPay), smOth = g(gOth), smBuy = g(gBuy), smInt = g(gInt), smFee = g(gFee), smEnd = g(gEnd)
        var card = Nazca.StatementResult.CardInfo()
        if let lim = g(gLim) { card.limit = lim }
        if let apr = aprRx.groups(all) { card.apr = PDFx.parseFloat(apr[1]) }
        let first = L.first ?? []
        if let hi = first.firstIndex(where: { cardAcct.test(lineText($0)) && dueHead.test(lineText($0)) }), hi + 1 < first.count {
            let its = first[hi + 1].items.map(\.str)
            let ds = its.filter { D.test($0) }, ms = its.compactMap { money($0) }
            if ds.count >= 2, let m = D.groups(ds[ds.count - 1]) { card.dueDate = iso(m); card.dueDay = Int(m[2]) }
            if ms.count >= 2 { card.minPayment = ms[1] }
        }

        var sec = "", line = 0
        var sums: [String: Double] = ["cr": 0, "buy": 0, "fee": 0, "int": 0]
        /// Una descripción larga se parte en tres líneas: la primera mitad ENCIMA de la fila y el resto DEBAJO. Se unen.
        func descOnly(_ l: PdfLine?) -> Bool {
            guard let l, !l.items.isEmpty else { return false }
            return l.items.allSatisfy { $0.x > 200 && !D.test($0.str) && money($0.str) == nil && !card4.test($0.str) } && !notDesc.test(lineText(l))
        }
        for ls in L.dropFirst() {
            var used = Set<Int>()
            for li in ls.indices {
                let l = ls[li]
                if used.contains(li) { continue }
                let t = lineText(l)
                if secCr.test(t) { sec = "cr"; continue }
                if secBuy.test(t) { sec = "buy"; continue }
                if secFee.test(t) { sec = "fee"; continue }
                if secInt.test(t) { sec = "int"; continue }
                if endSec.test(t) { sec = ""; continue }
                if sec.isEmpty { continue }
                guard let ai = l.items.lastIndex(where: { money($0.str) != nil }), let v = money(l.items[ai].str) else { continue }
                let d1 = D.groups(l.items[0].str), d2 = l.items.count > 1 ? D.groups(l.items[1].str) : nil
                var date: String, desc: String
                if let d1 {
                    date = iso(d2 ?? d1)
                    desc = PDFx.clean(l.items.enumerated().filter { $0.offset > (d2 != nil ? 1 : 0) && $0.offset != ai && !card4.test($0.element.str) }.map(\.element.str).joined(separator: " "))
                } else if sec == "int" && intRow.test(l.items[0].str) { date = periodTo; desc = l.items[0].str }
                else { continue }
                if d1 != nil && desc.isEmpty {
                    let up: PdfLine? = li > 0 && !used.contains(li - 1) && descOnly(ls[li - 1]) ? ls[li - 1] : nil
                    let dn: PdfLine? = li + 1 < ls.count && descOnly(ls[li + 1]) ? ls[li + 1] : nil
                    if up != nil || dn != nil {
                        desc = PDFx.clean([up, dn].compactMap { $0 }.map(lineText).joined(separator: " "))
                        if dn != nil { used.insert(li + 1) }
                        if up != nil { used.insert(li - 1) }
                    }
                }
                if desc.isEmpty { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                sums[sec] = PDFx.r2(sums[sec]! + abs(v))
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: sec == "cr" ? abs(v) : -abs(v), cur: "USD"))
            }
        }
        var ok: Bool?
        if let p = smPrev, let pay = smPay, let oth = smOth, let buy = smBuy, let it = smInt, let fee = smFee, let end = smEnd {
            ok = PDFx.near(sums["cr"]!, pay + oth) && PDFx.near(sums["buy"]!, buy) && PDFx.near(sums["int"]!, it) && PDFx.near(sums["fee"]!, fee) && PDFx.near(PDFx.r2(p - pay - oth + buy + it + fee), end)
        }
        out.card = card
        out.check = .init(ok: ok, end: smEnd)
        return out
    }
}
