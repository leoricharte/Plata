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

    /// `parseFloat` seguido de `Math.round(x * 100) / 100` (los montos de los estados de cuenta).
    static func money(_ s: String, strip: String = ",") -> Double {
        var t = s
        for ch in strip { t = t.replacingOccurrences(of: String(ch), with: "") }
        return r2(Nazca.jsParseFloat(t) ?? .nan)
    }

    static func upperFirst(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    /// `s.toLowerCase().replace(/(^|\s)\S/g, c => c.toUpperCase())`
    static func titleCase(_ s: String) -> String { Rx(#"(^|\s)\S"#).replace(s.lowercased()) { $0[0].uppercased() } }
}
