import Foundation

/// Nazca · lector genérico de PDF (puerto de `pdf-generico.js`).
/// Para los estados de cuenta de bancos que Nazca todavía no conoce: busca los renglones que empiezan con una fecha y terminan con un monto
/// y arma con ellos una tabla Fecha, Descripción, Monto que se lee con el mismo motor que un CSV. No sabe de qué banco es ni comprueba que «cuadre».
public enum NazcaPDFGen {
    public struct Result: Sendable {
        public var text = ""
        public var count = 0
        public var cur = ""
        public var year = 0
        public var name = ""
        public var isCard = false
        public var card = Nazca.StatementResult.CardInfo()
        public var last4 = ""
    }

    // MARK: Fechas

    static let MES: [String: Int] = ["ene": 1, "jan": 1, "feb": 2, "mar": 3, "abr": 4, "apr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "aug": 8, "set": 9, "sep": 9, "oct": 10, "nov": 11, "dic": 12, "dec": 12]
    static let minus = Rx(#"[−–—]"#)
    static func mon(_ w: String) -> Int { MES[String(w.lowercased().prefix(3))] ?? 0 }
    static func y4(_ y: Int) -> Int { y < 100 ? 2000 + y : y }
    static func pad(_ n: Int) -> String { PDFx.pad(n) }

    struct DateTok {
        var v: String?          // fecha para el motor de CSV
        var short = false
        var d = 0, mo = 0, yr = 0
        var rest = ""
    }

    static let dIso = Rx(#"^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)\s*"#)
    static let dNum = Rx(#"^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)\s*"#)
    static let dEs = Rx(#"^(\d{1,2})\s?(?:de\s|[-/.]\s?)?([A-Za-zñÑ]{3,10})\.?(?:[\s,/-]*(?:de\s)?(\d{4}|\d{2}))?(?![A-Za-z\d])\s*"#)
    static let dEn = Rx(#"^([A-Za-zñÑ]{3,9})\.?\s?(\d{1,2})(?:st|nd|rd|th)?(?:,?\s(\d{4}))?(?![A-Za-z\d])\s*"#)
    static let dShort = Rx(#"^(\d{1,2})[/.-](\d{1,2})(?![/.\d-]?\d)\s*"#)

    /// Fecha al inicio del texto. Entiende: 2026-03-05 · 5/3/2026 · 9/30/26 · 5-3 · 5 mar 2026 · 5-mar-26 · Mar 5, 2026 · Mar 5 · March 5th.
    static func takeDate(_ s: String) -> DateTok? {
        if let m = dIso.groups(s) {
            return DateTok(v: "\(m[1])-\(pad(Int(m[2])!))-\(pad(Int(m[3])!))", rest: s.jsSlice(m[0].jsLength))
        }
        if let m = dNum.groups(s) {
            let y = m[3].jsLength == 2 ? String(y4(Int(m[3])!)) : m[3]
            return DateTok(v: "\(m[1])/\(m[2])/\(y)", rest: s.jsSlice(m[0].jsLength))
        }
        if let m = dEs.groups(s), mon(m[2]) != 0 {
            return DateTok(d: Int(m[1])!, mo: mon(m[2]), yr: m[3].isEmpty ? 0 : y4(Int(m[3])!), rest: s.jsSlice(m[0].jsLength))
        }
        if let m = dEn.groups(s), mon(m[1]) != 0 {
            return DateTok(d: Int(m[2])!, mo: mon(m[1]), yr: m[3].isEmpty ? 0 : Int(m[3])!, rest: s.jsSlice(m[0].jsLength))
        }
        if let m = dShort.groups(s), Int(m[1])! <= 31, Int(m[2])! <= 31 {
            return DateTok(v: "\(m[1])/\(m[2])", short: true, rest: s.jsSlice(m[0].jsLength))
        }
        return nil
    }

    // MARK: Montos

    struct Amt { var v: String; var neg: Bool; var cur: String }

    static let amtTok = Rx(#"^\s*([-+]?\s?\(?\s?(?:S\/\.?|US\$|USD|PEN|EUR|€|\$)?\s?[-+]?\(?\s?\d[\d.,\s]*[.,]\d{2}\s?\)?\s?-?\s?(?:CR|DR|Cr|Dr)?)\s*$"#)
    static let curPEN = Rx(#"S\/|PEN"#), curUSD = Rx(#"US\$|USD|\$"#)
    static let numRx = Rx(#"(\d[\d.,\s]*)[.,](\d{2})(?!\d)"#)
    static let curLead = Rx(#"^\s*(?:S\/\.?|US\$|USD|PEN|EUR|€|\$)\s?"#)
    static let neg1 = Rx(#"^[-−]"#), neg2 = Rx(#"^-"#), neg3 = Rx(#"\("#), neg4 = Rx(#"-\s*(?:CR|DR)?\s*$"#), neg5 = Rx(#"\bDR\b"#, ci: true)
    static let seps = Rx(#"[.,\s]"#)

    /// Un token entero («$40.00», «-$1,175.13», «(45.00)», «45.00-», «S/ 12.50», «20,00 CR»).
    static func parseAmt(_ tok: String) -> Amt? {
        let t = tok.jsTrimmed
        guard amtTok.test(t) else { return nil }
        let cur = curPEN.test(t) ? "PEN" : curUSD.test(t) ? "USD" : ""
        guard let num = numRx.groups(t) else { return nil }
        let neg = neg1.test(curLead.replace(t, "")) || neg2.test(t) || neg3.test(t) || neg4.test(t) || neg5.test(t)
        return Amt(v: seps.replace(num[1], "") + "." + num[2], neg: neg, cur: cur)
    }

    // MARK: Encabezados

    static let KINDS: [(String, Rx)] = [
        ("balance", Rx(#"saldo|balance"#, ci: true)),
        ("net", Rx(#"\bnet\b|neto"#, ci: true)),
        ("debit", Rx(#"d[eé]bito|debit|cargo|retiro|withdraw|charge|money out|paid out|gasto|salida"#, ci: true)),
        ("credit", Rx(#"cr[eé]dito|credit|abono|dep[oó]sito|deposit|money in|paid in|ingreso|entrada"#, ci: true)),
        ("amount", Rx(#"monto|importe|amount|valor|total|cantidad|sum"#, ci: true)),
        ("desc", Rx(#"descripci|description|detalle|detail|concepto|memo|payee|merchant|movimiento|referencia|narrat|transaction(?!\s*date)"#, ci: true)),
        ("date", Rx(#"fecha|date|d[ií]a|\bday\b"#, ci: true)),
        ("type", Rx(#"tipo|type|status|estado|m[eé]todo|category|categor"#, ci: true))]
    static func kindOf(_ t: String) -> String { for (k, re) in KINDS where re.test(t) { return k }; return "" }
    static let NUMK: Set<String> = ["debit", "credit", "amount", "net", "balance"]

    struct HCell { var kind: String; var x: Double; var c: Double }

    static func header(_ l: PdfLine) -> [HCell]? {
        let every = l.items.map { HCell(kind: kindOf($0.str), x: $0.x, c: $0.x + $0.w / 2) }
        let cells = every.filter { !$0.kind.isEmpty }
        let hasDate = cells.contains { $0.kind == "date" }, hasNum = cells.contains { NUMK.contains($0.kind) }, hasDesc = cells.contains { $0.kind == "desc" }
        guard cells.count >= 2, l.items.count <= cells.count + 3, hasNum && (hasDate || hasDesc) else { return nil }
        return every.map { $0.kind.isEmpty ? HCell(kind: "other", x: $0.x, c: $0.c) : $0 }
    }

    // MARK: Renglones

    struct Row { var d: DateTok; var desc: String; var mov: Amt }

    static func joinStr(_ items: ArraySlice<PdfItem>) -> String { items.map(\.str).joined(separator: " ") }

    /// Un renglón de movimiento: empieza con una fecha (1 a 3 piezas de texto) y puede traer una segunda fecha.
    static func rowOf(_ items: [PdfItem], _ hdr: [HCell]?) -> Row? {
        var d1: DateTok?, used = 0
        if !items.isEmpty {
            for k in 1...min(3, items.count) {
                if let d = takeDate(minus.replace(joinStr(items[0..<k]), "-")), d.rest.jsTrimmed.isEmpty { d1 = d; used = k; break }
            }
        }
        guard let d1 else { return nil }
        var rest = Array(items[used...])
        if !rest.isEmpty {
            for k in 1...min(3, rest.count) {
                if let d = takeDate(joinStr(rest[0..<k])), d.rest.jsTrimmed.isEmpty { rest = Array(rest[k...]); break }
            }
        }
        let nums = rest.compactMap { it -> (it: PdfItem, a: Amt)? in
            guard let a = parseAmt(minus.replace(it.str, "-")), it.x > items[0].x + 20 else { return nil }
            return (it, a)
        }
        guard !nums.isEmpty else { return nil }
        let first = nums[0].it
        var mov: Amt?
        var descItems: [PdfItem]?
        let numCols = hdr?.filter { NUMK.contains($0.kind) } ?? []
        if let hdr, !numCols.isEmpty {
            var by: [String: Amt] = [:]
            for o in nums {
                let mid = o.it.x + o.it.w / 2
                guard let c = numCols.min(by: { abs($0.c - mid) < abs($1.c - mid) }) else { continue }
                if abs(c.c - mid) < 70 && by[c.kind] == nil { by[c.kind] = o.a }
            }
            if by["debit"] != nil || by["credit"] != nil {
                let dv = by["debit"].flatMap { (Double($0.v) ?? 0) != 0 ? $0 : nil }, cv = by["credit"].flatMap { (Double($0.v) ?? 0) != 0 ? $0 : nil }
                mov = dv.map { Amt(v: $0.v, neg: true, cur: $0.cur) } ?? cv.map { Amt(v: $0.v, neg: false, cur: $0.cur) }
            } else { mov = by["net"] ?? by["amount"] }
            let descCol = hdr.first { $0.kind == "desc" }
            let after = descCol.flatMap { dc in hdr.filter { $0.x > dc.x + 2 }.min(by: { $0.x < $1.x }) }
            if let dc = descCol {
                descItems = rest.filter { $0.x >= dc.x - 4 && (after == nil || $0.x < after!.x - 2) && parseAmt($0.str) == nil }
            }
        }
        if mov == nil { mov = nums[0].a }
        if descItems == nil || descItems!.isEmpty {
            descItems = rest.filter { $0.x < first.x && !(parseAmt($0.str) != nil && $0.x > items[0].x + 20) }
        }
        let desc = PDFx.clean(minus.replace(descItems!.map(\.str).joined(separator: " "), "-"))
        return Row(d: d1, desc: desc, mov: mov!)
    }

    static let AMT_SRC = #"[-+]?\s?\(?(?:S\/\.?|US\$|USD|PEN|\$)?\s?[-+]?\(?\d[\d.,]*[.,]\d{2}\)?-?(?:\s?(?:CR|DR))?"#
    static let amtTail = Rx(#"((?:\s+"# + AMT_SRC + #")+)\s*$"#), amtAll = Rx(AMT_SRC)
    static let dateTail = Rx(#"\s+(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2})$"#)

    /// Plan B si las piezas de texto no se separan bien por columna: toda la línea como texto.
    static func rowFromText(_ line: String) -> Row? {
        guard let d1 = takeDate(line) else { return nil }
        var s = d1.rest
        if let d2 = takeDate(s) { s = d2.rest }
        for _ in 0..<3 { guard let m = dateTail.index(s) else { break }; s = s.jsSlice(0, m) }
        guard let e = amtTail.exec(s) else { return nil }
        let amts = amtAll.all(e.groups[1]).map { $0[0] }
        guard let f = amts.first, let a = parseAmt(f) else { return nil }
        return Row(d: d1, desc: PDFx.clean(s.jsSlice(0, e.index)), mov: a)
    }

    static let SKIP = Rx(#"^(saldo|total|balance|previous|new balance|pago m[ií]nimo|minimum|beginning|ending|opening|closing|summary|resumen)"#, ci: true)

    // MARK: Nombre

    static let GENERIC = Rx(#"pago|payment|m[ií]nimo|minimum|l[ií]mite|limit|vence|due|estado|statement|extracto|cuenta|account|p[aá]gina|page|fecha|date|documento|movimientos|resumen|summary|saldo|balance|detalle|transacc|period"#, ci: true)
    static let nameSplit = Rx(#"\s[-–|·]\s"#), letters = Rx(#"[A-Za-zÁÉÍÓÚáéíóúñÑ]"#), d2 = Rx(#"\d{2,}"#), d3 = Rx(#"\d{3,}"#), badChars = Rx(#"[$%@]"#)

    /// Nombre probable del banco o emisor: la primera línea de arriba de la primera página que parezca un nombre.
    public static func guessName(_ doc: PdfDoc) -> String {
        guard let page = doc.pages.first else { return "" }
        for l in NazcaPDF.lines(page, 3).prefix(8) {
            var t = PDFx.clean(l.items.map(\.str).joined(separator: " "))
            if t.jsLength > 32, let i = nameSplit.index(t) { t = t.jsSlice(0, i).jsTrimmed }
            if t.jsLength < 3 || t.jsLength > 32 || d2.test(t) || letters.all(t).count < 3 || d3.test(t) || GENERIC.test(t) || badChars.test(t) { continue }
            return t
        }
        return ""
    }

    static let ext = Rx(#"\.[A-Za-z0-9]{2,4}$"#), punct = Rx(#"[_\-.]+"#), junk = Rx(#"\b(prueba|test|falso|estado|cuenta|movimientos|statement|export|descarga|download|csv|pdf|copia|copy|final|nuevo)\b"#, ci: true)
    static let digits = Rx(#"\d+"#), camera = Rx(#"^(img|dsc|scan|doc|file|data|untitled|sin titulo|whatsapp)\b"#, ci: true), wordStart = Rx(#"(^|\s)\S"#)

    /// Nombre probable a partir del nombre del archivo: «prueba-capital-one.csv» → «Capital One». Si no queda nada con sentido, «».
    public static func nameFromFile(_ fname: String?) -> String {
        var t = ext.replace(fname ?? "", "")
        t = punct.replace(t, " ")
        t = junk.replace(t, " ")
        t = digits.replace(t, " ")
        t = PDFx.clean(t)
        if letters.all(t).count < 3 || t.jsLength > 28 || camera.test(t) { return "" }
        return wordStart.replace(t) { $0[0].uppercased() }
    }

    // MARK: Tarjeta

    static let CARD_CUES: [Rx] = [
        Rx(#"credit card|tarjeta de cr[eé]dito|\bvisa\b|master ?card|american express|\bamex\b"#, ci: true),
        Rx(#"credit limit|l[ií]nea de cr[eé]dito|l[ií]mite de cr[eé]dito|credit line|cr[eé]dito disponible|available credit"#, ci: true),
        Rx(#"minimum (?:payment|amount) due|pago m[ií]nimo|min(?:imum)? payment"#, ci: true),
        Rx(#"payment due(?: date)?|fecha (?:l[ií]mite )?de pago|vencimiento|due date"#, ci: true),
        Rx(#"\bAPR\b|annual percentage rate|\bTEA\b|\bTCEA\b|tasa de inter[eé]s|interest rate"#, ci: true),
        Rx(#"new balance|previous balance|nuevo saldo|saldo anterior|statement closing|fecha de corte"#, ci: true)]
    static let PAYMENT = Rx(#"payment|pago|thank you|gracias|abono|refund|reembolso|devoluci|credit adjustment|reward|cashback|ajuste a favor|\bcr[eé]dito\b"#, ci: true)
    static let aprA = Rx(#"(?:\bAPR\b|annual percentage rate|\bTEA\b|\bTCEA\b|tasa(?: de inter[eé]s)?(?: anual)?|interest rate)[^\d%]{0,40}(\d{1,3}(?:[.,]\d{1,2})?)\s?%"#, ci: true)
    static let aprB = Rx(#"(\d{1,3}(?:[.,]\d{1,2})?)\s?%\s?\(?(?:Fixed|Variable|APR|TEA)"#, ci: true)
    static let minRx = Rx(#"(?:minimum (?:payment|amount) due|pago m[ií]nimo)[^\d$]{0,30}(?:S\/\.?|US\$|\$)?\s?([\d,]+\.\d{2})"#, ci: true)
    static let limRx = Rx(#"(?:credit limit|l[ií]nea de cr[eé]dito|l[ií]mite de cr[eé]dito)(?! available| disponible)[^\d$]{0,30}(?:S\/\.?|US\$|\$)?\s?([\d,]+\.\d{2})"#, ci: true)
    static let dueRx = Rx(#"(?:payment due(?: date)?|due date|fecha (?:l[ií]mite )?de pago|vencimiento)[:\s\-]{0,6}([A-Za-z0-9\/.,\s\-]{6,24})"#, ci: true)
    static let year20 = Rx(#"\b20\d{2}\b"#), isoStart = Rx(#"^\d{4}-"#), esWord = Rx(#"fecha|vencimiento"#, ci: true)
    static let l4A = Rx(#"(?:ending in|terminad[ao] en|account (?:number )?\*?|n[uú]mero de tarjeta|card (?:no\.?|number))[^\d]{0,12}(?:\*{2,}|x{2,}|•{2,}|\.{3,})?\s?(\d{4})\b"#, ci: true)
    static let l4B = Rx(#"(?:\*{2,}|x{3,}|•{3,})\s?(\d{4})\b"#, ci: true)
    static let startMinus = Rx(#"^-"#), commaSp = Rx(#"[,\s]"#)

    static func num(_ s: String) -> Double { Nazca.jsParseFloat(commaSp.replace(s, "")) ?? .nan }
    static var currentYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }

    struct Out { var date: String; var desc: String; var amt: String }

    struct CardRead {
        var isCard: Bool
        var info: Nazca.StatementResult.CardInfo
        var last4: String
        var sign: (String, String) -> String
    }

    static func cardInfo(_ doc: PdfDoc, _ rows: [Out]) -> CardRead {
        let t = PDFx.clean(doc.pages.map { $0.items.map(\.str).joined(separator: " ") }.joined(separator: " "))
        let cues = CARD_CUES.filter { $0.test(t) }.count
        var info = Nazca.StatementResult.CardInfo()
        let isCard = cues >= 3 && !rows.isEmpty
        if isCard {
            if let m = aprA.groups(t) ?? aprB.groups(t) { info.apr = num(m[1].replacingOccurrences(of: ",", with: ".")) }
            if let m = minRx.groups(t) { info.minPayment = num(m[1]) }
            if let m = limRx.groups(t) { info.limit = num(m[1]) }
            if let m = dueRx.groups(t), let d = takeDate(m[1].jsTrimmed) {
                let yr = year20.all(t).compactMap { Int($0[0]) }
                let Y = yr.max() ?? currentYear
                var iso: String?
                if let v = d.v {
                    if d.short { iso = nil }
                    else if isoStart.test(v) { iso = v }
                    else {
                        let q = v.split(separator: "/").map { Int($0) ?? 0 }
                        let es = esWord.test(m[0])
                        let dm = q[0] > 12 || es
                        iso = "\(q[2])-\(pad(dm ? q[1] : q[0]))-\(pad(dm ? q[0] : q[1]))"
                    }
                } else { iso = "\(d.yr != 0 ? d.yr : Y)-\(pad(d.mo))-\(pad(d.d))" }
                if let iso { info.dueDate = iso; info.dueDay = Int(iso.jsSlice(8, 10)) }
            }
        }
        let l4 = (l4A.groups(t) ?? l4B.groups(t))?[1] ?? ""
        let pays = rows.filter { PAYMENT.test($0.desc) }
        let negPays = pays.filter { startMinus.test($0.amt) }.count
        let usStyle = pays.isEmpty || Double(negPays) >= Double(pays.count) / 2
        let unsigned = !rows.contains { startMinus.test($0.amt) }
        let sign: (String, String) -> String = { desc, v in
            let a = startMinus.replace(v, "")
            if unsigned { return PAYMENT.test(desc) ? a : "-" + a }
            return usStyle ? (startMinus.test(v) ? a : "-" + a) : (startMinus.test(v) ? v : a)
        }
        return CardRead(isCard: isCard, info: info, last4: l4, sign: sign)
    }

    static let hasLetter = Rx(#"[A-Za-zÁÉÍÓÚáéíóúñÑ]"#)

    public static func read(_ doc: PdfDoc) -> Result {
        let all = doc.pages.flatMap { $0.items.map(\.str) }.joined(separator: " ")
        let years = year20.all(all).compactMap { Int($0[0]) }
        let year = years.max() ?? currentYear
        var out: [Out] = []
        var curs: [(String, Int)] = []
        var hdr: [HCell]?
        for page in doc.pages {
            for l in NazcaPDF.lines(page, 3) {
                if let h = header(l) { hdr = h; continue }
                var r = rowOf(l.items, hdr)
                if r == nil { r = rowFromText(PDFx.clean(minus.replace(l.items.map(\.str).joined(separator: " "), "-"))) }
                guard let r, !r.desc.isEmpty, hasLetter.test(r.desc), !SKIP.test(r.desc) else { continue }
                let d = r.d
                let date: String
                if let v = d.v { date = d.short ? "\(v)/\(year)" : v } else { date = "\(d.yr != 0 ? d.yr : year)-\(pad(d.mo))-\(pad(d.d))" }
                out.append(Out(date: date, desc: r.desc, amt: (r.mov.neg ? "-" : "") + r.mov.v))
                if !r.mov.cur.isEmpty {
                    if let i = curs.firstIndex(where: { $0.0 == r.mov.cur }) { curs[i].1 += 1 } else { curs.append((r.mov.cur, 1)) }
                }
            }
        }
        var best: (String, Int)?
        for c in curs where best == nil || c.1 > best!.1 { best = c }
        let card = cardInfo(doc, out)
        if card.isCard { for i in out.indices { out[i].amt = card.sign(out[i].desc, out[i].amt) } }
        let quote: (String) -> String = { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let text = out.isEmpty ? "" : "Fecha,Descripción,Monto\n" + out.map { "\($0.date),\(quote($0.desc)),\($0.amt)" }.joined(separator: "\n") + "\n"
        var res = Result()
        res.text = text; res.count = out.count; res.cur = best?.0 ?? ""; res.year = year
        res.name = guessName(doc); res.isCard = card.isCard; res.card = card.info; res.last4 = card.last4
        return res
    }
}
