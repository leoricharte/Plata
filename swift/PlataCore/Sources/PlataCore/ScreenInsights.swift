import Foundation

/// Los avisos que salen bajo cada meta de ahorro y cada deuda (`savingInsight` y `debtInsight` de la web).
public enum ScreenInsights {
    public struct Line: Equatable, Sendable {
        public enum Kind: Sendable { case warn, bad, ok }
        public var text: String
        public var kind: Kind
        public init(_ text: String, _ kind: Kind) { self.text = text; self.kind = kind }
    }

    static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    static func monthYear(_ d: LocalDate) -> String { months[d.month0] + " " + String(d.year) }
    static func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }

    /// `savingInsight`: una línea sobre el ritmo de aportes de una meta (nil si no hay nada que decir).
    /// `whole` da formato a un monto en la moneda de la meta.
    public static func saving(_ sv: JSONValue, today t: LocalDate, whole: (Double, String) -> String) -> Line? {
        let goal = Engine.num(sv["goal"]), balance = Engine.num(sv["balance"]), monthly = Engine.num(sv["monthly"])
        if !(goal > 0) || balance >= goal { return nil }
        let cur = Engine.str(sv["cur"])
        let mk = String(t.iso.prefix(7))
        let raw = (sv["log"]?.arrayValue ?? []).compactMap { l -> (date: String, amount: Double)? in
            let d = Engine.str(l["date"])
            return d.isEmpty ? nil : (d, Engine.num(l["amount"]))
        }
        let thisM = raw.filter { String($0.date.prefix(7)) == mk }.reduce(0.0) { $0 + $1.amount }
        let cutoff = t.adding(days: -90).iso
        let recent = raw.filter { $0.date >= cutoff }
        let last90 = recent.reduce(0.0) { $0 + $1.amount }
        let first = recent.reduce(t.iso) { $1.date < $0 ? $1.date : $0 }
        let diff = Double(t.days - (LocalDate(iso: first)?.days ?? t.days))
        let span = max(1.0, min(3.0, (diff / 30).rounded(.up)))
        let real = last90 / span
        let rem = goal - balance
        if !(monthly > 0) && !(real > 0) { return Line("Define un aporte mensual para ver cuándo llegas a tu meta.", .warn) }
        if thisM <= 0 && t.day >= 10 {
            return Line("Aún no has aportado este mes" + (monthly > 0 ? " (planeabas \(whole(monthly, cur)))" : "") + ".", .warn)
        }
        if monthly > 0 && real > 0 && real < monthly * 0.8 {
            let mo = Int((rem / real).rounded(.up))
            let d = LocalDate(year: t.year, month0: t.month0 + mo, day: 1)
            return Line("Tu ritmo real es de ~\(whole(real, cur))/mes: la meta llegaría en \(monthYear(d)).", .warn)
        }
        if thisM > 0 { return Line("Vas al día: ya aportaste \(whole(thisM, cur)) este mes.", .ok) }
        return nil
    }

    /// `debtInsight`: avisos de una tarjeta o préstamo. `util` es el uso del límite en %, `primary` la moneda principal,
    /// `k` el factor de escala de esa moneda y `whole` da formato a un monto en la moneda principal.
    public static func debt(_ card: JSONValue, util: Double, primary: String, k: Double, whole: (Double) -> String) -> [Line] {
        var out: [Line] = []
        let limit = Engine.num(card["limit"]), balance = Engine.num(card["balance"]), apr = Engine.num(card["apr"]), pay = Engine.num(card["payment"])
        if Engine.str(card["kind"]) == "card" && limit > 0 && util > 30 {
            out.append(Line("Usas el \(Int(util.rounded()))% de tu límite: mantenerlo bajo 30% ayuda a tu historial crediticio.", .warn))
        }
        if balance > 0 && apr > 0 && pay > 0 && Engine.str(card["cur"]) == primary {
            let xtra = 50 * k
            let a = Engine.debtSim(balance: balance, apr: apr, payment: pay), b = Engine.debtSim(balance: balance, apr: apr, payment: pay + xtra)
            if a == nil { out.append(Line("Tu pago mensual no alcanza a cubrir los intereses.", .bad)) }
            else if let a, let b, a.interest - b.interest >= 10 {
                out.append(Line("Pagando \(whole(xtra)) más al mes terminas \(plural(a.months - b.months, "mes", "meses")) antes y ahorras ~\(whole(a.interest - b.interest)) en intereses.", .ok))
            }
        }
        return out
    }
}
