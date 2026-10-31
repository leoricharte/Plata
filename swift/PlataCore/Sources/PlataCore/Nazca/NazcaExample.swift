import Foundation

/// «Enséñale a Nazca»: lee una captura de cualquier app o banco aprendiendo de DOS movimientos que la persona ya tiene.
/// La persona elige dos movimientos de su cuenta y sube la captura; Nazca los busca en el texto reconocido, aprende cómo está armada cada fila
/// (dónde va el monto, la descripción y la fecha, y cómo se distingue un gasto de un ingreso) y aplica esa misma forma al resto de la captura.
/// Sin red: el texto lo reconoce el dispositivo y todo lo demás es esta lógica. El resultado siempre pasa por la revisión antes de entrar a la cuenta.
public enum NazcaExample {
    /// Un trozo de texto reconocido en la captura. Las posiciones van de 0 a 1; `y` crece hacia ABAJO.
    public struct Box: Equatable, Sendable {
        public var text: String
        public var x: Double
        public var y: Double
        public var w: Double
        public var h: Double
        /// El color del texto: −1 rojizo, 1 verdoso, 0 neutro o desconocido.
        public var tone: Int
        public init(text: String, x: Double, y: Double, w: Double, h: Double, tone: Int = 0) {
            self.text = text; self.x = x; self.y = y; self.w = w; self.h = h; self.tone = tone
        }
        var right: Double { x + w }
    }

    /// Un movimiento que la persona ya tiene y que aparece en la captura.
    public struct Example: Equatable, Sendable {
        public var desc: String
        /// Negativo = gasto.
        public var amount: Double
        /// AAAA-MM-DD, o vacío si no se conoce.
        public var date: String
        public var cur: String
        public init(desc: String, amount: Double, date: String, cur: String = "") {
            self.desc = desc; self.amount = amount; self.date = date; self.cur = cur
        }
    }

    public enum DateMode: Equatable, Sendable, Codable {
        /// La fecha está en la misma fila, `dy` líneas arriba o abajo de la del monto.
        case row(Int)
        /// La fecha es un encabezado («Hoy», «12 oct») que vale para las filas de abajo.
        case header
        /// No se pudo aprender: se usa la fecha de hoy y se avisa.
        case none
    }

    public enum SignMode: Equatable, Sendable, Codable {
        /// El signo está escrito (− o +). Si no hay, se usa `noMarker`.
        case marker(noMarker: Int)
        /// El signo se distingue por el color del monto.
        case tone(expense: Int, income: Int)
        /// Todos los ejemplos tienen el mismo signo y nada los distingue.
        case fixed(Int)
    }

    public struct Template: Equatable, Sendable, Codable {
        public var amountX: Double
        public var rightAligned: Bool
        public var tol: Double
        public var descDy: Int
        public var descLeft: Double
        public var dateMode: DateMode
        public var signMode: SignMode
        public var cur: String
        /// 0 a 1: qué tan de acuerdo estaban los dos ejemplos.
        public var confidence: Double
    }

    public enum LearnError: Error, Equatable, Sendable {
        /// Ese ejemplo (0 o 1) no se encontró en la captura.
        case notFound(Int)
        case needTwo
    }

    public struct Extraction: Sendable {
        public var template: Template
        public var items: [Nazca.Item]
        /// `date`: a algún movimiento se le puso la fecha de hoy · `sign`: a algún movimiento se le adivinó el signo.
        public var flags: [String]
    }

    // MARK: Dinero

    struct Money: Equatable {
        var value: Double
        /// −1, +1 o 0 (sin signo escrito).
        var marker: Int
        var cur: String
    }

    private static let moneyRx = try! NSRegularExpression(
        pattern: #"^([+\-])?\s*(S/\.?|US\$|USD|PEN|\$)?\s*([+\-])?\s*(\d[\d.,' ]*)\s*(PEN|USD)?$"#, options: [.caseInsensitive])

    static func parseMoney(_ raw: String) -> Money? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for m in ["\u{2212}", "\u{2013}", "\u{2014}"] { t = t.replacingOccurrences(of: m, with: "-") }
        guard !t.isEmpty, t.count <= 24 else { return nil }
        let ns = t as NSString
        guard let m = moneyRx.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func g(_ i: Int) -> String { let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r) }
        let digits = g(4).trimmingCharacters(in: .whitespaces)
        guard let value = number(digits) else { return nil }
        let mark = g(1).isEmpty ? g(3) : g(1)
        let marker = mark == "-" ? -1 : (mark == "+" ? 1 : 0)
        let sym = (g(2) + g(5)).uppercased()
        let cur = sym.hasPrefix("S/") || sym == "PEN" ? "PEN" : (sym.isEmpty ? "" : "USD")
        return Money(value: value, marker: marker, cur: cur)
    }

    /// «1,234.50», «1.234,50», «25.00», «25,5», «1 234»: el último separador con 1 o 2 cifras detrás es el decimal.
    static func number(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "")
        guard !cleaned.isEmpty, cleaned.first?.isNumber == true, cleaned.last?.isNumber == true else { return nil }
        let seps = cleaned.indices.filter { cleaned[$0] == "." || cleaned[$0] == "," }
        guard let lastIdx = seps.last else { return Double(cleaned) }
        let after = cleaned.distance(from: lastIdx, to: cleaned.endIndex) - 1
        let sepChar = cleaned[lastIdx]
        let sameKind = seps.filter { cleaned[$0] == sepChar }.count
        let decimal: Bool
        if seps.count > sameKind { decimal = after >= 1 && after <= 2 }     // hay de los dos tipos: el último es el decimal
        else if sameKind > 1 { decimal = false }                              // «1.234.567»
        else { decimal = after >= 1 && after <= 2 }                           // un solo separador: 3 cifras detrás = miles
        var intPart = decimal ? String(cleaned[..<lastIdx]) : cleaned
        let frac = decimal ? String(cleaned[cleaned.index(after: lastIdx)...]) : ""
        intPart = intPart.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        return Double(frac.isEmpty ? intPart : intPart + "." + frac)
    }

    // MARK: Fechas

    private static let months: [String: Int] = [
        "ene": 1, "enero": 1, "jan": 1, "january": 1, "feb": 2, "febrero": 2, "february": 2, "mar": 3, "marzo": 3, "march": 3,
        "abr": 4, "abril": 4, "apr": 4, "april": 4, "may": 5, "mayo": 5, "jun": 6, "junio": 6, "june": 6, "jul": 7, "julio": 7, "july": 7,
        "ago": 8, "agosto": 8, "aug": 8, "august": 8, "set": 9, "sep": 9, "sept": 9, "setiembre": 9, "septiembre": 9, "september": 9,
        "oct": 10, "octubre": 10, "october": 10, "nov": 11, "noviembre": 11, "november": 11, "dic": 12, "diciembre": 12, "dec": 12, "december": 12,
    ]

    private static let isoRx = try! NSRegularExpression(pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#)
    private static let numRx = try! NSRegularExpression(pattern: #"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2}|\d{4})\b"#)
    private static let dmRx = try! NSRegularExpression(pattern: #"\b(\d{1,2})\s*(?:de\s+)?([a-z]{3,10})\.?(?:\s*(?:de\s+)?(\d{4}))?\b"#)
    private static let mdRx = try! NSRegularExpression(pattern: #"\b([a-z]{3,10})\.?\s+(\d{1,2})(?:,?\s*(\d{4}))?\b"#)

    private static func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }

    private static func ymd(_ iso: String) -> (Int, Int, Int)? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? (p[0], p[1], p[2]) : nil
    }

    private static func fmt(_ y: Int, _ m: Int, _ d: Int) -> String? {
        guard m >= 1, m <= 12, d >= 1, d <= 31 else { return nil }
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d
        let cal = calendar()
        guard let date = cal.date(from: dc) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        guard back.year == y, back.month == m, back.day == d else { return nil }   // 31 de febrero, etc.
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func addDays(_ iso: String, _ n: Int) -> String? {
        guard let (y, m, d) = ymd(iso) else { return nil }
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d
        let cal = calendar()
        guard let date = cal.date(from: dc), let moved = cal.date(byAdding: .day, value: n, to: date) else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: moved)
        return fmt(c.year ?? y, c.month ?? m, c.day ?? d)
    }

    /// Sin año: el más reciente que no quede en el futuro.
    private static func inferYear(_ m: Int, _ d: Int, today: String) -> Int? {
        guard let (ty, tm, td) = ymd(today) else { return nil }
        return (m * 100 + d) > (tm * 100 + td + 1) ? ty - 1 : ty
    }

    /// Una fecha dentro de un texto: «12/10/2026», «12 oct», «12 de octubre de 2026», «oct 12», «Hoy», «Ayer». `nil` si no hay.
    static func parseDate(_ raw: String, today: String) -> String? {
        let t = Nazca.norm(raw).isEmpty ? "" : strip(raw)
        guard !t.isEmpty else { return nil }
        func grab(_ rx: NSRegularExpression) -> [String]? {
            let ns = t as NSString
            guard let m = rx.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) else { return nil }
            return (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
        if let g = grab(isoRx), let y = Int(g[1]), let m = Int(g[2]), let d = Int(g[3]), let s = fmt(y, m, d) { return s }
        if let g = grab(numRx), let d = Int(g[1]), let m = Int(g[2]), var y = Int(g[3]) {
            if g[3].count == 2 { y += 2000 }
            if let s = fmt(y, m, d) { return s }
        }
        if let g = grab(dmRx), let d = Int(g[1]), let m = months[g[2]] {
            let y = Int(g[3]) ?? inferYear(m, d, today: today)
            if let y, let s = fmt(y, m, d) { return s }
        }
        if let g = grab(mdRx), let m = months[g[1]], let d = Int(g[2]) {
            let y = Int(g[3]) ?? inferYear(m, d, today: today)
            if let y, let s = fmt(y, m, d) { return s }
        }
        let words = t.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if words.contains("hoy") || words.contains("today") { return today.isEmpty ? nil : today }
        if words.contains("ayer") || words.contains("yesterday") { return addDays(today, -1) }
        return nil
    }

    private static func strip(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { out.append(u) }
        return String(out)
    }

    // MARK: Líneas

    struct Line {
        var boxes: [Box]
        var y: Double
    }

    static func lines(_ boxes: [Box]) -> [Line] {
        let sorted = boxes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.sorted { $0.y < $1.y }
        var out: [Line] = []
        for b in sorted {
            if let last = out.last, abs(last.y - b.y) < max(0.004, max(b.h, last.boxes.map(\.h).max() ?? 0) * 0.55) {
                out[out.count - 1].boxes.append(b)
                out[out.count - 1].y = out[out.count - 1].boxes.map(\.y).reduce(0, +) / Double(out[out.count - 1].boxes.count)
            } else { out.append(Line(boxes: [b], y: b.y)) }
        }
        return out.map { Line(boxes: $0.boxes.sorted { $0.x < $1.x }, y: $0.y) }
    }

    private static func tokens(_ s: String) -> Set<String> { Set(Nazca.norm(s).split(separator: " ").map(String.init).filter { $0.count >= 2 }) }

    /// Qué parte de las palabras del ejemplo está en el texto (0 a 1).
    private static func overlap(_ example: String, _ text: String) -> Double {
        let a = tokens(example)
        guard !a.isEmpty else { return 0 }
        let b = tokens(text)
        return Double(a.intersection(b).count) / Double(a.count)
    }

    // MARK: Aprender

    private struct Found {
        var line: Int
        var box: Box
        var descDy: Int
        var descBox: Box?
        var dateDy: Int?
        var header: Bool
        var score: Double
    }

    private static func isMoneyLike(_ b: Box) -> Bool { parseMoney(b.text) != nil }

    private static func find(_ ex: Example, in ls: [Line], today: String) -> Found? {
        var best: Found?
        for (li, line) in ls.enumerated() {
            for b in line.boxes {
                guard let m = parseMoney(b.text), abs(m.value - abs(ex.amount)) < 0.005 else { continue }
                var descDy = 0
                var descBox: Box?
                var score = ex.desc.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 0
                for dy in -2...2 {
                    let k = li + dy
                    guard ls.indices.contains(k) else { continue }
                    for c in ls[k].boxes where c != b && !isMoneyLike(c) {
                        let s = overlap(ex.desc, c.text)
                        if s > score { score = s; descDy = dy; descBox = c }
                    }
                }
                if !ex.desc.trimmingCharacters(in: .whitespaces).isEmpty && score < 0.34 { continue }
                var dateDy: Int?
                var header = false
                if !ex.date.isEmpty {
                    outer: for dy in [0, -1, 1, -2, 2] {
                        let k = li + dy
                        guard ls.indices.contains(k) else { continue }
                        for c in ls[k].boxes where c != b && parseDate(c.text, today: today) == ex.date { dateDy = dy; break outer }
                    }
                    var k = li - 1
                    while k >= 0 && k >= li - 14 {
                        let l = ls[k]
                        if !l.boxes.contains(where: isMoneyLike), l.boxes.contains(where: { parseDate($0.text, today: today) == ex.date }) { header = true; break }
                        k -= 1
                    }
                }
                let f = Found(line: li, box: b, descDy: descDy, descBox: descBox, dateDy: dateDy, header: header, score: score)
                if best == nil || f.score > best!.score { best = f }
            }
        }
        return best
    }

    public static func learn(examples: [Example], boxes: [Box], today: String) -> Result<Template, LearnError> {
        guard examples.count >= 2 else { return .failure(.needTwo) }
        let ls = lines(boxes)
        var found: [Found] = []
        for (i, ex) in examples.prefix(2).enumerated() {
            guard let f = find(ex, in: ls, today: today) else { return .failure(.notFound(i)) }
            found.append(f)
        }
        let a = found[0], b = found[1]
        var agree = 0.0, checks = 0.0
        // columna del monto
        let rightGap = abs(a.box.right - b.box.right), leftGap = abs(a.box.x - b.box.x)
        let rightAligned = rightGap <= leftGap
        let amountX = rightAligned ? (a.box.right + b.box.right) / 2 : (a.box.x + b.box.x) / 2
        let tol = max(0.05, min(rightAligned ? rightGap : leftGap, 0.2) * 1.5 + 0.03)
        checks += 1; if min(rightGap, leftGap) < 0.04 { agree += 1 }
        // descripción
        checks += 1; if a.descDy == b.descDy { agree += 1 }
        let descLeft = min(a.descBox?.x ?? 1, b.descBox?.x ?? 1)
        // fecha
        let dateMode: DateMode
        // ¿La fecha está en el mismo lugar relativo en TODAS las filas con monto? Si no, es un encabezado que vale para varias filas.
        func coverage(_ d: Int) -> Double {
            let rows = ls.indices.filter { ls[$0].boxes.contains(where: isMoneyLike) }
            guard !rows.isEmpty else { return 0 }
            let hit = rows.filter { i in
                let k = i + d
                return ls.indices.contains(k) && ls[k].boxes.contains { parseDate($0.text, today: today) != nil }
            }.count
            return Double(hit) / Double(rows.count)
        }
        if let da = a.dateDy, let db = b.dateDy, da == db, !(a.header && b.header && coverage(da) < 0.8) { dateMode = .row(da); agree += 1 }
        else if a.header && b.header { dateMode = .header; agree += 1 }
        else if let da = a.dateDy ?? b.dateDy, a.dateDy != nil || b.dateDy != nil, !(a.header || b.header) { dateMode = .row(da); agree += 0.5 }
        else if a.header || b.header { dateMode = .header; agree += 0.5 }
        else { dateMode = .none }
        checks += 1
        // signo
        let sa = examples[0].amount < 0 ? -1 : 1, sb = examples[1].amount < 0 ? -1 : 1
        let ma = parseMoney(a.box.text)?.marker ?? 0, mb = parseMoney(b.box.text)?.marker ?? 0
        let signMode: SignMode
        if (ma != 0 || mb != 0) {
            // sin marcador, el signo es el de los ejemplos que no lo traen; si todos lo traen, se supone ingreso
            let bare = [(ma, sa), (mb, sb)].filter { $0.0 == 0 }.map { $0.1 }
            signMode = .marker(noMarker: bare.first ?? 1)
            agree += 1
        } else if sa != sb, a.box.tone != 0, b.box.tone != 0, a.box.tone != b.box.tone {
            signMode = .tone(expense: sa < 0 ? a.box.tone : b.box.tone, income: sa < 0 ? b.box.tone : a.box.tone)
            agree += 1
        } else if sa == sb { signMode = .fixed(sa); agree += 0.5 }
        else { signMode = .fixed(sa); agree += 0 }
        checks += 1
        let cur = examples[0].cur.isEmpty ? examples[1].cur : examples[0].cur
        return .success(Template(amountX: amountX, rightAligned: rightAligned, tol: tol, descDy: a.descDy == b.descDy ? a.descDy : a.descDy,
                                 descLeft: descLeft, dateMode: dateMode, signMode: signMode, cur: cur, confidence: checks == 0 ? 0 : agree / checks))
    }

    // MARK: Aplicar

    public static func extract(_ t: Template, boxes: [Box], today: String) -> Extraction {
        let ls = lines(boxes)
        var items: [Nazca.Item] = []
        var usedToday = false, guessedSign = false
        var header = ""
        for (li, line) in ls.enumerated() {
            if !line.boxes.contains(where: isMoneyLike), let d = line.boxes.compactMap({ parseDate($0.text, today: today) }).first { header = d }
            for b in line.boxes {
                guard let m = parseMoney(b.text) else { continue }
                let edge = t.rightAligned ? b.right : b.x
                guard abs(edge - t.amountX) <= t.tol, m.value > 0 else { continue }
                // descripción
                let k = li + t.descDy
                var parts: [String] = []
                if ls.indices.contains(k) {
                    for c in ls[k].boxes where c != b && !isMoneyLike(c) && parseDate(c.text, today: today) == nil {
                        if t.descDy == 0 && c.x > b.x { continue }
                        if c.x + 0.05 < t.descLeft { continue }
                        parts.append(c.text.trimmingCharacters(in: .whitespaces))
                    }
                }
                let desc = parts.joined(separator: " ")
                if desc.isEmpty { continue }
                // fecha
                var date = ""
                switch t.dateMode {
                case .row(let dy):
                    let j = li + dy
                    if ls.indices.contains(j) { date = ls[j].boxes.compactMap { parseDate($0.text, today: today) }.first ?? "" }
                case .header: date = header
                case .none: break
                }
                if date.isEmpty { date = today; usedToday = true }
                // signo
                var sign = 1
                switch t.signMode {
                case .marker(let noMarker): if m.marker != 0 { sign = m.marker } else { sign = noMarker }
                case .tone(let expense, let income):
                    if b.tone == expense { sign = -1 } else if b.tone == income { sign = 1 }
                    else { sign = m.marker != 0 ? m.marker : -1; guessedSign = true }
                case .fixed(let s): sign = m.marker != 0 ? m.marker : s
                }
                let cur = m.cur.isEmpty ? t.cur : m.cur
                items.append(Nazca.Item(line: items.count + 1, date: date, desc: String(desc.prefix(90)), amount: Double(sign) * m.value, cur: cur))
            }
        }
        var flags: [String] = []
        if usedToday { flags.append("date") }
        if guessedSign { flags.append("sign") }
        return Extraction(template: t, items: items, flags: flags)
    }

    /// Arma el resultado que entiende la revisión de importaciones.
    public static func statement(_ x: Extraction, institution: String? = nil, label: String = "Captura") -> Nazca.StatementResult {
        let cur = x.template.cur.isEmpty ? (x.items.first?.cur ?? "") : x.template.cur
        var st = Nazca.StatementResult(bank: nil, kind: "corriente", label: label, cur: cur, items: x.items)
        // la institución solo NOMBRA la cuenta: el sello de banco verificado es de los lectores oficiales, no de una captura aprendida
        if let b = institution, !b.isEmpty { let n = Nazca.bankShort(b); st.name = n; st.label = n }
        let dates = x.items.map(\.date).filter { !$0.isEmpty }.sorted()
        if let f = dates.first, let l = dates.last { st.period = .init(from: f, to: l) }
        return st
    }
}
