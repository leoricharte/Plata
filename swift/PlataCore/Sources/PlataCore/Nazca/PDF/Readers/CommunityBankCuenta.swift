import Foundation

/// Nazca · Community Bank, N.A. · Estado de cuenta corriente (PDF) — puerto de `bancos/communitybank-cuenta.js`.
/// El monto de la tabla viene sin signo: el signo sale de cómo cambia la columna Balance (sube → abono, baja → cargo).
enum NazcaCommunityBank {
    static let numRx = Rx(#"^\(?-?\$?[\d,]+\.\d{2}\)?-?$"#), negRx = Rx(#"^\(|^-|-$"#), keep = Rx(#"[^\d.]"#)
    static func num(_ s: String) -> Double? {
        let t = s.jsTrimmed
        guard numRx.test(t) else { return nil }
        return PDFx.r2((negRx.test(t) ? -1 : 1) * PDFx.parseFloat(keep.replace(t, "")))
    }

    static let rBank = Rx("CBNA|Community Bank", ci: true), rPrev = Rx("Previous Balance", ci: true), rCred = Rx(#"Deposits\/Credits"#, ci: true), rDeb = Rx(#"Checks\/Debits"#, ci: true), rEnd = Rx("Ending Balance", ci: true), rDates = Rx("Statement Dates", ci: true)

    static func detect(_ doc: PdfDoc) -> Int {
        if doc.pages.isEmpty { return 0 }
        let t = PDFx.flat(doc)
        return rBank.test(t) && rPrev.test(t) && rCred.test(t) && rDeb.test(t) && rEnd.test(t) && rDates.test(t) ? 1 : 0
    }

    static let l4Rx = Rx(#"Primary Account:?\s*X*(\d{4})"#, ci: true), pmRx = Rx(#"Statement Dates\s*(\d{1,2})\/(\d{1,2})\/(\d{2,4})\s*thru\s*(\d{1,2})\/(\d{1,2})\/(\d{2,4})"#, ci: true)
    static let KEYS: [(String, Rx)] = [("prev", Rx(#"^Previous Balance$"#, ci: true)), ("cred", Rx(#"^Deposits\/Credits$"#, ci: true)), ("deb", Rx(#"^Checks\/Debits$"#, ci: true)),
                                       ("fee", Rx(#"^Service Charge$"#, ci: true)), ("int", Rx(#"^Interest Paid$"#, ci: true)), ("end", Rx(#"^Ending Balance$"#, ci: true))]
    static let START = Rx(#"^[A-Z][A-Za-z\/]{1,3}(?: [A-Z\/]{2,4})? \d{4} \d{2}\/\d{2}\/\d{2}\b"#)
    static let tableHead = Rx(#"Credits\/Debits"#, ci: true), balWord = Rx("Balance", ci: true), skipHead = Rx(#"Branch Phone|^Page:"#, ci: true), dmRx = Rx(#"^(\d{1,2})\/(\d{1,2})$"#)
    static let tidy1 = Rx(#"^[A-Z][A-Za-z\/]{1,3}(?: [A-Z\/]{2,4})? \d{4} \d{2}\/\d{2}\/\d{2} \d+\s*"#), tidy2 = Rx(#"\s*C#\d+\s*$"#)
    static let credWords = Rx("refund|deposit|credit|interest|reversal|transfer from|payroll", ci: true)
    static func tidy(_ x: String) -> String { PDFx.clean(tidy2.replace(tidy1.replace(x, ""), "")) }

    struct Row { var m: Int; var d: Int; var amt: Double; var bal: Double; var desc: [String] }

    static func read(_ doc: PdfDoc) -> Nazca.StatementResult? {
        if detect(doc) == 0 { return nil }
        let t = PDFx.flat(doc)
        var out = Nazca.StatementResult(bank: "communitybank", kind: "corriente", label: "Community Bank · Cuenta corriente", cur: "USD", items: [])
        if let l4 = l4Rx.groups(t) { out.last4 = l4[1] }
        guard let pm = pmRx.groups(t) else { out.error = "period"; return out }
        func yy(_ s: String) -> Int { let y = Int(s)!; return y < 100 ? 2000 + y : y }
        let f = (m: Int(pm[1])!, d: Int(pm[2])!, y: yy(pm[3])), e = (m: Int(pm[4])!, d: Int(pm[5])!, y: yy(pm[6]))
        out.period = .init(from: PDFx.iso(f.y, f.m, f.d), to: PDFx.iso(e.y, e.m, e.d))

        var sm: [String: Double] = [:]
        for l in NazcaPDF.lines(doc.pages[0], 3) {
            let it = l.items.map { $0.str.jsTrimmed }.filter { !$0.isEmpty }
            for (k, re) in KEYS {
                if let i = it.firstIndex(where: { re.test($0) }), i + 1 < it.count, let v = num(it[i + 1]) { sm[k] = v }
            }
        }

        var rows: [Row] = []
        var buf: [String] = [], inTable = false
        for page in doc.pages {
            for l in NazcaPDF.lines(page, 3) {
                let it = l.items, head = it.map(\.str).joined(separator: " ")
                if tableHead.test(head) && balWord.test(head) { inTable = true; continue }
                if !inTable || skipHead.test(head.jsTrimmed) { continue }
                if let dm = dmRx.groups(it[0].str.jsTrimmed), it[0].x <= 70, it.count >= 3, let amt = num(it[it.count - 2].str), let bal = num(it[it.count - 1].str) {
                    let inline = PDFx.clean(it[1..<(it.count - 2)].map(\.str).joined(separator: " "))
                    var desc = inline
                    if desc.isEmpty { desc = buf.joined(separator: " "); buf = [] }
                    rows.append(Row(m: Int(dm[1])!, d: Int(dm[2])!, amt: amt, bal: bal, desc: [desc]))
                } else {
                    let txt = PDFx.clean(head)
                    if txt.isEmpty { continue }
                    if START.test(txt) || rows.isEmpty || !buf.isEmpty { buf.append(txt) } else { rows[rows.count - 1].desc.append(txt) }
                }
            }
        }
        var line = 0, run: Double? = sm["prev"], running = sm["prev"] != nil, sumC = 0.0, sumD = 0.0
        for r in rows {
            let joined = r.desc.joined(separator: " ")
            var desc = tidy(joined)
            if desc.isEmpty { desc = "Movimiento" }
            if r.desc.joined().jsTrimmed.isEmpty { out.unreadable += 1; continue }
            let y = f.y == e.y ? f.y : (r.m >= f.m ? f.y : e.y)
            let date = PDFx.iso(y, r.m, r.d)
            let mag = abs(r.amt)
            var amount: Double
            if let run, PDFx.near(run + mag, r.bal) { amount = mag }
            else if let run, PDFx.near(run - mag, r.bal) { amount = -mag }
            else { running = false; amount = r.amt < 0 ? -mag : (credWords.test(desc) ? mag : -mag) }
            if amount == 0 { out.zero += 1; continue }
            run = r.bal
            if amount > 0 { sumC += amount } else { sumD += -amount }
            line += 1
            out.items.append(Nazca.Item(line: line, date: date, desc: desc, amount: amount, cur: "USD", balance: r.bal))
        }
        sumC = PDFx.r2(sumC); sumD = PDFx.r2(sumD)
        var ok: Bool?
        if let prev = sm["prev"], let end = sm["end"], let cred = sm["cred"], let deb = sm["deb"] {
            let fee = sm["fee"] ?? 0, intr = sm["int"] ?? 0
            ok = PDFx.near(sumC, cred + intr) && PDFx.near(sumD, abs(deb) + fee) && PDFx.near(PDFx.r2(prev + sumC - sumD), end) && running
        }
        out.check = .init(ok: ok, end: sm["end"])
        return out
    }
}
