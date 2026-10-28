import Foundation

/// Nazca · Chime · «Checking Account Statement» (PDF) — puerto de `bancos/chime-checking.js`.
enum NazcaChime {
    static let MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
    static let DATE = Rx(#"^(\d{1,2})\/(\d{1,2})\/(\d{4})$"#), dashes = Rx(#"[−–]"#), moneyRx = Rx(#"^(-)?\$([\d,]+\.\d{2})$"#)
    static func money(_ s: String) -> Double? {
        guard let m = moneyRx.groups(dashes.replace(s, "-").jsTrimmed) else { return nil }
        return PDFx.r2((m[1].isEmpty ? 1 : -1) * PDFx.parseFloat(m[2].replacingOccurrences(of: ",", with: "")))
    }

    static let rTitle = Rx("Checking Account Statement", ci: true), rTx = Rx("TRANSACTION DATE"), rNet = Rx("NET AMOUNT"), rSet = Rx("SETTLEMENT DATE"), rBank = Rx("Chime|The Bancorp Bank", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.flat(doc)
        return rTitle.test(t) && rTx.test(t) && rNet.test(t) && rSet.test(t) && rBank.test(t) ? 1 : 0
    }

    static let acRx = Rx(#"Account number\s+(\d{6,})"#, ci: true), pmRx = Rx(#"\(\s*([A-Za-z]+) (\d{1,2}), (\d{4}) - ([A-Za-z]+) (\d{1,2}), (\d{4})\s*\)"#)
    static let gPrev = Rx(#"Beginning balance on [A-Za-z]+ \d{1,2}, \d{4}\s+(-?\$[\d,]+\.\d{2})"#), gEnd = Rx(#"Ending balance on [A-Za-z]+ \d{1,2}, \d{4}\s+(-?\$[\d,]+\.\d{2})"#)
    static let gDep = Rx(#"Deposits\s+(-?\$[\d,]+\.\d{2})"#), gFees = Rx(#"Fees\s+(-?\$[\d,]+\.\d{2})"#)
    static let depType = Rx(#"^(Deposit|Cash Bonus)$"#, ci: true), feeType = Rx(#"^Fee$"#, ci: true)

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let t = PDFx.flat(doc)
        var out = Nazca.StatementResult(bank: "chime", kind: "corriente", label: "Chime · Cuenta corriente", cur: "USD", items: [])
        if let ac = acRx.groups(t) { out.last4 = String(ac[1].suffix(4)) }
        guard let pm = pmRx.groups(t), let m1 = MONTHS.firstIndex(of: pm[1].lowercased()), let m2 = MONTHS.firstIndex(of: pm[4].lowercased()) else { out.error = "period"; return out }
        out.period = .init(from: PDFx.iso(Int(pm[3])!, m1 + 1, Int(pm[2])!), to: PDFx.iso(Int(pm[6])!, m2 + 1, Int(pm[5])!))

        func grab(_ re: Rx) -> Double? { re.groups(t).flatMap { money($0[1]) } }
        let sPrev = grab(gPrev), sEnd = grab(gEnd), sDep = grab(gDep), sFees = grab(gFees)

        var line = 0, total = 0.0, dep = 0.0, fees = 0.0
        var cols: (desc: Double, type: Double, amt: Double, net: Double, set: Double)?
        for page in doc.pages {
            for l in NazcaPDF.lines(page, 3) {
                let its = l.items
                if its.contains(where: { $0.str == "TRANSACTION DATE" }) {
                    func g(_ n: String) -> PdfItem? { its.first { $0.str == n } }
                    if let a = g("AMOUNT"), let n = g("NET AMOUNT"), let d = g("DESCRIPTION"), let ty = g("TYPE"), let st = g("SETTLEMENT DATE") { cols = (d.x, ty.x, a.x, n.x, st.x) }
                    continue
                }
                guard let cols, !its.isEmpty else { continue }
                guard let d = DATE.groups(its[0].str), its[0].x <= cols.desc else { continue }
                func inCol(_ lo: Double, _ hi: Double) -> [PdfItem] { its.filter { $0.x >= lo - 3 && $0.x < hi - 3 } }
                let desc = PDFx.clean(inCol(cols.desc, cols.type).map(\.str).joined(separator: " "))
                let type = inCol(cols.type, cols.amt - 20).map(\.str).joined(separator: " ").jsTrimmed
                let netIt = its.first { $0.x >= cols.net - 20 && $0.x < cols.set - 3 && money($0.str) != nil } ?? its.first { $0.x >= cols.amt - 20 && $0.x < cols.net - 20 && money($0.str) != nil }
                guard !desc.isEmpty, let netIt, let v = money(netIt.str) else { out.unreadable += 1; continue }
                if v == 0 { out.zero += 1; continue }
                total = PDFx.r2(total + v)
                if depType.test(type) { dep = PDFx.r2(dep + v) }
                if feeType.test(type) { fees = PDFx.r2(fees + v) }
                line += 1
                out.items.append(Nazca.Item(line: line, date: PDFx.iso(Int(d[3])!, Int(d[1])!, Int(d[2])!), desc: desc, amount: v, cur: "USD"))
            }
        }
        var ok: Bool?
        if let sPrev, let sEnd { ok = PDFx.near(PDFx.r2(sPrev + total), sEnd) && (sDep == nil || PDFx.near(dep, sDep!)) && (sFees == nil || PDFx.near(fees, sFees!)) }
        out.check = .init(ok: ok, end: sEnd)
        return out
    }
}
