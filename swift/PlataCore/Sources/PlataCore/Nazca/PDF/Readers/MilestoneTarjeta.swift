import Foundation

/// Nazca · Milestone Mastercard (Concora Credit) · Estado de cuenta de tarjeta (PDF) — puerto de `bancos/milestone-tarjeta.js`.
/// El signo menos va DETRÁS del importe («8.02-» es un crédito); las fechas no traen año (se deduce de la fecha de cierre).
enum NazcaMilestone {
    static let MES: [String: Int] = ["january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12]
    static let AMT = Rx(#"^([\d,]+\.\d{2})(-)?$"#), dashes = Rx(#"[−–]"#)
    static func num(_ s: String) -> Double { PDFx.parseFloat(s.replacingOccurrences(of: ",", with: "")) }
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(dashes.replace(l.items.map(\.str).joined(separator: " "), "-")) }

    static let rBank = Rx(#"mymilestonecard\.com|Milestone"#, ci: true), rConc = Rx("Concora Credit", ci: true), rDays = Rx("Days in Billing Cycle", ci: true), rClose = Rx("Statement Closing Date", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = doc.pages.map(\.text).joined(separator: " ")
        return rBank.test(t) && rConc.test(t) && rDays.test(t) && rClose.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"Account number ending in (\d{4})"#, ci: true), cmRx = Rx(#"Statement Closing Date ([A-Za-z]+) (\d{1,2}), (\d{4})"#, ci: true), dcRx = Rx(#"Days in Billing Cycle (\d{1,3})"#, ci: true)
    static let gPrev = Rx(#"Previous Balance \$([\d,]+\.\d{2})(-)?"#, ci: true), gPay = Rx(#"Payments & Credits \$([\d,]+\.\d{2})(-)?"#, ci: true), gBuy = Rx(#"Purchases & Other Charges \$([\d,]+\.\d{2})(-)?"#, ci: true)
    static let gFees = Rx(#"FEES CHARGED \$([\d,]+\.\d{2})(-)?"#, ci: true), gInt = Rx(#"INTEREST CHARGED \$([\d,]+\.\d{2})(-)?"#, ci: true), gEnd = Rx(#"= New Balance \$([\d,]+\.\d{2})(-)?"#, ci: true), gEnd2 = Rx(#"New Balance \$([\d,]+\.\d{2})(-)?"#, ci: true)
    static let clRx = Rx(#"Credit Limit \$([\d,]+\.\d{2})"#, ci: true), mpRx = Rx(#"Minimum Payment Due \$([\d,]+\.\d{2})"#, ci: true), ddRx = Rx(#"Payment Due Date ([A-Za-z]+) (\d{1,2}), (\d{4})"#, ci: true)
    static let aprA = Rx(#"Purchase APR is (\d{1,3}\.\d{1,3})\s?%"#, ci: true), aprB = Rx(#"Purchases (\d{1,3}\.\d{1,3})\s?%"#, ci: true)
    static let sBuy = Rx("^TRANSACTIONS$", ci: true), sFee = Rx("^FEES$", ci: true), sInt = Rx("^INTEREST CHARGED$", ci: true), sEnd = Rx(#"^(Totals 2026|Totals \d{4}|IMPORTANT ACCOUNT INFORMATION|INTEREST CHARGE CALCULATION)"#, ci: true)
    static let mmdd = Rx(#"^\d{2}\/\d{2}$"#), refRx = Rx(#"^[A-Z0-9]{14,}$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let L = doc.pages.map { NazcaPDF.lines($0, 3) }
        let all = L.map { $0.map(lineText).joined(separator: " ") }.joined(separator: " ")
        var out = Nazca.StatementResult(bank: "milestone", kind: "tarjeta", label: "Milestone · Tarjeta de crédito", cur: "USD", items: [])
        var card = Nazca.StatementResult.CardInfo()
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1] }
        guard let cm = cmRx.groups(all), let cmo0 = MES[cm[1].lowercased()], let dc = dcRx.groups(all) else { out.error = "period"; out.card = card; return out }
        let closeDay = PDFx.epochDay(Int(cm[3])!, cmo0, Int(cm[2])!)
        let close = PDFx.civil(closeDay), start = PDFx.civil(closeDay - Int(dc[1])!)
        out.period = .init(from: PDFx.iso(start.y, start.m, start.d), to: PDFx.iso(close.y, close.m, close.d))
        let cmo = close.m, cy = close.y

        func grab(_ re: Rx) -> Double? { re.groups(all).map { PDFx.r2(($0[2].isEmpty ? 1 : -1) * num($0[1])) } }
        let smPrev = grab(gPrev), smPay = grab(gPay), smBuy = grab(gBuy), smFees = grab(gFees), smInt = grab(gInt)
        let smEnd = grab(gEnd) ?? grab(gEnd2)

        if let cl = clRx.groups(all) { card.limit = num(cl[1]) }
        if let mp = mpRx.groups(all) { card.minPayment = num(mp[1]) }
        if let dd = ddRx.groups(all), let mo = MES[dd[1].lowercased()] { card.dueDate = PDFx.iso(Int(dd[3])!, mo, Int(dd[2])!); card.dueDay = Int(dd[2]) }
        if let apr = aprA.groups(all) ?? aprB.groups(all) { card.apr = PDFx.parseFloat(apr[1]) }

        var line = 0, sec = "", sumBuy = 0.0, sumPay = 0.0, sumFee = 0.0, sumInt = 0.0
        for ls in L {
            for l in ls {
                let s = lineText(l)
                if sBuy.test(s) { sec = "buy"; continue }
                if sFee.test(s) { sec = "fee"; continue }
                if sInt.test(s) { sec = "int"; continue }
                if sEnd.test(s) { sec = ""; continue }
                if sec.isEmpty { continue }
                let its = l.items.map { $0.str.jsTrimmed }.filter { !$0.isEmpty }
                if its.count < 4 || !mmdd.test(its[0]) || !mmdd.test(its[1]) { continue }
                guard let am = AMT.groups(its[its.count - 1]) else { out.unreadable += 1; continue }
                var mid = Array(its[2..<(its.count - 1)])
                if mid.count > 1 && refRx.test(mid[0]) { mid.removeFirst() }
                let desc = PDFx.clean(mid.joined(separator: " "))
                if desc.isEmpty { out.unreadable += 1; continue }
                let v = PDFx.r2((am[2].isEmpty ? 1 : -1) * num(am[1]))
                if v == 0 { out.zero += 1; continue }
                let mo = Int(its[0].jsSlice(0, 2))!, dy = Int(its[0].jsSlice(3))!, y = mo > cmo ? cy - 1 : cy
                if sec == "fee" { sumFee += v } else if sec == "int" { sumInt += v } else if v > 0 { sumBuy += v } else { sumPay += abs(v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: PDFx.iso(y, mo, dy), desc: desc, amount: -v, cur: "USD"))
            }
        }
        sumBuy = PDFx.r2(sumBuy); sumPay = PDFx.r2(sumPay); sumFee = PDFx.r2(sumFee); sumInt = PDFx.r2(sumInt)
        var ok: Bool?
        if let p = smPrev, let e = smEnd, let pay = smPay {
            ok = PDFx.near(sumBuy, smBuy ?? 0) && PDFx.near(sumPay, pay) && PDFx.near(sumFee, smFees ?? 0) && PDFx.near(sumInt, smInt ?? 0) && PDFx.near(PDFx.r2(p - sumPay + sumBuy + sumFee + sumInt), e)
        }
        out.card = card
        out.check = .init(ok: ok, end: smEnd)
        return out
    }
}
