import Foundation

/// Traductor de textos, puerto de `i18n.js` de la web (solo español → inglés).
///
/// La app se escribe en español. Cuando el idioma es inglés, cada texto que pasa por `Text`, `Button`,
/// `Label`… se traduce al vuelo: se «tokeniza» (fechas, meses, nombre y números pasan a marcadores),
/// se busca en el diccionario (`tr_en.json`, generado de `dev/app/src/tr/*.txt`) y se rellena la plantilla.
/// Lo que no está en el diccionario se queda tal cual.
enum Tr {
    static let langKey = "plata.lang"

    // MARK: - Idioma

    /// La preferencia guardada: `auto`, `es` o `en`.
    static var pref: String { UserDefaults.standard.string(forKey: langKey) ?? "auto" }

    /// El idioma efectivo: `es` o `en`.
    /// Los widgets usan el idioma que la app dejó en el snapshot.
    nonisolated(unsafe) static var forced: String?
    static var lang: String { forced ?? resolve(pref) }
    static var isEnglish: Bool { lang == "en" }

    static func resolve(_ p: String) -> String {
        p == "es" || p == "en" ? p : systemLang
    }

    /// El idioma del dispositivo (es o en; cualquier otro cae en inglés, como la web).
    private static let systemLang: String = {
        for l in Locale.preferredLanguages {
            let c = String(l.prefix(2)).lowercased()
            if c == "es" || c == "en" { return c }
        }
        return "en"
    }()

    /// Los nombres del usuario (apodo y nombre) que `tokenize` reemplaza por `{n}`. Lo fija `AppModel`.
    nonisolated(unsafe) static var names: [String] = []

    // MARK: - API

    /// Traduce un texto completo (conserva los espacios del inicio y del final).
    static func t(_ raw: String) -> String {
        if raw.isEmpty { return raw }
        let l = lang
        if l == "es" { return raw }
        let names = Self.names
        let sig = l + "|" + names.joined(separator: ",")
        if sig != cacheSig { cache.removeAll(); misses.removeAll(); cacheSig = sig }
        if let hit = cache[raw] { return hit }
        if misses.contains(raw) { return raw }
        let out = translate(raw, names: names)
        if cache.count + misses.count > 6000 { cache.removeAll(); misses.removeAll() }
        if let out { cache[raw] = out } else { misses.insert(raw) }
        return out ?? raw
    }

    /// Una abreviatura de mes suelta («ene» → «jan») para las etiquetas de los gráficos; conserva mayúscula o minúscula.
    static func monthAbbr(_ s: String) -> String {
        guard isEnglish, let i = esMonA.firstIndex(of: s.lowercased()) else { return s }
        return s.first?.isUppercase == true ? enMonA[i] : enMonA[i].lowercased()
    }

    /// Una plantilla con huecos `{0}`, `{1}`… (nombres de cuentas, etc.): se busca entera en el diccionario, sin tokenizar, y luego se rellena.
    static func f(_ tpl: String, _ args: String...) -> String {
        var s = tpl
        if lang != "es", let v = index.exact[tpl] { s = v }
        for (i, a) in args.enumerated() { s = s.replacingOccurrences(of: "{\(i)}", with: a) }
        return s
    }

    nonisolated(unsafe) private static var cache: [String: String] = [:]
    nonisolated(unsafe) private static var misses: Set<String> = []
    nonisolated(unsafe) private static var cacheSig = ""

    private static func translate(_ raw: String, names: [String]) -> String? {
        let scalars = Array(raw.unicodeScalars)
        var a = 0, b = scalars.count
        while a < b, CharacterSet.whitespacesAndNewlines.contains(scalars[a]) { a += 1 }
        while b > a, CharacterSet.whitespacesAndNewlines.contains(scalars[b - 1]) { b -= 1 }
        if a == b { return nil }
        var lead = String.UnicodeScalarView(); lead.append(contentsOf: scalars[0..<a])
        var tail = String.UnicodeScalarView(); tail.append(contentsOf: scalars[b..<scalars.count])
        var mid = String.UnicodeScalarView(); mid.append(contentsOf: scalars[a..<b])
        let core = reSpaces.replace(in: String(mid)) { _ in " " }
        guard let r = trString(core, names: names) else { return nil }
        return String(lead) + r + String(tail)
    }

    // MARK: - Fechas (inglés)

    private static let esMon = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    private static let esMonA = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    private static let esDow = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    private static let esDowA = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    private static let enMon = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let enMonA = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let enDow = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let enDowA = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    private static func safe(_ a: [String], _ i: Int) -> String { i >= 0 && i < a.count ? a[i] : "" }

    private static func fmtShort(_ dw: Int, _ d: Int, _ mo: Int, _ y: Int) -> String {
        let a = safe(enMonA, mo)
        let pre = dw >= 0 ? safe(enDowA, dw) + ", " : ""
        return pre + (y != 0 ? "\(a) \(d), \(y)" : "\(a) \(d)")
    }
    private static func fmtLong(_ dw: Int, _ d: Int, _ mo: Int) -> String { "\(safe(enDow, dw)), \(safe(enMon, mo)) \(d)" }
    private static func fmtMY(_ mo: Int, _ y: Int) -> String { "\(safe(enMon, mo)) \(y)" }
    private static func fmtMYA(_ mo: Int, _ y: Int) -> String { "\(safe(enMonA, mo)) \(y)" }

    // MARK: - Expresiones regulares

    private static func rx(_ p: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: p, options: opts)
    }

    private static let monAlt = esMon.joined(separator: "|")
    private static let monaAlt = esMonA.joined(separator: "|")
    private static let dowAlt = esDow.joined(separator: "|")
    private static let dowaAlt = esDowA.joined(separator: "|")

    private static let reSpaces = rx("\\s+")
    private static let reLong = rx("\\b(\(dowAlt)) (\\d{1,2}) de (\(monAlt))\\b", .caseInsensitive)
    private static let reMY = rx("\\b(\(monAlt)) (\\d{4})\\b", .caseInsensitive)
    private static let reSD = rx("\\b(\(dowaAlt)) (\\d{1,2}) (\(monaAlt))\\b(?: (\\d{4}))?", .caseInsensitive)
    private static let reD = rx("\\b(\\d{1,2}) (\(monaAlt))\\b(?: (\\d{4}))?", .caseInsensitive)
    private static let reMYA = rx("\\b(\(monaAlt)) (\\d{4})\\b", .caseInsensitive)
    private static let reMF = rx("\\b(\(monAlt))\\b", .caseInsensitive)
    private static let reNum = rx("[+−\\-]?(?:S/ ?|US\\$|CHF ?|KM ?|C\\$|A\\$|[$€£¥●] ?)?\\d(?:[\\d.,]*\\d)?%?")

    private static let plSing: [String: String] = [
        "días": "día", "meses": "mes", "semanas": "semana", "cuentas": "cuenta", "ocultas": "oculta", "registros": "registro",
        "cambios": "cambio", "ingresos": "ingreso", "categorías": "categoría", "gastos": "gasto", "movimientos": "movimiento",
        "metas": "meta", "tarjetas": "tarjeta", "eventos": "evento", "dígitos": "dígito", "años": "año", "previstos": "previsto", "pagos": "pago",
    ]
    private static let rePL = rx("(\\{\\d+\\}) (\(plSing.keys.joined(separator: "|")))(?![\\wáéíóúñ])", .caseInsensitive)
    private static let reQPlural = rx("\\{(\\d+)\\?([^:}]*):([^}]*)\\}")
    private static let reIdx = rx("\\{(\\d+)\\}")
    private static let reMonTok = rx("\\{([mM])\\}")
    private static let reDateTok = rx("\\{([defg])\\}")
    private static let reOnlyTok = rx("^(\\{[dDYym]\\}|\\s|·|[-–—])+$")
    private static let reDigit = rx("\\d")
    private static let reIdxTok = rx("\\{\\d+\\}")

    // MARK: - Tokenización

    private struct Ctx {
        var dts: [[Int]] = []
        var mons: [Int] = []
        var nums: [String] = []
        var long: [Int]?
        var my: [Int]?
        var mya: [Int]?
        var name = ""
    }

    private static func idx(_ arr: [String], _ w: String) -> Int { arr.firstIndex(of: w.lowercased()) ?? -1 }

    private static func tokenize(_ s: String, names: [String]) -> (key: String, ctx: Ctx) {
        var ctx = Ctx()
        var k = s
        k = reLong.replace(in: k) { g in ctx.long = [idx(esDow, g[1]), Int(g[2]) ?? 0, idx(esMon, g[3])]; return "{D}" }
        k = reMY.replace(in: k) { g in ctx.my = [idx(esMon, g[1]), Int(g[2]) ?? 0]; return "{Y}" }
        k = reSD.replace(in: k) { g in ctx.dts.append([idx(esDowA, g[1]), Int(g[2]) ?? 0, idx(esMonA, g[3]), Int(g[4]) ?? 0]); return "{d}" }
        k = reD.replace(in: k) { g in ctx.dts.append([-1, Int(g[1]) ?? 0, idx(esMonA, g[2]), Int(g[3]) ?? 0]); return "{d}" }
        k = reMYA.replace(in: k) { g in ctx.mya = [idx(esMonA, g[1]), Int(g[2]) ?? 0]; return "{y}" }
        k = reMF.replace(in: k) { g in ctx.mons.append(idx(esMon, g[1])); return "{m}" }
        for nm in names {
            let re = rx("(^|[^\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: nm) + "(?![\\p{L}\\p{N}])")
            if re.firstMatch(in: k, range: NSRange(location: 0, length: (k as NSString).length)) != nil {
                ctx.name = nm
                k = re.replace(in: k) { g in g[1] + "{n}" }
                break
            }
        }
        k = reNum.replace(in: k) { g in ctx.nums.append(g[0]); return "{\(ctx.nums.count - 1)}" }
        k = rePL.replace(in: k) { g in g[1] + " " + (plSing[g[2].lowercased()] ?? g[2]) }
        return (k, ctx)
    }

    private static func fillTpl(_ tpl: String, _ ctx: Ctx) -> String {
        var s = reQPlural.replace(in: tpl) { g in
            let i = Int(g[1]) ?? 0
            let digits = i < ctx.nums.count ? ctx.nums[i].filter { $0.isASCII && $0.isNumber } : ""
            return Int(digits) == 1 ? g[2] : g[3]
        }
        s = reIdx.replace(in: s) { g in
            let i = Int(g[1]) ?? 0
            return i < ctx.nums.count ? ctx.nums[i] : g[0]
        }
        s = s.replacingOccurrences(of: "{n}", with: ctx.name)
        s = reMonTok.replace(in: s) { g in
            guard let mo = ctx.mons.first else { return g[0] }
            let w = safe(enMon, mo)
            return g[1] == "M" ? cap(w) : w
        }
        s = reDateTok.replace(in: s) { g in
            let order = ["d", "e", "f", "g"]
            guard let i = order.firstIndex(of: g[1]), i < ctx.dts.count else { return g[0] }
            let x = ctx.dts[i]
            return fmtShort(x[0], x[1], x[2], x[3])
        }
        if s.contains("{D}") { if let l = ctx.long { s = s.replacingOccurrences(of: "{D}", with: fmtLong(l[0], l[1], l[2])) } }
        if s.contains("{y}") { if let m = ctx.mya { s = s.replacingOccurrences(of: "{y}", with: fmtMYA(m[0], m[1])) } }
        if s.contains("{Y}") { if let m = ctx.my { s = s.replacingOccurrences(of: "{Y}", with: fmtMY(m[0], m[1])) } }
        return s
    }

    // MARK: - Diccionario

    private struct Index { var exact: [String: String] = [:]; var lower: [String: String] = [:] }

    nonisolated(unsafe) private static var indexCache: Index?

    private static var index: Index {
        if let i = indexCache { return i }
        var ix = Index()
        for r in loadRows() {
            guard r.count >= 2 else { continue }
            let v = r[1]
            if v.isEmpty { continue }
            var key = r[0]
            let ns = key as NSString
            if reDigit.firstMatch(in: key, range: NSRange(location: 0, length: ns.length)) != nil,
               reIdxTok.firstMatch(in: key, range: NSRange(location: 0, length: ns.length)) == nil {
                var c = 0
                key = reNum.replace(in: key) { _ in defer { c += 1 }; return "{\(c)}" }
            }
            ix.exact[key] = v
            let lk = r[0].lowercased()
            if ix.lower[lk] == nil { ix.lower[lk] = v }
        }
        indexCache = ix
        return ix
    }

    private static func loadRows() -> [[String]] {
        guard let url = Bundle.main.url(forResource: "tr_en", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let any = try? JSONSerialization.jsonObject(with: data) as? [[String]] else { return [] }
        return any
    }

    private static func matchCase(_ src: String, _ out: String) -> String {
        guard let a = src.first, let o = out.first else { return out }
        let isUpper = String(a) != String(a).lowercased()
        let isLower = String(a) != String(a).uppercased()
        if isLower && !isUpper { return o.lowercased() + out.dropFirst() }
        if isUpper { return o.uppercased() + out.dropFirst() }
        return out
    }

    // MARK: - Reglas

    private static func rule(_ p: String, _ opts: NSRegularExpression.Options = [], _ f: @escaping ([String], [String]) -> String?) -> (NSRegularExpression, ([String], [String]) -> String?) {
        (rx(p, opts), f)
    }

    private static let rules: [(NSRegularExpression, ([String], [String]) -> String?)] = [
        rule("^Misma letra (\\d+) meses seguidos y sube a letra\\+ (dorada|platino)\\.$") { m, _ in
            "Same letter \(m[1]) months in a row and it becomes a \(m[2] == "dorada" ? "gold" : "platinum") letter+."
        },
        rule("^Misma letra (\\d+) meses seguidos y baja a letra- más roja\\.$") { m, _ in
            "Same letter \(m[1]) months in a row and it drops to a deeper red letter-."
        },
        rule("^Si sigues igual, al cuarto pasas a ([DF])-\\.$") { m, _ in "If it stays this way, on the fourth you drop to \(m[1])-." },
        rule("^Mantén la misma letra (\\d+) meses seguidos y al cuarto sube a letra\\+ dorada\\.$") { m, _ in
            "Keep the same letter for \(m[1]) months in a row and on the fourth it becomes a golden letter+."
        },
        rule("^Llevas (\\d+) de 2 meses con ([SABCDF])\\.$") { m, _ in "Month \(m[1]) of 2 at \(m[2])." },
        rule("^Al segundo subes a ([SABCDF])\\+\\.$") { m, _ in "On the second, you move up to \(m[1])+." },
        rule("^Si sigues igual, al segundo pasas a ([DF])-\\.$") { m, _ in "If nothing changes, on the second you drop to \(m[1])-." },
        rule("^Diamante · (\\d+) meses seguidos$") { m, _ in "Diamond · \(m[1]) months in a row" },
        rule("^Tu evaluación fue Diamante\\.$") { _, _ in "Your grade was Diamond." },
        rule("^Perfección\\. En todo su esplendor\\.$") { _, _ in "Perfection. In all its splendor." },
        rule("^([SABCDF][+-]) · (\\d+) meses seguidos$") { m, _ in "\(m[1]) · \(m[2]) months in a row" },
        rule("^Pago ([A-ZÁÉÍÓÚ\\u0250-\\uFFFF][^·]*)$") { m, _ in "Payment \(m[1])" },
        rule("^(\\d+) ([A-Z]{3}) en ([A-Z]{3})$") { m, _ in "\(m[1]) \(m[2]) in \(m[3])" },
        rule("^Tu evaluación fue ([FDCBAS][+-]?)\\.$") { m, _ in "Your grade was \(m[1])." },
        rule("^Principal: (\\S+) · Segunda: (\\S+)$") { m, _ in "Primary: \(m[1]) · Secondary: \(m[2])" },
        rule("^Principal: (.+)$") { m, names in "Primary: \(trCore(m[1], names: names) ?? m[1])" },
        rule("^Usar (\\S+) como principal$") { m, _ in "Use \(m[1]) as primary" },
        rule("^Saldo actual \\((.+)\\)$") { m, _ in "Current balance (\(m[1]))" },
        rule("^Monto \\((.+)\\)$") { m, _ in "Amount (\(m[1]))" },
        rule("^Cuenta al ejecutarlo \\(monto en (.+)\\)$") { m, _ in "Account when executed (amount in \(m[1]))" },
        rule("^Próximos (\\d+) meses$") { m, _ in "Next \(m[1]) months" },
        rule("^¿Cargar el perfil de (.+)\\?$") { m, _ in "Load \(m[1])’s profile?" },
        rule("^(.+) \\((S/|US\\$|C\\$|A\\$|\\p{Sc}|[A-Z]{2,3})\\)$") { m, names in
            guard let b = trCore(m[1], names: names) else { return nil }
            return "\(b) (\(m[2]))"
        },
        rule("^(.+) \\(monto en ([A-Z]{2,3})\\)$") { m, names in
            guard let b = trCore(m[1], names: names) else { return nil }
            return "\(b) (amount in \(m[2]))"
        },
        rule("^Empieza con una copia de los límites de «(.+)»\\. Luego los ajustas en Presupuesto\\.$") { m, names in
            "Starts with a copy of the limits from “\(trCore(m[1], names: names) ?? m[1])”. Then adjust them in Budget."
        },
        rule("^Estás viendo y editando este set, pero hoy está activo (?:«(.+)»|el presupuesto base)\\.$") { m, _ in
            "You are viewing and editing this set, but today \(m[1].isEmpty ? "the base budget" : "“" + m[1] + "”") is active."
        },
    ]

    // MARK: - Traducción

    private static func trCore(_ core: String, names: [String]) -> String? {
        let tk = tokenize(core, names: names)
        let key = tk.key
        let ix = index
        if let v = ix.exact[key] { return fillTpl(v, tk.ctx) }
        let allCaps = core == core.uppercased() && core != core.lowercased()
        if let v = ix.lower[key.lowercased()] {
            let o = fillTpl(v, tk.ctx)
            return allCaps ? o.uppercased() : matchCase(core, o)
        }
        let kn = key as NSString
        if reOnlyTok.firstMatch(in: key, range: NSRange(location: 0, length: kn.length)) != nil { return fillTpl(key, tk.ctx) }
        let cn = core as NSString
        for (re, f) in rules {
            guard let m = re.firstMatch(in: core, range: NSRange(location: 0, length: cn.length)) else { continue }
            var g: [String] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                g.append(r.location == NSNotFound ? "" : cn.substring(with: r))
            }
            return f(g, names)
        }
        return nil
    }

    private static func trString(_ core: String, names: [String]) -> String? {
        if let r = trCore(core, names: names) { return r }
        if let last = core.last, (last == "." || last == "!"), core.count > 3,
           let q = trCore(String(core.dropLast()), names: names) { return q + String(last) }
        if core.range(of: " · ") != nil, !core.hasPrefix(" · ") {
            let parts = core.components(separatedBy: " · ")
            var hit = false
            let out = parts.map { p -> String in
                if let q = trString(p, names: names) { hit = true; return q }
                return p
            }
            if hit { return out.joined(separator: " · ") }
        }
        return nil
    }
}

private extension NSRegularExpression {
    /// `String.replace(regex, fn)` de JavaScript: `g[0]` es todo el texto que coincide y `g[i]` cada grupo («» si no participó).
    func replace(in s: String, _ f: ([String]) -> String) -> String {
        let ns = s as NSString
        let ms = matches(in: s, range: NSRange(location: 0, length: ns.length))
        if ms.isEmpty { return s }
        var out = ""
        var last = 0
        for m in ms {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            var g: [String] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                g.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            out += f(g)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }
}
