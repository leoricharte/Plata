import Foundation

/// Nazca · Capital One · Estado de cuenta de tarjeta de crédito (PDF) — puerto de `bancos/capitalone-tarjeta.js`.
/// Compras positivas y pagos/créditos negativos en el PDF; para Plata, al revés. «Cuadra»: Previous Balance + Purchases + Fees − Payments = New Balance.
enum NazcaCapitalOne {
    static let MES: [String: Int] = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
    static let AMT = #"(-?\s?\$\s?[\d,]+\.\d{2}|\(\$[\d,]+\.\d{2}\))"#
    static let ROW = Rx(#"^([A-Za-z]{3}) (\d{1,2}) (?:([A-Za-z]{3}) (\d{1,2}) )?(.+?) "# + AMT + "$")
    static let dollarStrip = Rx(#"[$,\s]"#), parenAmt = Rx(#"^\((.*)\)$"#), dashes = Rx(#"[−–]"#)

    static func money(_ s: String) -> Double {
        var t = dollarStrip.replace(s, "")
        if let m = parenAmt.groups(t) { t = "-" + m[1] }
        return PDFx.r2(PDFx.parseFloat(t))
    }
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(dashes.replace(l.items.map(\.str).joined(separator: " "), "-")) }

    static let rEn = Rx(#"\bPage \d+ of \d+"#, ci: true), rEs = Rx(#"\bPágina \d+ de \d+"#, ci: true)

    /// Los estados en español traen la misma información dos veces (copia en español y copia en inglés): se lee solo la copia en inglés.
    static func soloIngles(_ pages: [PdfPage]) -> [PdfPage] {
        var lang: [String?] = [], cur: String?
        for p in pages {
            let t = p.text
            if rEn.test(t) { cur = "en" } else if rEs.test(t) { cur = "es" }
            lang.append(cur)
        }
        let hasEn = lang.contains { $0 == "en" }, hasEs = lang.contains { $0 == "es" }
        return hasEn && hasEs ? pages.enumerated().filter { lang[$0.offset] != "es" }.map(\.element) : pages
    }

    static let rCap = Rx("Capital One", ci: true), rDate = Rx(#"(Trans|Post) Date"#, ci: true), rPrev = Rx("Previous Balance", ci: true), rNew = Rx("New Balance", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = doc.pages.map(\.text).joined(separator: " ")
        return rCap.test(t) && rDate.test(t) && rPrev.test(t) && rNew.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"ending in (\d{4})"#, ci: true)
    static let pmA = Rx(#"Statement period:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})"#, ci: true)
    static let pmB = Rx(#"([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})[\s|]*\d+ days in Billing Cycle"#, ci: true)
    static let aprA = Rx(#"(?:Purchase )?APR:?\s*(\d{1,3}(?:\.\d{1,2})?)\s?%"#, ci: true), aprB = Rx(#"Purchases\s+(\d{1,3}\.\d{1,2})\s?%"#, ci: true)
    static let ddRx = Rx(#"Payment Due Date:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})"#, ci: true)
    static let mpRx = Rx(#"Minimum Payment Due:?\s*"# + AMT, ci: true), clRx = Rx(#"Credit Limit:?\s*"# + AMT, ci: true)
    static let usd = Rx(#"^\$\s?[\d,]+\.\d{2}$"#), mpTitle = Rx(#"^Minimum Payment Due$"#), clLine = Rx(#"^Credit Limit "# + AMT + "$", ci: true)
    static let secFees = Rx(#"^Fees$"#, ci: true), secOther = Rx(#"^(Interest Charged|Transactions|Totals Year-to-Date)$"#, ci: true)
    static let authDate = Rx(#"\s*AuthDate \d{1,2}-[A-Za-z]{3}$"#, ci: true), hasAlpha = Rx(#"[A-Za-z]"#), skipDesc = Rx(#"^(previous balance|new balance|total|minimum|payments|purchases|fees)\b"#, ci: true)
    static let gPrev = Rx(#"Previous Balance\s*"# + AMT, ci: true), gPay = Rx(#"Payments(?: & Credits)?\s*"# + AMT, ci: true), gBuy = Rx(#"(?:Purchases|Transactions)\s*\+?\s*"# + AMT, ci: true)
    static let gOc = Rx(#"Other Credits\s*"# + AMT, ci: true), gInt = Rx(#"Interest Charged\s*\+?\s*"# + AMT, ci: true), gFees = Rx(#"Fees(?: & Interest| Charged)?\s*\+?\s*"# + AMT, ci: true), gEnd = Rx(#"New Balance\s*=?\s*"# + AMT, ci: true)

    static func read(_ doc0: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc0) == 0 { return nil }
        let doc = PdfDoc(pages: soloIngles(doc0.pages))
        let all = PDFx.squash(dashes.replace(doc.pages.map(\.text).joined(separator: " "), "-"))
        var out = Nazca.StatementResult(bank: "capitalone", kind: "tarjeta", label: "Capital One · Tarjeta de crédito", cur: "USD", items: [])
        if let l4 = l4Rx.groups(all) { out.last4 = l4[1] }
        guard let pm = pmA.groups(all) ?? pmB.groups(all), let fm = MES[pm[1].lowercased()], let tm = MES[pm[4].lowercased()] else { out.error = "period"; return out }
        let f = (m: fm, d: Int(pm[2])!, y: Int(pm[3])!), t = (m: tm, d: Int(pm[5])!, y: Int(pm[6])!)
        let periodTo = PDFx.iso(t.y, t.m, t.d)
        out.period = .init(from: PDFx.iso(f.y, f.m, f.d), to: periodTo)

        func grab(_ re: Rx) -> Double? { re.groups(all).map { money($0[1]) } }
        let smPrev = grab(gPrev), smPay = grab(gPay), smBuy = grab(gBuy), smOc = grab(gOc), smInt = grab(gInt), smFees = grab(gFees), smEnd = grab(gEnd)

        var card = Nazca.StatementResult.CardInfo()
        let apr = aprA.groups(all) ?? aprB.groups(all), dd = ddRx.groups(all)
        let mp = mpRx.groups(all), cl = clRx.groups(all)
        func under(_ re: Rx) -> Double? {
            for page in doc.pages {
                let ls = NazcaPDF.lines(page, 3)
                for i in ls.indices {
                    guard let it = ls[i].items.first(where: { re.test($0.str) }) else { continue }
                    var k = i + 1
                    while k <= i + 3 && k < ls.count {
                        if let a = ls[k].items.first(where: { usd.test($0.str) && abs($0.x - it.x) < 40 }) { return money(a.str) }
                        k += 1
                    }
                }
            }
            return nil
        }
        let mp2 = under(mpTitle)
        var cl2: Double?
        search: for page in doc.pages { for l in NazcaPDF.lines(page, 3) { if let m = clLine.groups(lineText(l)) { cl2 = money(m[1]); break search } } }
        if let apr { card.apr = PDFx.parseFloat(apr[1]) }
        if let dd, let mo = MES[dd[1].lowercased()] { card.dueDate = "\(dd[3])-\(PDFx.pad(mo))-\(PDFx.pad(Int(dd[2])!))"; card.dueDay = Int(dd[2]) }
        if let mp2 { card.minPayment = abs(mp2) } else if let mp { card.minPayment = abs(money(mp[1])) }
        if let cl { card.limit = abs(money(cl[1])) } else if let cl2 { card.limit = abs(cl2) }
        out.card = card

        var line = 0, sumBuy = 0.0, sumPay = 0.0, sumFee = 0.0, sec = ""
        for page in doc.pages {
            for l in NazcaPDF.lines(page, 3) {
                let s = lineText(l)
                if secFees.test(s) { sec = "fees" } else if secOther.test(s) { sec = "" }
                guard let m = ROW.groups(s), let mo = MES[m[1].lowercased()] else { continue }
                let desc = PDFx.clean(authDate.replace(m[5], ""))
                if desc.isEmpty || !hasAlpha.test(desc) || skipDesc.test(desc) { continue }
                let v = money(m[6])
                if v == 0 || v.isNaN { out.zero += 1; continue }
                let y = f.y == t.y ? f.y : (mo >= f.m ? f.y : t.y)
                let date = "\(y)-\(PDFx.pad(mo))-\(PDFx.pad(Int(m[2])!))"
                let amount = v > 0 ? -v : abs(v)
                if v > 0 { if sec == "fees" { sumFee += v } else { sumBuy += v } } else { sumPay += abs(v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: amount, cur: "USD"))
            }
        }
        let intr = (smInt ?? 0) > 0 ? smInt! : 0
        if intr != 0 { line += 1; out.items.append(Nazca.Item(line: line, date: periodTo, desc: "Interest charge", amount: -intr, cur: "USD")) }
        sumBuy = PDFx.r2(sumBuy); sumPay = PDFx.r2(sumPay); sumFee = PDFx.r2(sumFee)
        var ok: Bool?
        if let smPrev, let smEnd, let smBuy, let smPay {
            ok = PDFx.near(sumBuy, smBuy) && PDFx.near(sumFee, smFees ?? 0) && PDFx.near(sumPay, abs(smPay) + abs(smOc ?? 0)) && PDFx.near(PDFx.r2(smPrev + sumBuy + sumFee + intr - sumPay), smEnd)
        }
        out.check = .init(ok: ok, end: smEnd)
        return out
    }
}
