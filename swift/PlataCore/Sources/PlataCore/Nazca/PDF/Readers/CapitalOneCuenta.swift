import Foundation

/// Nazca · Capital One 360 · Estado de cuenta de cheques (PDF) — puerto de `bancos/capitalone-cuenta.js`.
/// Cada fila trae el monto con signo («+ $1,018.47» / «- $169.64») y el saldo corrido; hay descripciones de dos líneas.
enum NazcaCapitalOneCuenta {
    static let MES = NazcaCapitalOne.MES
    static func text(_ doc: PdfDoc) -> String { PDFx.flat(doc) }

    static let moneyRx = Rx(#"^([+-])?\s?\$\s?([\d,]+\.\d{2})$"#), dashes = Rx(#"[−–]"#)
    static func money(_ s: String) -> Double? {
        guard let m = moneyRx.groups(dashes.replace(s, "-").jsTrimmed) else { return nil }
        return PDFx.r2((m[1] == "-" ? -1 : 1) * PDFx.parseFloat(m[2].replacingOccurrences(of: ",", with: "")))
    }
    static let START = Rx(#"^(ATM|Debit|Digital|Deposit|Withdrawal|Zelle|Monthly|Check|ACH|Transfer|Wire|Direct|Interest|Fee|Refund|Payment|POS|Bill|Online|External|Mobile|Overdraft|Cash|Credit|Purchase|Service|Instant|Incoming|Outgoing|Recurring|Remote|Round)\b"#, ci: true)

    static let rCap = Rx("Capital One", ci: true), rPeriod = Rx("STATEMENT PERIOD", ci: true), rOpen = Rx("Opening Balance", ci: true), rClose = Rx("Closing Balance", ci: true), rHead = Rx(#"DATE\s+DESCRIPTION\s+CATEGORY\s+AMOUNT\s+BALANCE"#, ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = text(doc)
        return rCap.test(t) && rPeriod.test(t) && rOpen.test(t) && rClose.test(t) && rHead.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"\.{2,}\s*(\d{4})\b"#), pmRx = Rx(#"([A-Za-z]{3})[a-z]* (\d{1,2}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})"#)
    static let headLine = Rx(#"^DATE DESCRIPTION CATEGORY AMOUNT BALANCE"#, ci: true), dmRx = Rx(#"^([A-Za-z]{3}) (\d{1,2})$"#)
    static let endRx = Rx(#"^(Fees Summary|Page \d+ of)"#, ci: true), feesSum = Rx(#"^Fees Summary"#, ci: true), hasAlpha = Rx(#"[A-Za-z]"#), notDesc = Rx(#"^(TOTAL|Total|PERIOD|DATE)"#), hasDollar = Rx(#"[$]"#)
    static let openRx = Rx(#"^Opening Balance$"#, ci: true), closeRx = Rx(#"^Closing Balance$"#, ci: true)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let t = text(doc)
        var out = Nazca.StatementResult(bank: "capitalone", kind: "corriente", label: "Capital One · Cuenta de cheques", cur: "USD", items: [])
        if let l4 = l4Rx.groups(t) { out.last4 = l4[1] }
        guard let pm = pmRx.groups(t), let fm = MES[pm[1].lowercased()], let em = MES[pm[3].lowercased()] else { out.error = "period"; return out }
        let f = (m: fm, d: Int(pm[2])!), e = (m: em, d: Int(pm[4])!, y: Int(pm[5])!)
        let fy = f.m > e.m ? e.y - 1 : e.y
        out.period = .init(from: PDFx.iso(fy, f.m, f.d), to: PDFx.iso(e.y, e.m, e.d))

        var prev: Double?, end: Double?, run: Double?
        var running = true, line = 0, sumC = 0.0, sumD = 0.0, prefix = "", seenHead = false, closed = false
        var lastIdx: Int?
        pages: for page in doc.pages {
            for l in NazcaPDF.lines(page, 3) {
                if closed { break pages }
                let its = l.items.map { (x: $0.x, s: PDFx.clean($0.str)) }.filter { !$0.s.isEmpty }
                let joined = its.map(\.s).joined(separator: " ")
                if headLine.test(joined) { seenHead = true; continue }
                if !seenHead { continue }
                let dm: [String]? = (its.first.map { $0.x < 90 } ?? false) ? dmRx.groups(its[0].s) : nil
                guard let dm else {
                    if endRx.test(joined) { if feesSum.test(joined) { closed = true }; continue }
                    if its.count == 1 && its[0].x > 90 && its[0].x < 300 && hasAlpha.test(joined) && !notDesc.test(joined) {
                        if START.test(joined) || lastIdx == nil { prefix = (prefix.isEmpty ? "" : prefix + " ") + joined }
                        else if let li = lastIdx { out.items[li].desc = PDFx.clean(out.items[li].desc + " " + joined) }
                    }
                    continue
                }
                guard let mo = MES[dm[1].lowercased()] else { continue }
                let amtIt = its.first { $0.x > 380 && $0.x < 480 && hasDollar.test($0.s) }
                let balIt = its.filter { $0.x >= 480 }.last
                let descIt = its.first { $0.x >= 90 && $0.x < 340 }
                let bal = balIt.flatMap { money($0.s) }
                if let d = descIt, openRx.test(d.s) { prev = bal; run = bal; prefix = ""; continue }
                if let d = descIt, closeRx.test(d.s) { end = bal; prefix = ""; closed = true; continue }
                let amount = amtIt.flatMap { money($0.s) }
                guard let amount, let bal else { out.unreadable += 1; prefix = ""; continue }
                var desc = PDFx.clean(descIt?.s ?? prefix)
                if descIt != nil && !prefix.isEmpty { desc = (prefix + " " + desc).jsTrimmed }
                prefix = ""
                if desc.isEmpty { out.unreadable += 1; continue }
                if amount == 0 { out.zero += 1; continue }
                if let run, !PDFx.near(PDFx.r2(run + amount), bal) { running = false }
                run = bal
                if amount > 0 { sumC += amount } else { sumD += -amount }
                let y = f.m > e.m && mo >= f.m ? e.y - 1 : e.y
                line += 1
                out.items.append(Nazca.Item(line: line, date: PDFx.iso(y, mo, Int(dm[2])!), desc: desc, amount: amount, cur: "USD", balance: bal))
                lastIdx = out.items.count - 1
            }
        }
        sumC = PDFx.r2(sumC); sumD = PDFx.r2(sumD)
        var ok: Bool?
        if let prev, let end { ok = running && PDFx.near(PDFx.r2(prev + sumC - sumD), end) }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
