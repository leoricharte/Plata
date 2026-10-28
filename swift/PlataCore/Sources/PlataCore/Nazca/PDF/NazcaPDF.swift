import Foundation

/// Un texto de una página con su posición (`{ str, x, y, w }` de `pdf.js` de la web): (x, y) es la esquina inferior izquierda del texto sobre la línea base; y crece hacia arriba.
public struct PdfItem: Equatable, Sendable {
    public var str: String
    public var x: Double
    public var y: Double
    public var w: Double
    public init(str: String, x: Double, y: Double, w: Double) { self.str = str; self.x = x; self.y = y; self.w = w }
}

public struct PdfPage: Sendable {
    public var w: Double
    public var h: Double
    public var items: [PdfItem]
    public init(w: Double, h: Double, items: [PdfItem]) { self.w = w; self.h = h; self.items = items }
    /// Todo el texto de la página, separado por espacios.
    var text: String { items.map(\.str).joined(separator: " ") }
}

public struct PdfDoc: Sendable {
    public var pages: [PdfPage]
    public var total: Int
    public var truncated: Bool
    public init(pages: [PdfPage], total: Int? = nil, truncated: Bool = false) { self.pages = pages; self.total = total ?? pages.count; self.truncated = truncated }
}

/// Los textos de una página agrupados por renglón (de arriba hacia abajo), cada uno de izquierda a derecha.
public struct PdfLine: Sendable {
    public var y: Double
    public var items: [PdfItem]
    public var text: String { items.map(\.str).joined(separator: " ") }
}

/// Lectura de PDF (puerto de `pdf.js` de la web, núcleo sin pantalla). Todo ocurre en el dispositivo; la clave solo se usa para abrir el archivo.
public enum NazcaPDF {
    public static let maxBytes = 15 * 1024 * 1024
    static let maxPages = 60, maxItems = 200_000

    /// Los códigos de error de la web: `not_pdf`, `too_big`, `need_password`, `bad_password`, `invalid`, `no_text`, `unavailable`.
    public enum Failure: String, Error, Equatable, Sendable {
        case notPDF = "not_pdf", tooBig = "too_big", needPassword = "need_password", badPassword = "bad_password", invalid, noText = "no_text", unavailable
    }

    /// El estándar deja que «%PDF-» aparezca dentro de los primeros 1024 bytes (algunos bancos anteponen texto o bytes de más).
    static func hasHeader(_ b: [UInt8]) -> Bool {
        let n = min(b.count - 4, 1024)
        if n <= 0 { return false }
        for i in 0..<n where b[i] == 37 && b[i + 1] == 80 && b[i + 2] == 68 && b[i + 3] == 70 && b[i + 4] == 45 { return true }
        return false
    }

    /// Agrupa los textos de una página en renglones (de arriba hacia abajo) y ordena cada uno de izquierda a derecha. `tol`: tolerancia vertical.
    public static func lines(_ page: PdfPage, _ tol: Double = 2.5) -> [PdfLine] {
        let order = page.items.enumerated().sorted { a, b in
            if a.element.y != b.element.y { return a.element.y > b.element.y }
            if a.element.x != b.element.x { return a.element.x < b.element.x }
            return a.offset < b.offset
        }
        var out: [PdfLine] = []
        for (_, it) in order {
            if let l = out.last, abs(l.y - it.y) <= tol { out[out.count - 1].items.append(it) } else { out.append(PdfLine(y: it.y, items: [it])) }
        }
        for k in out.indices {
            out[k].items = out[k].items.enumerated().sorted { a, b in a.element.x != b.element.x ? a.element.x < b.element.x : a.offset < b.offset }.map(\.element)
        }
        return out
    }
}

// MARK: - Utilidades que comparten los lectores

enum PDFx {
    static func r2(_ n: Double) -> Double { Nazca.jsRound(n * 100) / 100 }
    static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.005 }
    static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
    static func pad(_ n: Double) -> String { pad(Int(n)) }

    /// `String(t).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')`
    static func norm(_ t: String) -> String {
        var out = String.UnicodeScalarView()
        for u in t.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { out.append(u) }
        return String(out)
    }

    static let ws = Rx(#"\s+"#)
    /// `s.replace(/\s+/g, ' ')`
    static func squash(_ s: String) -> String { ws.replace(s, " ") }
    /// `s.replace(/\s+/g, ' ').trim()`
    static func clean(_ s: String) -> String { squash(s).jsTrimmed }

    /// El texto de todas las páginas unido con espacios y con los espacios repetidos reducidos a uno.
    static func flat(_ doc: PdfDoc) -> String { squash(doc.pages.map(\.text).joined(separator: " ")) }

    /// `parseFloat` de JavaScript: espacios al inicio, signo opcional y el prefijo numérico (`NaN` si no hay).
    static func parseFloat(_ s: String) -> Double {
        var t = Substring(s.jsTrimmed)
        var sign = 1.0
        if let c = t.first, c == "+" || c == "-" { if c == "-" { sign = -1 }; t = t.dropFirst() }
        guard let v = Nazca.jsParseFloat(String(t)) else { return .nan }
        return sign * v
    }

    /// `parseFloat` seguido de `Math.round(x * 100) / 100` (los montos de los estados de cuenta).
    static func money(_ s: String, strip: String = ",") -> Double {
        var t = s
        for ch in strip { t = t.replacingOccurrences(of: String(ch), with: "") }
        return r2(parseFloat(t))
    }

    static let commaSpace = Rx(#"[,\s]"#), commaDash = Rx(#"[,-]"#)
    /// `r2(parseFloat(s.replace(/[,\s]/g, '')))`
    static func numSp(_ s: String) -> Double { r2(parseFloat(commaSpace.replace(s, ""))) }
    /// `r2(parseFloat(s.replace(/[,-]/g, '')))`
    static func numDash(_ s: String) -> Double { r2(parseFloat(commaDash.replace(s, ""))) }

    /// `a.slice(from, to)` (índices no negativos; se ajustan al largo).
    static func slice<T>(_ a: [T], _ from: Int, _ to: Int? = nil) -> [T] {
        let lo = min(max(from, 0), a.count), hi = min(max(to ?? a.count, lo), a.count)
        return Array(a[lo..<hi])
    }

    /// `items.slice().sort((a, b) => a.x - b.x)` (orden estable).
    static func stableSortedByX(_ a: [PdfItem]) -> [PdfItem] {
        a.enumerated().sorted { $0.element.x != $1.element.x ? $0.element.x < $1.element.x : $0.offset < $1.offset }.map(\.element)
    }

    /// `items.find(i => re.test(i.str))`
    static func find(_ items: [PdfItem], _ re: Rx) -> PdfItem? { items.first { re.test($0.str) } }
    static func items(_ doc: PdfDoc) -> [PdfItem] { doc.pages.flatMap(\.items) }
    static func text(_ page: PdfPage) -> String { page.text }
    static func daysIn(_ y: Int, _ m: Int) -> Int {
        switch m { case 2: return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28; case 4, 6, 9, 11: return 30; default: return 31 }
    }
    /// Días desde 1970-01-01 de una fecha civil (el día puede desbordar el mes, como en `Date.UTC`).
    static func epochDay(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468 + (d - 1)
    }
    /// La fecha civil (año, mes, día) de un día desde 1970-01-01.
    static func civil(_ z0: Int) -> (y: Int, m: Int, d: Int) {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
    static func iso(_ y: Int, _ m: Int, _ d: Int) -> String { "\(y)-\(pad(m))-\(pad(d))" }

    static func upperFirst(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    /// `s.toLowerCase().replace(/(^|\s)\S/g, c => c.toUpperCase())`
    static func titleCase(_ s: String) -> String { Rx(#"(^|\s)\S"#).replace(s.lowercased()) { $0[0].uppercased() } }
}

/// Un valor por moneda (soles y dólares), como los `{ PEN, USD }` de los lectores de la web.
struct Cur2<T> {
    var pen: T
    var usd: T
    init(_ pen: T, _ usd: T) { self.pen = pen; self.usd = usd }
    init(both v: T) { pen = v; usd = v }
    subscript(_ c: String) -> T {
        get { c == "USD" ? usd : pen }
        set { if c == "USD" { usd = newValue } else { pen = newValue } }
    }
}
