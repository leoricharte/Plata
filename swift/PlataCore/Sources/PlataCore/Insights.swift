import Foundation

// Nota del mes, racha, half-time y otros números de "Insights". Port de monthSums / subGrowth / insightsModel / monthScore / gradeStreak /
// insLocked / svGoal / debtSim de dev/app/src/app.html. Solo los números: los textos y gráficos son de la interfaz.

public struct MonthSums: Equatable, Sendable {
    public var inc = 0.0, exp = 0.0, expV = 0.0, sub = 0.0
    public var cat: [String: Double] = [:]
    public var n = 0
}

public struct SubGrowth: Equatable, Sendable {
    public var cur: Double, base: Double, d: Double, pct: Double
    public var n: Int
    public var pts: Double
}

/// Racha de meses seguidos con la misma letra: a los 2 meses sube a "+", a los 4 en S es Diamante.
public enum StreakLevel: Equatable, Sendable { case none, plus, diamond }

public struct InsightsModel: Sendable {
    public var mk: String
    public var pmk: String
    public var isCur: Bool
    public var day: Int
    public var dim: Int
    public var cur: MonthSums
    public var prev: MonthSums
    /// El mes anterior sale del historial (no de movimientos).
    public var est: Bool
    public var hasPrev: Bool
    public var ps: Double?
    public var limCount: Int
    public var within: Int
    public var contrib: Bool
    public var rateC: Double?
    public var rateP: Double?
    public var sg: SubGrowth?
    public var score: Int
    public var delta: Double
    public var letter: String
    public var streak: Int
    public var plus: StreakLevel
}

public struct MonthScore: Equatable, Sendable {
    public var score: Int
    public var letter: String
    public var streak: Int
    public var plus: StreakLevel
}

public struct SavingGoal: Equatable, Sendable {
    public var goal: Double, rem: Double, pct: Double
    public var done: Bool
    public var mo: Int
}

public struct DebtSim: Equatable, Sendable { public var months: Int; public var interest: Double }

extension Engine {
    var insightsOn: Bool { settings["insights"] != JSONValue.bool(false) }
    var scoreOn: Bool { insightsOn && settings["score"] != JSONValue.bool(false) }

    static func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }

    /// El mes anterior a "YYYY-MM".
    static func prevMonthKey(_ mk: String) -> String {
        let y = Int(mk.prefix(4)) ?? 0
        let m = Int(String(mk.dropFirst(5).prefix(2))) ?? 1
        return String(LocalDate(year: y, month0: m - 2, day: 1).iso.prefix(7))
    }

    static func dayOf(_ date: String) -> Int {
        let s = Array(date.utf8)
        guard s.count >= 10 else { return 0 }
        return Int(String(decoding: s[8..<10], as: UTF8.self)) ?? 0
    }

    /// Ingresos y gastos de un mes (hasta el día `upTo`, si se indica), sin pagos de crédito ni transferencias.
    public func monthSums(_ mk: String, upTo: Int = 0) -> MonthSums {
        var o = MonthSums()
        for t in list("transactions") {
            let date = Engine.str(t["date"])
            if isPay(t) || String(date.prefix(7)) != mk { continue }
            if upTo > 0 && Engine.dayOf(date) > upTo { continue }
            let v = txUSD(t)
            o.n += 1
            if v > 0 {
                o.inc += v
            } else if txSub(t) != nil {
                o.exp -= v
                o.sub -= v
            } else {
                o.exp -= v
                o.expV -= v
                let cat = Engine.str(t["category"])
                let c = catOrder.contains(cat) ? cat : "Otros"
                o.cat[c] = (o.cat[c] ?? 0) - v
            }
        }
        return o
    }

    /// Cuánto crecieron las suscripciones frente al mes anterior. `subHist` (fotos mensuales) vive en el perfil.
    public func subGrowth(_ mk: String) -> SubGrowth? {
        let hist = data["subHist"]?.objectValue ?? [:]
        let pk = Engine.prevMonthKey(mk)
        let isCur = mk == String(today.iso.prefix(7))
        let subs = list("subs")
        var cur: Double
        if isCur {
            cur = 0
            for s in subs { cur += usd(Engine.num(s["amount"]), Engine.str(s["cur"])) }
        } else if let h = hist[mk]?.doubleValue {
            cur = h
        } else {
            return nil
        }
        var newTot = 0.0
        var nNew = 0
        for s in subs {
            let since = Engine.str(s["since"])
            if !since.isEmpty && String(since.prefix(7)) == mk {
                nNew += 1
                newTot += usd(Engine.num(s["amount"]), Engine.str(s["cur"]))
            }
        }
        let base: Double
        if let h = hist[pk]?.doubleValue { base = h } else if isCur { base = cur - newTot } else { return nil }
        let d = Engine.round2(cur - base)
        let pct = base > 0 ? d / base : (d > 0 ? 1 : 0)
        return SubGrowth(cur: cur, base: base, d: d, pct: pct, n: nNew, pts: d > 0.005 ? -Engine.clamp(pct * 40, 0, 10) : 0)
    }

    static func letter(for score: Int) -> String {
        score >= 90 ? "S" : score >= 78 ? "A" : score >= 64 ? "B" : score >= 50 ? "C" : score >= 35 ? "D" : "F"
    }

    /// Cuántas categorías con tope y cuántas respetaron su tope este mes.
    func budgetWithin(_ cat: [String: Double]) -> (lim: Int, within: Int) {
        let ab = budOf(activeSet())
        let lim = catOrder.filter { Engine.num(ab[$0]) > 0 }
        let within = lim.filter { (cat[$0] ?? 0) <= Engine.num(ab[$0]) }.count
        return (lim.count, within)
    }

    func savedThisMonth(_ mk: String, upTo day: Int?) -> Bool {
        list("savings").contains { sv in
            (sv["log"]?.arrayValue ?? []).contains { l in
                let date = Engine.str(l["date"])
                return !date.isEmpty && String(date.prefix(7)) == mk && (day == nil || Engine.dayOf(date) <= day!)
            }
        }
    }

    /// La nota de un mes (o del medio mes si `upTo` = 15). `month` nil = el mes actual.
    public func insightsModel(month: String? = nil, upTo: Int = 0) -> InsightsModel {
        let cmk = String(today.iso.prefix(7))
        let mk = month ?? cmk
        let isCur = mk == cmk
        let y = Int(mk.prefix(4)) ?? 0
        let mo = (Int(String(mk.dropFirst(5).prefix(2))) ?? 1) - 1
        let dimM = LocalDate.daysInMonth(year: y, month0: mo)
        let part = upTo > 0 || isCur
        let day = upTo > 0 ? upTo : (isCur ? today.day : dimM)
        let pmk = Engine.prevMonthKey(mk)
        let dimP = LocalDate.daysInMonth(year: y, month0: mo - 1)

        let cur = monthSums(mk, upTo: part ? day : 0)
        var prev = monthSums(pmk, upTo: part ? day : 0)
        var est = false
        if prev.n == 0, let h = list("history").first(where: { Engine.str($0["month"]) == pmk }) {
            let f = part ? min(1, Double(day) / Double(dimP)) : 1
            var p = MonthSums()
            p.inc = Engine.num(h["income"]) * f
            p.exp = Engine.num(h["expense"]) * f
            p.expV = Engine.num(h["expense"]) * f
            prev = p
            est = true
        }
        let hasPrev = prev.inc > 0 || prev.exp > 0
        func pct(_ a: Double, _ b: Double) -> Double? { b > 0 ? (a - b) / b : nil }

        let bw = budgetWithin(cur.cat)
        let contrib = savedThisMonth(mk, upTo: part ? day : nil)
        let rateC: Double? = cur.inc > 0 ? (cur.inc - cur.expV) / cur.inc : nil
        let rateP: Double? = prev.inc > 0 ? (prev.inc - prev.expV) / prev.inc : nil
        var A = 0.0, B = 0.0, Cc = 0.0
        let D = contrib ? 5.0 : 0.0
        let ps = pct(cur.expV, prev.expV)
        if let ps = ps { A = Engine.clamp(-ps * 50, -25, 25) }
        if let rc = rateC, let rp = rateP { B = Engine.clamp((rc - rp) * 60, -15, 15) }
        if bw.lim > 0 { Cc = (Double(bw.within) / Double(bw.lim) - 0.5) * 30 }
        let sg = subGrowth(mk)
        let E = sg?.pts ?? 0
        let raw = JS.round(50 + A + B + Cc + D + E)
        let score = Int(Engine.clamp(raw, 0, 100))
        let letter = Engine.letter(for: score)
        let sk = hasPrev ? gradeStreak(mk, letter) : (n: 1, plus: StreakLevel.none)
        return InsightsModel(mk: mk, pmk: pmk, isCur: isCur, day: day, dim: dimM, cur: cur, prev: prev, est: est, hasPrev: hasPrev, ps: ps,
                             limCount: bw.lim, within: bw.within, contrib: contrib, rateC: rateC, rateP: rateP, sg: sg, score: score, delta: A + B,
                             letter: letter, streak: sk.n, plus: sk.plus)
    }

    /// nil si ya hay datos suficientes para evaluar; si no, cuánto falta ("unos días", "un par de semanas", "alrededor de un mes").
    public func insightsLocked(_ m: InsightsModel) -> String? {
        if m.hasPrev && m.cur.n + m.prev.n >= 10 { return nil }
        let dimC = m.dim == 0 ? 30 : m.dim
        let left = max(0, dimC - m.day)
        let need = m.hasPrev ? 7 : left + 7
        return need <= 10 ? "unos días" : (need <= 21 ? "un par de semanas" : "alrededor de un mes")
    }

    /// La nota de un mes ya cerrado (o la del mes actual si ya hay datos). nil si no se puede evaluar.
    public func monthScore(_ mk: String) -> MonthScore? {
        if !scoreOn { return nil }
        let cmk = String(today.iso.prefix(7))
        if mk > cmk { return nil }
        if mk == cmk {
            let m = insightsModel()
            if insightsLocked(m) != nil || !m.hasPrev { return nil }
            return MonthScore(score: m.score, letter: m.letter, streak: m.streak, plus: m.plus)
        }
        let pk = Engine.prevMonthKey(mk)
        let cur = monthSums(mk), prev = monthSums(pk)
        if cur.n == 0 || !(prev.inc > 0 || prev.exp > 0) { return nil }
        let bw = budgetWithin(cur.cat)
        let contrib = savedThisMonth(mk, upTo: nil)
        let rC: Double? = cur.inc > 0 ? (cur.inc - cur.expV) / cur.inc : nil
        let rP: Double? = prev.inc > 0 ? (prev.inc - prev.expV) / prev.inc : nil
        var A = 0.0, B = 0.0, Cc = 0.0
        if prev.expV > 0 { A = Engine.clamp(-((cur.expV - prev.expV) / prev.expV) * 50, -25, 25) }
        if let rc = rC, let rp = rP { B = Engine.clamp((rc - rp) * 60, -15, 15) }
        if bw.lim > 0 { Cc = (Double(bw.within) / Double(bw.lim) - 0.5) * 30 }
        let E = subGrowth(mk)?.pts ?? 0
        let score = Int(Engine.clamp(JS.round(50 + A + B + Cc + E + (contrib ? 5 : 0)), 0, 100))
        let letter = Engine.letter(for: score)
        let sk = gradeStreak(mk, letter)
        return MonthScore(score: score, letter: letter, streak: sk.n, plus: sk.plus)
    }

    /// Meses seguidos (hacia atrás, hasta 6) con la misma letra.
    public func gradeStreak(_ mk: String, _ letter: String) -> (n: Int, plus: StreakLevel) {
        if !scoreOn { return (1, .none) }
        var n = 1
        let y = Int(mk.prefix(4)) ?? 0
        let mo = (Int(String(mk.dropFirst(5).prefix(2))) ?? 1) - 1
        for i in 0..<6 {
            let pk = String(LocalDate(year: y, month0: mo - 1 - i, day: 1).iso.prefix(7))
            guard let ms = monthScore(pk), ms.letter == letter else { break }
            n += 1
        }
        let plus: StreakLevel = n >= 2 ? ((letter == "S" && n >= 4) ? .diamond : .plus) : .none
        return (n, plus)
    }

    // MARK: metas y deudas

    public static func savingGoal(_ sv: JSONValue) -> SavingGoal {
        let goal = num(sv["goal"]), balance = num(sv["balance"]), monthly = num(sv["monthly"])
        let rem = max(0, goal - balance)
        let done = goal > 0 && rem <= 0
        let mo = (goal > 0 && monthly > 0 && rem > 0) ? Int((rem / monthly).rounded(.up)) : 0
        return SavingGoal(goal: goal, rem: rem, pct: goal > 0 ? min(100, balance / goal * 100) : 0, done: done, mo: mo)
    }

    /// Meses e intereses para pagar una deuda con un pago fijo; nil si el pago no cubre ni los intereses.
    public static func debtSim(balance: Double, apr: Double, payment: Double) -> DebtSim? {
        let r = apr / 1200
        var b = balance
        var n = 0
        var tot = 0.0
        if !(payment > 0) || payment <= b * r { return nil }
        while b > 0.005 && n < 600 {
            let i = b * r
            tot += i
            b = b + i - payment
            n += 1
        }
        return DebtSim(months: n, interest: tot)
    }
}
