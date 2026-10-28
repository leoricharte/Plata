import Foundation

/// Nazca · TJX Rewards (Synchrony) · Estado de cuenta de tarjeta (PDF) — puerto de `bancos/tjx-tarjeta.js`.
enum NazcaTJX {
    static let moneyRx = Rx(#"^(-)?\s?\$?\s?([\d,]+\.\d{2})$"#), dashes = Rx(#"[−–]"#)
    static func money(_ s: String) -> Double? {
        guard let m = moneyRx.groups(dashes.replace(s, "-").jsTrimmed) else { return nil }
        return PDFx.r2((m[1].isEmpty ? 1 : -1) * PDFx.parseFloat(m[2].replacingOccurrences(of: ",", with: "")))
    }
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(dashes.replace(l.items.map(\.str).joined(separator: " "), "-")) }

    static let rTjx = Rx("TJX Rewards", ci: true), rCycle = Rx(#"Billing Cycle from \d{2}\/\d{2}\/\d{4} to \d{2}\/\d{2}\/\d{4}"#, ci: true), rDetail = Rx("Transaction Detail", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = doc.pages.map(\.text).joined(separator: " ")
        return rTjx.test(t) && rCycle.test(t) && rDetail.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"ending in (\d{4})"#, ci: true), pmRx = Rx(#"Billing Cycle from (\d{2})\/(\d{2})\/(\d{4}) to (\d{2})\/(\d{2})\/(\d{4})"#, ci: true)
    static let kPrev = Rx(#"^Previous Balance as of \d{2}\/\d{2}\/\d{4} \$([\d,]+\.\d{2})"#, ci: true), kEnd = Rx(#"^New Balance as of \d{2}\/\d{2}\/\d{4} \$([\d,]+\.\d{2})"#, ci: true)
    static let kPay = Rx(#"^Payments - ([\d,]+\.\d{2})"#, ci: true), kBuy = Rx(#"^Purchases\/Debits \+ ([\d,]+\.\d{2})"#, ci: true), kInt = Rx(#"^Interest Charges \+ ([\d,]+\.\d{2})"#, ci: true)
    static let kFees = Rx(#"^Fees Charged \+ ([\d,]+\.\d{2})"#, ci: true), kCred = Rx(#"^(?:Other )?Credits - ([\d,]+\.\d{2})"#, ci: true)
    static let aprRx = Rx(#"Purchases\s+N\/A\s+(\d{1,3}\.\d{1,3})\s?%"#, ci: true), ddRx = Rx(#"Payment Due Date:\s*(\d{2})\/(\d{2})\/(\d{4})"#, ci: true)
    static let mpRx = Rx(#"Total Minimum Payment Due:\s*\$([\d,]+\.\d{2})"#, ci: true), clRx = Rx(#"Credit Limit\s*\$([\d,]+)"#, ci: true)
    static let onRx = Rx("^Transaction Detail", ci: true), offRx = Rx(#"^(2026|20\d\d) Year-to-Date|^Interest Charge Calculation"#, ci: true)
    static let mmdd = Rx(#"^\d{2}\/\d{2}$"#), refRx = Rx(#"^[A-Z0-9]{14,}$"#), intRx = Rx("^INTEREST CHARGE", ci: true)
    static let feeRx = Rx(#"\b(LATE|ANNUAL|MEMBERSHIP|RETURNED PAYMENT|OVER ?LIMIT)\b.*\bFEE\b|^(LATE|ANNUAL|MEMBERSHIP) FEE"#, ci: true)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let L = doc.pages.map { NazcaPDF.lines($0, 3) }
        let all = L.map { $0.map(lineText).joined(separator: " ") }.joined(separator: " ")
        var out = Nazca.StatementResult(bank: "tjx", kind: "tarjeta", label: "TJX Rewards · Tarjeta de crédito", cur: "USD", items: [])
        var card = Nazca.StatementResult.CardInfo()
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1] }
        guard let pm = pmRx.groups(all) else { out.error = "period"; out.card = card; return out }
        let f = (m: Int(pm[1])!, d: Int(pm[2])!, y: Int(pm[3])!), t = (m: Int(pm[4])!, d: Int(pm[5])!, y: Int(pm[6])!)
        out.period = .init(from: PDFx.iso(f.y, f.m, f.d), to: PDFx.iso(t.y, t.m, t.d))

        func first(_ re: Rx) -> Double? {
            for l in L.first ?? [] { if let m = re.groups(lineText(l)) { return PDFx.r2(PDFx.parseFloat(m[1].replacingOccurrences(of: ",", with: ""))) } }
            return nil
        }
        let smPrev = first(kPrev), smEnd = first(kEnd), smPay = first(kPay), smBuy = first(kBuy), smInt = first(kInt), smFees = first(kFees), smCred = first(kCred)

        if let apr = aprRx.groups(all) { card.apr = PDFx.parseFloat(apr[1]) }
        if let dd = ddRx.groups(all) { card.dueDate = dd[3] + "-" + dd[1] + "-" + dd[2]; card.dueDay = Int(dd[2]) }
        if let mp = mpRx.groups(all) { card.minPayment = PDFx.r2(PDFx.parseFloat(mp[1].replacingOccurrences(of: ",", with: ""))) }
        if let cl = clRx.groups(all) { card.limit = PDFx.parseFloat(cl[1].replacingOccurrences(of: ",", with: "")) }

        var line = 0, sumBuy = 0.0, sumPay = 0.0, sumFee = 0.0, sumInt = 0.0, on = false
        for ls in L {
            for l in ls {
                let s = lineText(l)
                if onRx.test(s) { on = true }
                if !on { continue }
                if offRx.test(s) { on = false; continue }
                let its = l.items.map { $0.str.jsTrimmed }.filter { !$0.isEmpty }
                if its.count < 3 || !mmdd.test(its[0]) { continue }
                guard let v = money(its[its.count - 1]) else { out.unreadable += 1; continue }
                var mid = Array(its[1..<(its.count - 1)])
                if mid.count > 1 && refRx.test(mid[0]) { mid.removeFirst() }
                let desc = PDFx.clean(mid.joined(separator: " "))
                if desc.isEmpty { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                let mo = Int(its[0].jsSlice(0, 2))!, dy = Int(its[0].jsSlice(3))!, y = f.y == t.y ? f.y : (mo >= f.m ? f.y : t.y)
                let isInt = intRx.test(desc), isFee = !isInt && v > 0 && feeRx.test(desc)
                if v > 0 { if isInt { sumInt += v } else if isFee { sumFee += v } else { sumBuy += v } } else { sumPay += abs(v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: PDFx.iso(y, mo, dy), desc: desc, amount: v > 0 ? -v : abs(v), cur: "USD"))
            }
        }
        sumBuy = PDFx.r2(sumBuy); sumPay = PDFx.r2(sumPay); sumFee = PDFx.r2(sumFee); sumInt = PDFx.r2(sumInt)
        var ok: Bool?
        if let p = smPrev, let e = smEnd, smPay != nil {
            ok = PDFx.near(sumBuy, smBuy ?? 0) && PDFx.near(sumPay, (smPay ?? 0) + (smCred ?? 0)) && PDFx.near(sumFee, smFees ?? 0) && PDFx.near(sumInt, smInt ?? 0) && PDFx.near(PDFx.r2(p - sumPay + sumBuy + sumFee + sumInt), e)
        }
        out.card = card
        out.check = .init(ok: ok, end: smEnd)
        return out
    }
}
