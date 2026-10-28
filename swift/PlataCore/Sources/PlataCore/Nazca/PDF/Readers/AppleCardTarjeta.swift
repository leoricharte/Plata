import Foundation

/// Nazca · Apple Card · Estado de cuenta (PDF) — puerto de `bancos/applecard-tarjeta.js`.
/// Pagos en negativo y compras en positivo en el PDF; para Plata el signo se invierte en los dos casos.
enum NazcaAppleCard {
    static let MES: [String: Int] = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
    static let D = Rx(#"^(\d{2})\/(\d{2})\/(\d{4})$"#), moneyRx = Rx(#"^(-)?\$([\d,]+\.\d{2})$"#), dashes = Rx(#"[−–]"#)
    static func money(_ s: String) -> Double? {
        guard let m = moneyRx.groups(dashes.replace(s, "-").jsTrimmed) else { return nil }
        return PDFx.r2((m[1].isEmpty ? 1 : -1) * PDFx.parseFloat(m[2].replacingOccurrences(of: ",", with: "")))
    }
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(l.items.map(\.str).joined(separator: " ")) }

    static let rCust = Rx("Apple Card Customer", ci: true), rIssued = Rx("Apple Card is issued by", ci: true), rTotal = Rx("Total Balance", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = doc.pages.map(\.text).joined(separator: " ")
        return rCust.test(t) && rIssued.test(t) && rTotal.test(t) ? 1 : 0
    }

    static let pmRx = Rx(#"([A-Za-z]{3}) (\d{1,2}) [—–\-] ([A-Za-z]{3}) (\d{1,2}), (\d{4})"#)
    static let gPrev = Rx(#"Previous Total Balance\s+(\$[\d,]+\.\d{2})"#), gEnd = Rx(#"(?<!Previous )Total Balance\s+(\$[\d,]+\.\d{2})"#)
    static let gChg = Rx(#"Total charges, credits and returns\s+(\$[\d,]+\.\d{2})"#), gInt = Rx(#"Total interest for this month\s+(\$[\d,]+\.\d{2})"#), gPay = Rx(#"Total payments for this period\s+(-?\$[\d,]+\.\d{2})"#)
    static let aprRx = Rx(#"Annual Percentage Rate \(APR\)\s+(\d{1,3}\.\d{1,2})\s?%"#, ci: true)
    static let dueRx = Rx(#"\$[\d,]+\.\d{2}\s+\$([\d,]+\.\d{2})\s+([A-Z][a-z]{2}) (\d{1,2}), (\d{4})"#)
    static let sPayRx = Rx(#"^Payments$"#), sChgRx = Rx(#"^Transactions$"#), sIntRx = Rx(#"^Interest Charged$"#), sEndRx = Rx(#"^(Daily Cash|Interest Charges|Legal)$"#)
    static let intRow = Rx(#"^Interest charge"#, ci: true), dailyAdj = Rx(#"^Daily Cash Adjustment$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let L = doc.pages.map { NazcaPDF.lines($0, 3) }
        let all = dashes.replace(L.map { $0.map(lineText).joined(separator: " ") }.joined(separator: " "), "-")
        var out = Nazca.StatementResult(bank: "applecard", kind: "tarjeta", label: "Apple Card · Tarjeta de crédito", cur: "USD", items: [])
        var card = Nazca.StatementResult.CardInfo()
        guard let pm = pmRx.groups(all), let m1 = MES[pm[1].lowercased()], let m2 = MES[pm[3].lowercased()] else { out.error = "period"; out.card = card; return out }
        let y2 = Int(pm[5])!, y1 = m1 > m2 ? y2 - 1 : y2
        let periodTo = PDFx.iso(y2, m2, Int(pm[4])!)
        out.period = .init(from: PDFx.iso(y1, m1, Int(pm[2])!), to: periodTo)

        func g(_ re: Rx) -> Double? { re.groups(all).flatMap { money($0[1]) } }
        let smPrev = g(gPrev), smEnd = g(gEnd), smChg = g(gChg), smInt = g(gInt), smPay = g(gPay)
        if let apr = aprRx.groups(all) { card.apr = PDFx.parseFloat(apr[1]) }
        if let due = dueRx.groups(all), let mo = MES[due[2].lowercased()] {
            card.minPayment = PDFx.parseFloat(due[1].replacingOccurrences(of: ",", with: ""))
            card.dueDate = PDFx.iso(Int(due[4])!, mo, Int(due[3])!); card.dueDay = Int(due[3])
        }

        var sec = "", line = 0, sPay = 0.0, sChg = 0.0, sInt = 0.0, lastDate = ""
        for ls in L {
            for l in ls {
                let its = l.items, t = lineText(l)
                if sPayRx.test(t) { sec = "pay"; continue }
                if sChgRx.test(t) { sec = "chg"; continue }
                if sIntRx.test(t) { sec = "int"; continue }
                if sEndRx.test(t) { sec = ""; continue }
                if sec.isEmpty { continue }
                guard let v = money(its[its.count - 1].str) else { continue }
                let d = D.groups(its[0].str)
                if sec == "int" {
                    if intRow.test(its[0].str) && its.count == 2 {
                        sInt = PDFx.r2(sInt + v); line += 1
                        out.items.append(Nazca.Item(line: line, date: periodTo, desc: its[0].str, amount: -v, cur: "USD"))
                    }
                    continue
                }
                // «Daily Cash Adjustment»: al devolver una compra, Apple retira el Daily Cash que había dado; cuenta como cargo
                if sec == "chg" && d == nil && dailyAdj.test(its[0].str) && v > 0 && !lastDate.isEmpty {
                    sChg = PDFx.r2(sChg + v); line += 1
                    out.items.append(Nazca.Item(line: line, date: lastDate, desc: "Daily Cash Adjustment", amount: -v, cur: "USD")); continue
                }
                guard let d, its[0].x <= 60, its.count >= 3 else { continue }
                let desc = PDFx.clean(its[1..<(its.count - 1)].filter { $0.x < 410 }.map(\.str).joined(separator: " "))
                if desc.isEmpty { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                if sec == "pay" { sPay = PDFx.r2(sPay + v) } else { sChg = PDFx.r2(sChg + v) }
                lastDate = "\(d[3])-\(d[1])-\(d[2])"
                line += 1
                out.items.append(Nazca.Item(line: line, date: lastDate, desc: desc, amount: -v, cur: "USD"))
            }
        }
        var ok: Bool?
        if let p = smPrev, let e = smEnd, let c = smChg, let i = smInt, let pay = smPay {
            ok = PDFx.near(sChg, c) && PDFx.near(sPay, pay) && PDFx.near(sInt, i) && PDFx.near(PDFx.r2(p + sPay + sChg + sInt), e)
        }
        out.card = card
        out.check = .init(ok: ok, end: smEnd)
        return out
    }
}
