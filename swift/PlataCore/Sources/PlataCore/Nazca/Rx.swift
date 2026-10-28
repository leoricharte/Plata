import Foundation

/// Expresión regular con la semántica de JavaScript para los patrones de Nazca:
/// `\d`, `\w` y `\b` solo ven ASCII (en ICU también letras y dígitos de otros alfabetos) y `$` es el final del texto (en ICU también antes de un salto de línea final).
struct Rx: @unchecked Sendable {
    let re: NSRegularExpression

    init(_ pattern: String, ci: Bool = false) {
        re = try! NSRegularExpression(pattern: Rx.translate(pattern), options: ci ? [.caseInsensitive] : [])
    }

    static func translate(_ p: String) -> String {
        var out = "", inClass = false, esc = false
        for ch in p {
            if esc {
                esc = false
                if ch == "d" { out += inClass ? "0-9" : "[0-9]" }
                else if ch == "w" { out += inClass ? "A-Za-z0-9_" : "[A-Za-z0-9_]" }
                else if ch == "b" && !inClass { out += "(?:(?<=[A-Za-z0-9_])(?![A-Za-z0-9_])|(?<![A-Za-z0-9_])(?=[A-Za-z0-9_]))" }
                else if ch == "B" && !inClass { out += "(?:(?<=[A-Za-z0-9_])(?=[A-Za-z0-9_])|(?<![A-Za-z0-9_])(?![A-Za-z0-9_]))" }
                else { out.append("\\"); out.append(ch) }
                continue
            }
            if ch == "\\" { esc = true; continue }
            if inClass { if ch == "]" { inClass = false }; out.append(ch); continue }
            if ch == "[" { inClass = true; out.append(ch); continue }
            if ch == "$" { out += "\\z"; continue }
            out.append(ch)
        }
        return out
    }

    private func full(_ s: String) -> NSRange { NSRange(location: 0, length: (s as NSString).length) }

    func test(_ s: String) -> Bool { re.firstMatch(in: s, range: full(s)) != nil }

    /// Los grupos de la primera coincidencia (el 0 es todo); un grupo que no participó queda vacío. `nil` si no hay coincidencia.
    func groups(_ s: String) -> [String]? {
        guard let m = re.firstMatch(in: s, range: full(s)) else { return nil }
        let ns = s as NSString
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    func first(_ s: String) -> String? { groups(s)?.first }

    /// Dónde empieza la primera coincidencia (en unidades UTF-16, como `index` de `exec` en JavaScript).
    func index(_ s: String) -> Int? {
        guard let m = re.firstMatch(in: s, range: full(s)) else { return nil }
        return m.range.location
    }

    /// Los grupos de la primera coincidencia junto con dónde empieza (UTF-16).
    func exec(_ s: String) -> (index: Int, groups: [String])? {
        guard let m = re.firstMatch(in: s, range: full(s)) else { return nil }
        let ns = s as NSString
        return (m.range.location, (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        })
    }

    /// Todas las coincidencias, cada una con sus grupos (el 0 es todo; un grupo que no participó queda vacío).
    func all(_ s: String) -> [[String]] {
        let ns = s as NSString
        return re.matches(in: s, range: full(s)).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    /// Reemplaza cada coincidencia por lo que devuelva `f` (recibe los grupos).
    func replace(_ s: String, _ f: ([String]) -> String) -> String {
        let ns = s as NSString
        var out = "", last = 0
        for m in re.matches(in: s, range: full(s)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let g = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += f(g)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    /// Reemplaza todas las coincidencias por un texto fijo (sin referencias a grupos).
    func replace(_ s: String, _ with: String) -> String {
        re.stringByReplacingMatches(in: s, range: full(s), withTemplate: NSRegularExpression.escapedTemplate(for: with))
    }
}

/// `String.prototype.trim` de JavaScript (no quita U+0085, sí quita U+FEFF).
let jsWhitespace: CharacterSet = {
    var c = CharacterSet(charactersIn: "\u{09}\u{0A}\u{0B}\u{0C}\u{0D}\u{20}\u{A0}\u{1680}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
    c.insert(charactersIn: "\u{2000}"..."\u{200A}")
    return c
}()

extension String {
    /// `s.slice(from, to)` en unidades UTF-16 (índices no negativos).
    func jsSlice(_ from: Int, _ to: Int? = nil) -> String {
        let ns = self as NSString
        let a = min(max(from, 0), ns.length), b = min(max(to ?? ns.length, a), ns.length)
        return ns.substring(with: NSRange(location: a, length: b - a))
    }
    /// `s.length` de JavaScript.
    var jsLength: Int { utf16.count }
    var jsTrimmed: String { trimmingCharacters(in: jsWhitespace) }
}
