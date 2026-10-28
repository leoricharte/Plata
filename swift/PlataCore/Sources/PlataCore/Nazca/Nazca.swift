import Foundation

/// Nazca, el motor de importación de Plata: lectura de CSV (port de `dev/app/src/core/nazca/csv.js`, sin pantalla).
/// Todo ocurre en el dispositivo. Entrada: el contenido del archivo. Salida: movimientos con fecha `AAAA-MM-DD`, descripción,
/// monto (negativo = sale dinero), moneda y saldo. Los resultados deben ser idénticos a los de la web: lo comprueban las pruebas
/// con vectores generados por `swift/tools/gen-nazca.mjs`.
public enum Nazca {
    public static let maxRows = 5000
    public static let maxBytes = 5 * 1024 * 1024

    public enum Failure: Error, Equatable { case tooBig, empty }

    /// Qué columna es cada cosa (−1 = ninguna).
    public struct Columns: Equatable, Sendable {
        public var date = -1, desc = -1, amount = -1, debit = -1, credit = -1, balance = -1, currency = -1, type = -1
        public init() {}
        public subscript(role: String) -> Int {
            get {
                switch role {
                case "date": return date
                case "desc": return desc
                case "amount": return amount
                case "debit": return debit
                case "credit": return credit
                case "balance": return balance
                case "currency": return currency
                default: return type
                }
            }
            set {
                switch role {
                case "date": date = newValue
                case "desc": desc = newValue
                case "amount": amount = newValue
                case "debit": debit = newValue
                case "credit": credit = newValue
                case "balance": balance = newValue
                case "currency": currency = newValue
                default: type = newValue
                }
            }
        }
    }

    public struct Analysis: Sendable {
        public var delim: String
        public var headerRow: Int
        public var headers: [String]
        public var width: Int
        public var cols: Columns
        public var dec: String
        public var order: String
        public var rows: [[String]]
        public var truncated: Bool
    }

    public struct Item: Equatable, Sendable {
        public var line: Int
        public var date: String
        public var desc: String
        public var amount: Double
        public var cur: String
        public var balance: Double?
        public init(line: Int = 0, date: String, desc: String, amount: Double, cur: String = "", balance: Double? = nil) {
            self.line = line; self.date = date; self.desc = desc; self.amount = amount; self.cur = cur; self.balance = balance
        }
    }

    public struct Skipped: Equatable, Sendable { public var blank = 0, unreadable = 0, total = 0 }

    public struct Options: Sendable {
        public var cols: [String: Int] = [:]
        public var dec: String?
        public var order: String?
        public init(cols: [String: Int] = [:], dec: String? = nil, order: String? = nil) { self.cols = cols; self.dec = dec; self.order = order }
    }

    // MARK: Texto

    /// Quita tildes y símbolos, pasa a minúsculas y deja solo `a-z 0-9 / $` separados por un espacio.
    public static func norm(_ s: String) -> String {
        var stripped = String.UnicodeScalarView()
        for u in s.decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { stripped.append(u) }
        var out = String.UnicodeScalarView()
        var pendingSpace = false
        for u in String(stripped).lowercased().unicodeScalars {
            let v = u.value
            let ok = (v >= 97 && v <= 122) || (v >= 48 && v <= 57) || v == 47 || v == 36
            if ok {
                if pendingSpace && !out.isEmpty { out.append(" ") }
                pendingSpace = false
                out.append(u)
            } else { pendingSpace = true }
        }
        return String(out)
    }

    /// UTF-8 si es válido; si no, Windows-1252 (lo que suele exportar Excel en español).
    public static func decode(_ data: Data) -> String {
        var s = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1) ?? ""
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        return s
    }

    // MARK: CSV con comillas (RFC 4180, tolerante)

    static func splitRows(_ text: [Unicode.Scalar], _ d: Unicode.Scalar) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = String.UnicodeScalarView(), q = false
        var i = 0
        let n = text.count
        func cellTrimmedEmpty() -> Bool { String(cell).jsTrimmed.isEmpty }
        while i < n {
            let c = text[i]
            if q {
                if c == "\"" {
                    if i + 1 < n && text[i + 1] == "\"" { cell.append("\""); i += 1 } else { q = false }
                } else { cell.append(c) }
            } else if c == "\"" && cellTrimmedEmpty() { q = true; cell = String.UnicodeScalarView() }
            else if c == d { row.append(String(cell)); cell = String.UnicodeScalarView() }
            else if c == "\n" || c == "\r" {
                if c == "\r" && i + 1 < n && text[i + 1] == "\n" { i += 1 }
                row.append(String(cell)); rows.append(row); row = []; cell = String.UnicodeScalarView()
                if rows.count > maxRows + 60 { break }
            } else { cell.append(c) }
            i += 1
        }
        if !cell.isEmpty || !row.isEmpty { row.append(String(cell)); rows.append(row) }
        return rows.map { r in
            r.map { x -> String in
                var v = String.UnicodeScalarView()
                for u in x.unicodeScalars {
                    let k = u.value
                    if k <= 8 || k == 0x0B || k == 0x0C || (k >= 0x0E && k <= 0x1F) || k == 0x7F { continue }
                    v.append(u)
                }
                return String(v).jsTrimmed
            }
        }.filter { r in r.contains { !$0.isEmpty } }
    }

    /// El separador es el que deja más filas con el mismo número de columnas (y más de una columna).
    static func detectDelim(_ text: String) -> String {
        let sample = Array(text.unicodeScalars.prefix(20000))
        var best = ",", bestScore = -1
        for d in [",", ";", "\t", "|"] {
            let rows = splitRows(sample, d.unicodeScalars.first!).prefix(40)
            var counts: [Int: Int] = [:]
            for r in rows where r.count > 1 { counts[r.count, default: 0] += 1 }
            var top = 0
            for (k, v) in counts { top = max(top, v * min(k, 8)) }
            if top > bestScore { bestScore = top; best = d }
        }
        return best
    }

    // MARK: Encabezados

    static func roleOf(_ h: String) -> String? {
        let n = norm(h)
        if n.isEmpty { return nil }
        for r in ["date", "balance", "type", "debit", "credit", "currency", "amount", "desc"] where roleRules[r]!.re.test(n) { return r }
        return nil
    }

    public static func roleName(forHeader h: String) -> String? { roleOf(h) }

    static func findHeader(_ rows: [[String]]) -> Int {
        var best = -1, bestScore = 1
        for i in 0..<min(rows.count, 40) {
            var roles = Set<String>()
            for h in rows[i] { if let r = roleOf(h) { roles.insert(r) } }
            let score = roles.count + (roles.contains("date") ? 1 : 0) + (roles.contains("amount") || roles.contains("debit") || roles.contains("credit") ? 1 : 0)
            if score > bestScore && rows[i].count >= 2 { best = i; bestScore = score }
        }
        return best
    }

    // MARK: Números

    static let curRx = Rx(#"(S\/\.?|US\$|USD|PEN|EUR|€|\$|soles|dolares|dólares)"#, ci: true)

    static let curPen = Rx(#"^(pen|s\/|s|sol|soles|nuevossoles|mn)$"#), curPen2 = Rx(#"^s\/"#)
    static let curUsd = Rx(#"^(usd|us\$|\$|us|dolar|dolares|me)$"#), curUsd2 = Rx(#"^us\$"#)
    static let curEur = Rx(#"^(eur|euro|euros)$"#), cur3 = Rx(#"^[a-z]{3}$"#)

    static func curOf(_ s: String) -> String {
        let n = norm(s).filter { !$0.isWhitespace }
        if n.isEmpty { return "" }
        if curPen.test(n) || curPen2.test(n) { return "PEN" }
        if curUsd.test(n) || curUsd2.test(n) { return "USD" }
        if curEur.test(n) || s.jsTrimmed == "€" { return "EUR" }
        if cur3.test(n) { return n.uppercased() }
        return ""
    }

    public static func currency(of s: String) -> String { curOf(s) }

    static let keepNumRx = Rx(#"[^\d.,]"#), tailDigitsRx = Rx(#"[.,](\d+)$"#)

    static func decimalVote(_ vals: [String]) -> String {
        var dot = 0, comma = 0
        let keep = keepNumRx, tail = tailDigitsRx
        for v in vals {
            let s = keep.replace(curRx.replace(v, ""), "")
            if s.isEmpty { continue }
            let chars = Array(s)
            let li = max(chars.lastIndex(of: ".") ?? -1, chars.lastIndex(of: ",") ?? -1)
            if chars.contains(".") && chars.contains(",") {
                if chars[li] == "." { dot += 3 } else { comma += 3 }
                continue
            }
            guard let m = tail.groups(s) else { continue }
            let digits = m[1].count
            let sep = chars[chars.count - digits - 1]
            let parts = chars.filter { $0 == sep }.count
            if digits <= 2 && parts == 1 { if sep == "." { dot += 2 } else { comma += 2 } }
            else if digits == 3 { if sep == "." { comma += 1 } else { dot += 1 } }
        }
        return comma > dot ? "," : "."
    }

    /// `parseFloat` de JavaScript sobre un texto de dígitos y puntos (toma el prefijo válido).
    static func jsParseFloat(_ s: String) -> Double? {
        var intPart = "", frac = "", seenDot = false
        for ch in s {
            if ch.isASCII && ch.isNumber { if seenDot { frac.append(ch) } else { intPart.append(ch) } }
            else if ch == "." && !seenDot { seenDot = true }
            else { break }
        }
        if intPart.isEmpty && frac.isEmpty { return nil }
        return Double((intPart.isEmpty ? "0" : intPart) + "." + (frac.isEmpty ? "0" : frac))
    }

    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    static let paren = Rx(#"^\(.*\)$"#), lead = Rx(#"^[-−–]"#), leadStrip = Rx(#"^[-−–]\s*"#)
    static let trail = Rx(#"[-−–]$"#), trailStrip = Rx(#"\s*[-−–]$"#)
    static let dbRx = Rx(#"\b(db|dr)$"#, ci: true), dbStrip = Rx(#"\s*(db|dr)$"#, ci: true)
    static let crRx = Rx(#"\bcr$"#, ci: true), crStrip = Rx(#"\s*cr$"#, ci: true)
    static let wsRx = Rx(#"\s"#), numOnly = Rx(#"^[\d.,]+$"#), hasDigit = Rx(#"\d"#)

    public static func parseAmount(_ v: String?, _ dec: String) -> Double? {
        var s = (v ?? "").jsTrimmed
        if s.isEmpty { return nil }
        var neg = false
        func dropFirst(_ s: String) -> String { String(String.UnicodeScalarView(s.unicodeScalars.dropFirst())) }
        if paren.test(s) { neg = true; s = String(String.UnicodeScalarView(s.unicodeScalars.dropFirst().dropLast())) }
        s = curRx.replace(s, " ").jsTrimmed
        if lead.test(s) { neg.toggle(); s = leadStrip.replace(s, "") }
        else if s.hasPrefix("+") { s = dropFirst(s) }
        if trail.test(s) { neg.toggle(); s = trailStrip.replace(s, "") }
        if dbRx.test(s) { neg = true; s = dbStrip.replace(s, "") }
        else if crRx.test(s) { s = crStrip.replace(s, "") }
        s = wsRx.replace(s, "")
        if !numOnly.test(s) || !hasDigit.test(s) { return nil }
        if dec == "," {
            s = s.replacingOccurrences(of: ".", with: "")
            if let r = s.range(of: ",") { s.replaceSubrange(r, with: ".") }
        } else { s = s.replacingOccurrences(of: ",", with: "") }
        if s.filter({ $0 == "." }).count > 1 { return nil }
        guard let n = jsParseFloat(s), n.isFinite else { return nil }
        return jsRound((neg ? -n : n) * 100) / 100
    }

    // MARK: Fechas

    static let months: [String: Int] = ["ene": 1, "jan": 1, "feb": 2, "mar": 3, "abr": 4, "apr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "aug": 8, "sep": 9, "set": 9, "oct": 10, "nov": 11, "dic": 12, "dec": 12]
    static func monIdx(_ w: String) -> Int { months[String(norm(w).prefix(3))] ?? 0 }

    struct DateParts: Equatable { var k: String; var a: Int; var b: Int; var c: Int }

    static let dateRx1 = Rx(#"^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:$|[ T])"#)
    static let dateRx2 = Rx(#"^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})(?:$|[ T,])"#)
    static let dateRx3 = Rx(#"^(\d{1,2})[-/. ]+([a-zA-ZáéíóúÁÉÍÓÚ]{3,})\.?[-/. ,]+(\d{2}|\d{4})(?:$|[ T])"#)
    static let dateRx4 = Rx(#"^([a-zA-Z]{3,})\.? (\d{1,2}),? (\d{4})(?:$|[ T])"#)
    static let dateRx5 = Rx(#"^(\d{4})(\d{2})(\d{2})$"#)

    static func dateParts(_ v: String?) -> DateParts? {
        let s = (v ?? "").jsTrimmed
        if let m = dateRx1.groups(s) { return DateParts(k: "ymd", a: Int(m[1])!, b: Int(m[2])!, c: Int(m[3])!) }
        if let m = dateRx2.groups(s) { return DateParts(k: "xxy", a: Int(m[1])!, b: Int(m[2])!, c: Int(m[3])!) }
        if let m = dateRx3.groups(s), monIdx(m[2]) > 0 { return DateParts(k: "ymd", a: Int(m[3])!, b: monIdx(m[2]), c: Int(m[1])!) }
        if let m = dateRx4.groups(s), monIdx(m[1]) > 0 { return DateParts(k: "ymd", a: Int(m[3])!, b: monIdx(m[1]), c: Int(m[2])!) }
        if let m = dateRx5.groups(s) { return DateParts(k: "ymd", a: Int(m[1])!, b: Int(m[2])!, c: Int(m[3])!) }
        return nil
    }

    /// dmy (Perú) salvo que los datos digan lo contrario.
    static func dateOrder(_ vals: [String]) -> String {
        var dmy = 0, mdy = 0
        for v in vals { if let p = dateParts(v), p.k == "xxy" { if p.a > 12 { dmy += 1 }; if p.b > 12 { mdy += 1 } } }
        return mdy > dmy ? "mdy" : "dmy"
    }

    static func daysIn(_ month: Int, _ year: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    public static func parseDate(_ v: String?, _ order: String = "dmy") -> String? {
        guard let p = dateParts(v) else { return nil }
        var y: Int, mo: Int, d: Int
        if p.k == "ymd" { y = p.a; mo = p.b; d = p.c }
        else if order == "mdy" { mo = p.a; d = p.b; y = p.c }
        else { d = p.a; mo = p.b; y = p.c }
        if y < 100 { y += 2000 }
        if y < 1990 || y > 2100 || mo < 1 || mo > 12 || d < 1 || d > daysIn(mo, y) { return nil }
        return String(format: "%04d-%02d-%02d", y, mo, d)
    }

    // MARK: Tipo (cargo/abono)

    static let typeNeg = Rx(#"^(cargo|cargos|d|db|dr|debito|debit|retiro|egreso|consumo|compra|salida)( |$)"#)
    static let typePos = Rx(#"^(abono|abonos|c|cr|credito|credit|deposito|ingreso|entrada|devolucion)( |$)"#)

    static func typeSign(_ v: String) -> Int {
        let n = norm(v)
        if typeNeg.test(n) { return -1 }
        if typePos.test(n) { return 1 }
        return 0
    }

    // MARK: Analizar

    static let dotAny = Rx(#"\."#), commaAny = Rx(#","#), commaTail = Rx(#",\d{1,2}$"#)
    static let textColRx = Rx(#"[a-zA-ZáéíóúñÁÉÍÓÚÑ]{3,}"#)

    public static func analyze(_ text: String) throws -> Analysis {
        if text.utf16.count > maxBytes * 2 { throw Failure.tooBig }
        let delim = detectDelim(text)
        let all = splitRows(Array(text.unicodeScalars), delim.unicodeScalars.first!)
        if all.isEmpty { throw Failure.empty }
        let hi = findHeader(all)
        let headers = hi >= 0 ? all[hi] : []
        let body = (hi >= 0 ? Array(all[(hi + 1)...]) : all).filter { $0.count >= 2 }
        let width = max(body.prefix(50).map(\.count).max() ?? 0, headers.count, 0)
        func col(_ j: Int) -> [String] { body.prefix(400).map { j < $0.count ? $0[j] : "" } }
        func share(_ j: Int, _ min: Double, _ f: (String) -> Bool) -> Bool {
            let v = col(j).filter { !$0.isEmpty }
            return !v.isEmpty && Double(v.filter(f).count) / Double(v.count) >= min
        }
        func isDateCol(_ j: Int) -> Bool { share(j, 0.6) { dateParts($0) != nil } }
        func isNumCol(_ j: Int) -> Bool { share(j, 0.6) { parseAmount($0, ".") != nil || parseAmount($0, ",") != nil } }
        func isTextCol(_ j: Int) -> Bool { share(j, 0.5) { textColRx.test($0) } }

        var map = Columns()
        var prios: [String: Double] = [:]
        for (j, h) in headers.enumerated() {
            guard let r = roleOf(h) else { continue }
            let n = norm(h), R = roleRules[r]!
            var prio = 1.0
            if let p = R.prefer, p.test(n) { prio = 3 }
            if let a = R.avoid, a.test(n) { prio = 0.5 }
            if r == "date" && !isDateCol(j) { continue }
            if (r == "amount" || r == "debit" || r == "credit" || r == "balance") && !isNumCol(j) { continue }
            if map[r] < 0 || prio > (prios[r] ?? 0) { map[r] = j; prios[r] = prio }
        }
        // Sin encabezado útil: se adivina por el contenido
        if map.date < 0 { for j in 0..<width where isDateCol(j) { map.date = j; break } }
        if map.amount < 0 && map.debit < 0 && map.credit < 0 {
            var nums: [Int] = []
            for j in 0..<width where j != map.date && j != map.balance && isNumCol(j) && !isDateCol(j) { nums.append(j) }
            if let f = nums.first { map.amount = f }
        }
        if map.desc < 0 {
            var best = -1, bestLen = 0.0
            let taken = [map.date, map.amount, map.debit, map.credit, map.balance, map.currency, map.type]
            for j in 0..<width {
                if taken.contains(j) || !isTextCol(j) { continue }
                let v = col(j)
                let len = Double(v.reduce(0) { $0 + $1.utf16.count }) / Double(max(v.count, 1))
                let uniq = Double(Set(v).count) / Double(max(v.count, 1))
                if len * uniq > bestLen { bestLen = len * uniq; best = j }
            }
            map.desc = best
        }
        if map.type >= 0 {
            let v = col(map.type).filter { !$0.isEmpty }
            if v.isEmpty || Double(v.filter { typeSign($0) != 0 }.count) / Double(v.count) < 0.8 { map.type = -1 }
        }
        var numVals: [String] = []
        for j in [map.amount, map.debit, map.credit, map.balance] where j >= 0 { numVals += col(j) }
        var dec = decimalVote(numVals)
        let dotRx = dotAny, commaRx = commaAny, tailRx = commaTail
        if delim == ";" && numVals.allSatisfy({ !dotRx.test($0) || !commaRx.test($0) }) && decimalVote(numVals) == "." && numVals.contains(where: { tailRx.test($0) }) { dec = "," }
        return Analysis(delim: delim, headerRow: hi, headers: headers, width: width, cols: map, dec: dec,
                        order: map.date >= 0 ? dateOrder(col(map.date)) : "dmy", rows: Array(body.prefix(maxRows)), truncated: body.count > maxRows)
    }

    // MARK: Convertir filas en movimientos

    static let skipDesc = Rx(#"^(total|totales|saldo anterior|saldo inicial|saldo final|saldo al|saldo disponible|subtotal)\b"#)

    static let wsRuns = Rx(#"\s+"#)
    static func cleanDesc(_ s: String) -> String {
        String(String.UnicodeScalarView(wsRuns.replace(s, " ").jsTrimmed.unicodeScalars.prefix(140)))
    }

    public static func extract(_ a: Analysis, _ opts: Options = Options()) -> (items: [Item], skipped: Skipped) {
        var c = a.cols
        for (k, v) in opts.cols { c[k] = v }
        let dec = opts.dec ?? a.dec, order = opts.order ?? a.order
        var out: [Item] = [], skipped = Skipped()
        for (i, r) in a.rows.enumerated() {
            func get(_ j: Int) -> String { j >= 0 && j < r.count ? r[j] : "" }
            let desc = cleanDesc(get(c.desc))
            if skipDesc.test(norm(desc)) || skipDesc.test(norm(r.first ?? "")) { skipped.total += 1; continue }
            let date = parseDate(get(c.date), order)
            var amount: Double?
            if c.amount >= 0 {
                amount = parseAmount(get(c.amount), dec)
                if let am = amount, c.type >= 0 { let sg = typeSign(get(c.type)); if sg != 0 { amount = Double(sg) * abs(am) } }
            }
            if amount == nil && (c.debit >= 0 || c.credit >= 0) {
                let d = parseAmount(get(c.debit), dec), cr = parseAmount(get(c.credit), dec)
                if let d, d != 0 { amount = -abs(d) } else if let cr, cr != 0 { amount = abs(cr) } else if d == 0 || cr == 0 { amount = 0 }
            }
            if date == nil && (amount == nil || amount == 0) && desc.isEmpty { skipped.blank += 1; continue }
            guard let date, let amt = amount, amt != 0 else { skipped.unreadable += 1; continue }
            var cur = curOf(get(c.currency))
            if cur.isEmpty {
                let src = [get(c.amount), get(c.debit), get(c.credit)].first { !$0.isEmpty } ?? ""
                cur = curOf(curRx.first(src) ?? "")
            }
            let bal = c.balance >= 0 ? parseAmount(get(c.balance), dec) : nil
            out.append(Item(line: i + 1, date: date, desc: desc, amount: amt, cur: cur, balance: bal))
        }
        return (out, skipped)
    }
}
