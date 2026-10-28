import Foundation

/// Formato de montos como la web (`fmtC`, `fmtC2`, `fmtSC2`): símbolo de la moneda, miles con coma, signo "−" (menos tipográfico).
public enum Money {
    /// Símbolo de la moneda. Los que la tabla guarda con espacio al final ("PEN ") salen con espacio duro, como en la web.
    public static func symbol(_ cur: String, custom: String = "") -> String {
        let raw: String
        if let c = Currencies.table[cur] {
            raw = c.sym
        } else if !custom.isEmpty && cur == custom {
            raw = custom.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) ? custom + " " : custom
        } else {
            raw = Currencies.table["USD"]?.sym ?? "$"
        }
        return raw.hasSuffix(" ") ? String(raw.dropLast()) + "\u{00A0}" : raw
    }

    /// Decimales de la moneda (2, salvo las que no usan: yen, peso chileno…).
    public static func decimals(_ cur: String) -> Int { Currencies.table[cur]?.dec ?? 2 }

    static func group(_ digits: String) -> String {
        var out = "", n = 0
        for ch in digits.reversed() {
            if n > 0 && n % 3 == 0 { out.append(",") }
            out.append(ch)
            n += 1
        }
        return String(out.reversed())
    }

    /// `−$1,235`: sin decimales.
    public static func whole(_ n: Double, _ cur: String, custom: String = "") -> String {
        let r = JS.round(n)
        let body = group(String(format: "%.0f", abs(r)))
        return (r < 0 ? "−" : "") + symbol(cur, custom: custom) + body
    }

    /// `$1,234.50`: con los decimales de la moneda y sin signo.
    public static func exact(_ n: Double, _ cur: String, custom: String = "") -> String {
        let dec = decimals(cur)
        let s = String(format: "%.\(dec)f", abs(n))
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        return symbol(cur, custom: custom) + group(parts[0]) + (parts.count > 1 ? "." + parts[1] : "")
    }

    /// `+$1,234.50` / `−$1,234.50`
    public static func signed(_ n: Double, _ cur: String, custom: String = "") -> String {
        (n < 0 ? "−" : "+") + exact(n, cur, custom: custom)
    }
}
