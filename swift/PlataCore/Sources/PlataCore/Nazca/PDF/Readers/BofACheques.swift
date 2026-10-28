import Foundation

/// Nazca · Bank of America · Estado de cuenta de cheques (PDF) — puerto de `bancos/bofa-cheques.js`.
enum NazcaBofA {
    static let AMT = Rx(#"^-?\$?[\d,]+\.\d{2}$"#), dashes = Rx(#"[−–]"#), junkChars = Rx(#"[-$,]"#)
    static func money(_ s: String) -> Double? {
        let t = dashes.replace(s, "-").jsTrimmed
        if !AMT.test(t) { return nil }
        return PDFx.r2((t.hasPrefix("-") ? -1 : 1) * PDFx.parseFloat(junkChars.replace(t, "")))
    }
    static let ES: [String: Int] = ["enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7, "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12]
    static let EN: [String: Int] = ["january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12]
    static func lineText(_ l: PdfLine) -> String { PDFx.clean(l.items.map(\.str).joined(separator: " ")) }

    static let rBank = Rx("Bank of America", ci: true), rSum = Rx("Resumen de la cuenta|Account summary", ci: true), rIni = Rx("Saldo inicial|Beginning balance", ci: true), rFin = Rx("Saldo final|Ending balance", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.flat(doc)
        return rBank.test(t) && rSum.test(t) && rIni.test(t) && rFin.test(t) ? 1 : 0
    }

    static let pEs = Rx(#"(\d{1,2}) de ([a-záéíóú]+) (?:del? )?(\d{4}) al (\d{1,2}) de ([a-záéíóú]+) (?:del? )?(\d{4})"#, ci: true)
    static let pEn = Rx(#"([A-Za-z]+) (\d{1,2}), (\d{4}) (?:to|through|-) ([A-Za-z]+) (\d{1,2}), (\d{4})"#, ci: true)

    static func period(_ t: String) -> Nazca.StatementResult.Period? {
        if let m = pEs.groups(t), let a = ES[m[2].lowercased()], let b = ES[m[5].lowercased()] {
            return .init(from: PDFx.iso(Int(m[3])!, a, Int(m[1])!), to: PDFx.iso(Int(m[6])!, b, Int(m[4])!))
        }
        if let m = pEn.groups(t), let a = EN[m[1].lowercased()], let b = EN[m[4].lowercased()] {
            return .init(from: PDFx.iso(Int(m[3])!, a, Int(m[2])!), to: PDFx.iso(Int(m[6])!, b, Int(m[5])!))
        }
        return nil
    }

    static let tidyRx = Rx(#"^(?:MOBILE PURCHASE|PURCHASE|CHECKCARD|RECURRING CHECKCARD)\s+\d{4}\s+"#, ci: true)
    static func tidy(_ d: String) -> String { let t = PDFx.clean(tidyRx.replace(d, "")); return t.isEmpty ? d : t }

    static let acRx = Rx(#"(?:N[uú]mero de cuenta|Account number):?\s*((?:\d{4} ?){2,4})"#, ci: true), ws = Rx(#"\s"#)
    static let kPrev = Rx("^(Saldo inicial|Beginning balance)", ci: true), kEnd = Rx("^(Saldo final|Ending balance)", ci: true), kDep = Rx("^(Dep[oó]sitos y otros agregados|Deposits and other additions)", ci: true)
    static let kAtm = Rx("^(Sustracciones de tarjeta|ATM and debit card subtractions)", ci: true), kOth = Rx("^(Otras sustracciones|Other subtractions)", ci: true), kFee = Rx("^(Cargos por servicio|Service fees)", ci: true)
    static let dRx = Rx(#"^(\d{2})\/(\d{2})\/(\d{2})$"#)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        var out = Nazca.StatementResult(bank: "bofa", kind: "corriente", label: "Bank of America · Cuenta de cheques", cur: "USD", items: [])
        let t = PDFx.flat(doc)
        if let ac = acRx.groups(t) { out.last4 = String(ws.replace(ac[1], "").suffix(4)) }
        out.period = period(t)
        if out.period == nil { out.error = "period"; return out }

        var prev: Double?, end: Double?, dep: Double?, atm: Double?, oth: Double?, fee: Double?
        for l in NazcaPDF.lines(doc.pages[0], 3) {
            let its = l.items, s = lineText(l)
            guard let last = its.last, let v = money(last.str), its.count >= 2 else { continue }
            if kPrev.test(s) { prev = v } else if kEnd.test(s) { end = v }
            else if kDep.test(s) { dep = v } else if kAtm.test(s) { atm = v } else if kOth.test(s) { oth = v } else if kFee.test(s) { fee = v }
        }

        var line = 0, pos = 0.0, neg = 0.0
        for page in doc.pages.dropFirst() {
            for l in NazcaPDF.lines(page, 3) {
                let its = l.items
                guard let d = dRx.groups(its[0].str), its[0].x <= 60, its.count >= 3 else { continue }
                let am = its[its.count - 1]
                guard let v = money(am.str), am.x >= 400 else { out.unreadable += 1; continue }
                let desc = tidy(its[1..<(its.count - 1)].map(\.str).joined(separator: " "))
                if desc.isEmpty { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                if v > 0 { pos = PDFx.r2(pos + v) } else { neg = PDFx.r2(neg + v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: "20\(d[3])-\(d[1])-\(d[2])", desc: desc, amount: v, cur: "USD"))
            }
        }
        var ok: Bool?
        if let prev, let end, let dep {
            let subs = PDFx.r2((atm ?? 0) + (oth ?? 0) + (fee ?? 0))
            ok = PDFx.near(pos, dep) && PDFx.near(neg, subs) && PDFx.near(PDFx.r2(prev + pos + neg), end)
        }
        out.check = .init(ok: ok, end: end)
        return out
    }
}
