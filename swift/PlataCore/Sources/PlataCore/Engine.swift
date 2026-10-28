import Foundation

// Motor de cálculo de Plata: resumen del mes, eventos futuros, proyección, simulaciones y simulador de deuda.
// Es un port de calc / genEvents / projection / dailySeries / simImpact / pendingItems / payoff de dev/app/src/app.html.
// Trabaja sobre un perfil ya migrado (ver `Migration`). Los resultados se prueban contra los de la web (Fixtures/engine.json).

// MARK: - Resultados

public struct CatSlice: Equatable, Sendable { public var name: String; public var v: Double; public var color: String }
public struct MonthBar: Equatable, Sendable { public var label: String; public var income: Double; public var expense: Double; public var cur: Bool }
public struct CardCalc: Equatable, Sendable { public var id: String; public var ub: Double; public var color: String; public var util: Double; public var interest: Double }
public struct SavingCalc: Equatable, Sendable { public var id: String; public var ub: Double; public var color: String }

public struct CalcResult: Sendable {
    public var mk: String
    public var dim: Int
    public var income: Double
    public var expense: Double
    public var incomeCount: Int
    public var cats: [CatSlice]
    public var catTot: [String: Double]
    public var months: [MonthBar]
    public var balance: Double
    public var cards: [CardCalc]
    public var debt: Double
    public var interest: Double
    public var savings: [SavingCalc]
    public var saved: Double
    public var savedMonthly: Double
    public var budgetTotal: Double
    public var subsTotal: Double
    public var expV: Double
    public var subSpent: Double
    /// Ids de movimientos, del más nuevo al más viejo.
    public var txIds: [String]
    public var monthTxIds: [String]
    /// Foto del total de suscripciones de este mes (`data.subHist[mk]`): quien llama decide si la guarda en el perfil.
    public var subHist: Double
}

public struct EngineEvent: Sendable {
    public var date: LocalDate
    public var name: String
    public var amt: Double
    public var type: String          // rec, sub, card, in, exp, sim
    public var key: String?
    public var pending = false
    public var orig: String?
    public var skipped = false
    public var edited = false
    public var form: String?
    public var srcId: String?
    public var cur: String?
    public var a0: Double = 0
}

public struct SeriesPoint: Equatable, Sendable { public var date: LocalDate; public var v: Double }

public struct TimelineEntry: Equatable, Sendable {
    public var name: String
    public var date: String          // "mié 28 oct"
    public var amt: Double
    public var type: String
    public var key: String?
    public var edited: Bool
    public var skipped: Bool
    public var after: Double
}

public struct ProjectionResult: Sendable {
    public var V: Double
    public var series: [SeriesPoint]
    public var timeline: [TimelineEntry]
    public var minV: Double
    /// Índice (semana) del primer punto en rojo, o nil.
    public var firstRed: Int?
}

public struct SimImpact: Equatable, Sendable {
    public var start: String
    public var end: String
    public var withMin: Double
    public var withDate: LocalDate
    public var withoutMin: Double
    public var status: String        // red, amber, ok
}

public struct PayoffResult: Equatable, Sendable { public var months: Int; public var interest: Double; public var ok: Bool }

public struct PendingItem: Equatable, Sendable { public var kind: String; public var id: String; public var date: String }   // kind: in, out, pay

public struct IncomeItem: Equatable, Sendable { public var id: String; public var date: String; public var amount: Double }

// MARK: - Motor

public struct Engine {
    public let data: JSONValue
    public let today: LocalDate
    public var variable: Bool

    public let primaryCurrency: String
    public let secondaryCurrency: String      // "" si no hay
    let fx: Double
    let catOrder: [String]
    let catColor: [String: String]

    static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    static let weekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    static let cardColors = ["#B98AE6", "#6D8BEA", "#EDB03E", "#F08FB0", "#5CC8C0"]
    static let weeks = 52

    public init(profile: Profile, today: LocalDate, variable: Bool = true) {
        let d = profile.raw
        self.data = d
        self.today = today
        self.variable = variable

        let settings = d["settings"] ?? .object([:])
        let custom = settings["customCur"]?.stringValue ?? ""
        func known(_ c: String) -> Currency? {
            if let t = Currencies.table[c] { return t }
            if !custom.isEmpty && c == custom { return Currency(sym: c, name: "Personalizada", rate: 1, k: 1) }
            return nil
        }
        let c1 = settings["currency"]?.stringValue ?? ""
        let p = known(c1) != nil ? c1 : "USD"
        let c2 = settings["currency2"]?.stringValue ?? ""
        let s = (known(c2) != nil && c2 != p) ? c2 : ""
        self.primaryCurrency = p
        self.secondaryCurrency = s

        let fxSet = settings["fx"]?.doubleValue ?? 0
        if fxSet > 0 {
            self.fx = fxSet
        } else if !s.isEmpty, let rp = known(p)?.rate, let rs = known(s)?.rate {
            // Number((rate_s / rate_p).toPrecision(4))
            self.fx = Double(String(format: "%.4g", rs / rp)) ?? 1
        } else {
            self.fx = 1
        }

        var order: [String] = []
        var colors: [String: String] = ["Ingreso": "#22B573"]
        for c in d["cats"]?.arrayValue ?? [] {
            let name = c["name"]?.stringValue ?? ""
            order.append(name)
            let col = c["color"]?.stringValue ?? ""
            colors[name] = col.isEmpty ? "#C9CBD1" : col
        }
        self.catOrder = order
        self.catColor = colors
    }

    // MARK: lectura del perfil

    func list(_ key: String) -> [JSONValue] { data[key]?.arrayValue ?? [] }
    var settings: JSONValue { data["settings"] ?? .object([:]) }

    static func num(_ v: JSONValue?) -> Double {
        guard let v = v else { return 0 }
        switch v {
        case .number(let n): return n.isNaN ? 0 : n
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces)) ?? 0
        case .bool(let b): return b ? 1 : 0
        default: return 0
        }
    }
    static func str(_ v: JSONValue?) -> String { v?.stringValue ?? "" }
    static func idStr(_ v: JSONValue?) -> String { v.map { JS.string($0) } ?? "undefined" }
    static func int(_ v: JSONValue?) -> Int {
        let n = num(v)
        guard n.isFinite, abs(n) < 1e9 else { return 0 }
        return Int(n.rounded(.towardZero))
    }

    /// Orden estable por comparador al estilo JS (negativo, cero, positivo).
    static func stableSort<T>(_ a: [T], _ cmp: (T, T) -> Int) -> [T] {
        let sorted = a.indices.sorted { (i: Int, j: Int) -> Bool in
            let c = cmp(a[i], a[j])
            if c != 0 { return c < 0 }
            return i < j
        }
        return sorted.map { a[$0] }
    }

    // MARK: monedas

    /// Pasa un monto de su moneda a la principal (`usd` de la web).
    public func usd(_ n: Double, _ cur: String) -> Double {
        (!secondaryCurrency.isEmpty && cur == secondaryCurrency) ? n / fx : n
    }
    public func fromUSD(_ n: Double, _ cur: String) -> Double {
        (!secondaryCurrency.isEmpty && cur == secondaryCurrency) ? n * fx : n
    }

    func accOf(_ id: JSONValue?) -> JSONValue? {
        let accounts = list("accounts")
        if let id = id, !id.isNull {
            if let a = accounts.first(where: { $0["id"] == id }) { return a }
            if let c = list("cards").first(where: { $0["id"] == id }) { return c }
        }
        return accounts.first
    }
    func accCur(_ id: JSONValue?) -> String { Engine.str(accOf(id)?["cur"]) }

    func txUSD(_ t: JSONValue) -> Double { usd(Engine.num(t["amount"]), accCur(t["acc"])) }

    // MARK: categorías y suscripciones

    static let payCategory = "Pago de crédito", xferCategory = "Transferencia"
    func isPay(_ t: JSONValue) -> Bool {
        let c = Engine.str(t["category"])
        return c == Engine.payCategory || c == Engine.xferCategory
    }

    static func bankNorm(_ s: String) -> String {
        let folded = s.lowercased().decomposedStringWithCanonicalMapping
        let scalars = folded.unicodeScalars.filter { !(0x0300...0x036F).contains($0.value) }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: scalars)
        return String(out)
    }

    /// La suscripción a la que corresponde un gasto (por su id o por el nombre en la nota), o nil.
    func txSub(_ t: JSONValue) -> JSONValue? {
        if Engine.num(t["amount"]) >= 0 || isPay(t) { return nil }
        let subs = list("subs")
        if JS.truthy(t["sub"]), let id = t["sub"], let s = subs.first(where: { $0["id"] == id }) { return s }
        let note = Engine.str(t["note"])
        if note.isEmpty { return nil }
        let n = Engine.bankNorm(note).trimmingCharacters(in: .whitespacesAndNewlines)
        return subs.first(where: { Engine.bankNorm(Engine.str($0["name"])).trimmingCharacters(in: .whitespacesAndNewlines) == n })
    }

    // MARK: presupuesto

    /// El set de presupuesto que rige hoy (o nil: el presupuesto base).
    public func activeSet() -> JSONValue? {
        let t = today.iso
        let sets = list("budgetSets").filter { Engine.str($0["from"]) <= t && Engine.str($0["to"]) >= t }
        let sorted = Engine.stableSort(sets) { (a: JSONValue, b: JSONValue) -> Int in
            Engine.str(a["from"]) < Engine.str(b["from"]) ? 1 : -1
        }
        return sorted.first
    }
    func budOf(_ set: JSONValue?) -> [String: JSONValue] {
        if let s = set { return s["budget"]?.objectValue ?? [:] }
        return data["budget"]?.objectValue ?? [:]
    }

    // MARK: calc

    public func calc() -> CalcResult {
        let mk = String(today.iso.prefix(7))
        let txs = Engine.stableSort(list("transactions")) { (a: JSONValue, b: JSONValue) -> Int in
            let da = Engine.str(a["date"]), db = Engine.str(b["date"])
            if da < db { return 1 }
            if da > db { return -1 }
            let x = Engine.idNumber(b["id"]) - Engine.idNumber(a["id"])
            return x > 0 ? 1 : (x < 0 ? -1 : 0)
        }
        let monthTx = txs.filter { String(Engine.str($0["date"]).prefix(7)) == mk }
        let flowTx = monthTx.filter { !isPay($0) }
        let incTx = flowTx.filter { Engine.num($0["amount"]) > 0 }
        var income = 0.0
        for t in incTx { income += txUSD(t) }
        var expSum = 0.0
        for t in flowTx where Engine.num(t["amount"]) < 0 { expSum += txUSD(t) }
        let expense = -expSum

        var catTot: [String: Double] = [:]
        var subSpent = 0.0
        for t in flowTx where Engine.num(t["amount"]) < 0 {
            if txSub(t) != nil { subSpent -= txUSD(t); continue }
            let cat = Engine.str(t["category"])
            let c = catOrder.contains(cat) ? cat : "Otros"
            catTot[c] = (catTot[c] ?? 0) - txUSD(t)
        }
        var cats: [CatSlice] = []
        for c in catOrder where (catTot[c] ?? 0) > 0 {
            cats.append(CatSlice(name: c, v: catTot[c] ?? 0, color: catColor[c] ?? "#C9CBD1"))
        }

        let hist = Engine.stableSort(list("history")) { (a: JSONValue, b: JSONValue) -> Int in
            Engine.str(a["month"]) < Engine.str(b["month"]) ? -1 : 1
        }
        var months: [MonthBar] = hist.suffix(5).map { (h: JSONValue) -> MonthBar in
            let mm = Engine.int(.string(String(Engine.str(h["month"]).dropFirst(5).prefix(2))))
            let label = (mm >= 1 && mm <= 12) ? Engine.months[mm - 1] : ""
            return MonthBar(label: label, income: Engine.num(h["income"]), expense: Engine.num(h["expense"]), cur: false)
        }
        months.append(MonthBar(label: Engine.months[today.month0], income: income, expense: expense, cur: true))

        var balance = 0.0
        for a in list("accounts") { balance += usd(Engine.num(a["balance"]), Engine.str(a["cur"])) }

        var cards: [CardCalc] = []
        var debt = 0.0, interest = 0.0
        for (i, c) in list("cards").enumerated() {
            let ub = usd(Engine.num(c["balance"]), Engine.str(c["cur"]))
            let col = Engine.str(c["color"])
            let limit = Engine.num(c["limit"])
            let util = limit > 0 ? JS.round(Engine.num(c["balance"]) / limit * 100) : 0
            let intr = ub * Engine.num(c["apr"]) / 100 / 12
            cards.append(CardCalc(id: Engine.idStr(c["id"]), ub: ub, color: col.isEmpty ? Engine.cardColors[i % 5] : col, util: util, interest: intr))
            debt += ub
            interest += intr
        }
        var savings: [SavingCalc] = []
        var saved = 0.0, savedMonthly = 0.0
        for (i, s) in list("savings").enumerated() {
            let ub = usd(Engine.num(s["balance"]), Engine.str(s["cur"]))
            let col = Engine.str(s["color"])
            savings.append(SavingCalc(id: Engine.idStr(s["id"]), ub: ub, color: col.isEmpty ? Engine.cardColors[(i + 3) % 5] : col))
            saved += ub
            savedMonthly += usd(Engine.num(s["monthly"]), Engine.str(s["cur"]))
        }

        let dim = LocalDate.daysInMonth(year: today.year, month0: today.month0)
        let bud = budOf(activeSet())
        var budgetTotal = 0.0
        for k in catOrder { budgetTotal += Engine.num(bud[k]) }
        var subsTotal = 0.0
        for s in list("subs") { subsTotal += usd(Engine.num(s["amount"]), Engine.str(s["cur"])) }

        return CalcResult(mk: mk, dim: dim, income: income, expense: expense, incomeCount: incTx.count, cats: cats, catTot: catTot, months: months,
                          balance: balance, cards: cards, debt: debt, interest: interest, savings: savings, saved: saved, savedMonthly: savedMonthly,
                          budgetTotal: budgetTotal, subsTotal: subsTotal, expV: expense - subSpent, subSpent: subSpent,
                          txIds: txs.map { Engine.idStr($0["id"]) }, monthTxIds: monthTx.map { Engine.idStr($0["id"]) },
                          subHist: Engine.round2(subsTotal))
    }

    /// `(b.id || 0)` como número para ordenar (NaN si no es numérico).
    static func idNumber(_ v: JSONValue?) -> Double {
        guard let v = v, JS.truthy(v) else { return 0 }
        switch v {
        case .number(let n): return n
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces)) ?? .nan
        case .bool(let b): return b ? 1 : 0
        default: return .nan
        }
    }

    static func round2(_ n: Double) -> Double { JS.round(n * 100) / 100 }

    // MARK: repeticiones

    /// `Number(x)` de JS (NaN si no se puede).
    static func jsNumber(_ v: JSONValue) -> Double {
        switch v {
        case .number(let n): return n
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? 0 : (Double(t) ?? .nan)
        case .bool(let b): return b ? 1 : 0
        case .null: return 0
        default: return .nan
        }
    }

    static func isQ(_ r: JSONValue) -> Bool { if case .string(let s) = r { return s.hasPrefix("q") } else { return false } }

    /// Los dos días de una quincena "q10,25" (con los mismos límites que la web).
    static func qDays(_ r: String) -> (Int, Int) {
        func clamp(_ n: Double) -> Int {
            let x = JS.round(n)
            let v = (x.isNaN || x == 0) ? 1 : x
            return Int(min(31, max(1, v)))
        }
        var a = 15.0, b = 30.0
        if r.hasPrefix("q") {
            let rest = r.dropFirst()
            let parts = rest.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty,
               parts[0].allSatisfy({ $0.isASCII && $0.isNumber }), parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
               let x = Double(parts[0]), let y = Double(parts[1]) { a = x; b = y }
        }
        let p = clamp(a), q = clamp(b)
        return p <= q ? (p, q) : (q, p)
    }

    static func qMake(_ a: JSONValue?, _ b: JSONValue?) -> String {
        func s(_ v: JSONValue?) -> String { v.map { JS.string($0) } ?? "undefined" }
        let x = qDays("q" + s(a) + "," + s(b))
        return "q\(x.0),\(x.1)"
    }

    static func qNext(_ d: LocalDate, _ r: String, inclusive: Bool = false) -> LocalDate {
        let dd = qDays(r)
        let y = d.year, m = d.month0
        let last = LocalDate.daysInMonth(year: y, month0: m)
        for x0 in [dd.0, dd.1] {
            let x = min(x0, last)
            if inclusive ? x >= d.day : x > d.day { return LocalDate(year: y, month0: m, day: x) }
        }
        let l2 = LocalDate.daysInMonth(year: y, month0: m + 1)
        return LocalDate(year: y, month0: m + 1, day: min(dd.0, l2))
    }

    static func nextRep(_ d: LocalDate, _ rep: JSONValue) -> LocalDate {
        if isQ(rep), case .string(let s) = rep { return qNext(d, s) }
        if case .string("m") = rep {
            let m = d.month0 + 1
            let last = LocalDate.daysInMonth(year: d.year, month0: m)
            return LocalDate(year: d.year, month0: m, day: min(d.day, last))
        }
        let n = jsNumber(rep)
        let step = (n.isFinite && n != 0 && abs(n) < 1e7) ? Int(n.rounded(.towardZero)) : 7   // Number(rep) || 7
        return d.adding(days: step)
    }

    // MARK: trabajos simulados

    static let jobMult: [String: Double] = ["w": 1, "b": 2, "q": 52.0 / 24.0, "m": 52.0 / 12.0]

    static func jobRep(_ freq: String, _ j: JSONValue) -> JSONValue {
        switch freq {
        case "w": return .number(7)
        case "b": return .number(14)
        case "q": return .string(qMake(j["q1"], j["q2"]))
        default: return .string("m")
        }
    }

    static func jobNet(_ j: JSONValue) -> Double {
        let freq = str(j["freq"])
        let rate = num(j["rate"])
        if str(j["mode"]) == "s" {
            let f: Double = freq == "m" ? 1 : ((freq == "b" || freq == "q") ? 0.5 : 12.0 / 52.0)
            return round2(rate * f)
        }
        let mult = jobMult[freq] ?? 1
        return round2(rate * num(j["hours"]) * (1 - num(j["tax"]) / 100) * mult)
    }

    // MARK: eventos futuros

    func payOf(_ e: JSONValue) -> JSONValue? {
        guard JS.truthy(e["card"]), let id = e["card"] else { return nil }
        return list("cards").first(where: { $0["id"] == id })
    }

    /// Todos los movimientos esperados del próximo año (suscripciones, pagos de tarjeta, ingresos y gastos previstos, simulaciones).
    public func genEvents(noSim: Bool = false, skip: String? = nil, keepSkipped: Bool = false) -> [EngineEvent] {
        let end = today.adding(days: 371)
        var ev: [EngineEvent] = []

        func monthly(_ day: Int, _ fn: (LocalDate) -> Void) {
            for k in 0...13 {
                let base = LocalDate(year: today.year, month0: today.month0 + k, day: 1)
                let last = LocalDate.daysInMonth(year: base.year, month0: base.month0)
                let d = LocalDate(year: base.year, month0: base.month0, day: min(day, last))
                if d > today && d <= end { fn(d) }
            }
        }
        func dayOr1(_ v: JSONValue?) -> Int { let n = Engine.int(v); return n == 0 ? 1 : n }
        let pcur = primaryCurrency

        for (ri, r) in list("recurring").enumerated() {
            let amount = Engine.num(r["amount"])
            monthly(dayOr1(r["day"])) { d in
                ev.append(EngineEvent(date: d, name: Engine.str(r["name"]), amt: amount, type: "rec", key: "rec:\(ri):" + d.iso, cur: pcur, a0: amount))
            }
        }
        for s in list("subs") {
            let cur = Engine.str(s["cur"]), amount = Engine.num(s["amount"])
            monthly(dayOr1(s["day"])) { d in
                ev.append(EngineEvent(date: d, name: Engine.str(s["name"]), amt: -usd(amount, cur), type: "sub", key: "sub:" + Engine.idStr(s["id"]) + ":" + d.iso,
                                      form: "sub", srcId: Engine.idStr(s["id"]), cur: cur, a0: -amount))
            }
        }
        for c in list("cards") where Engine.num(c["payment"]) > 0 {
            let cur = Engine.str(c["cur"]), pay = Engine.num(c["payment"])
            monthly(dayOr1(c["due_day"])) { d in
                ev.append(EngineEvent(date: d, name: "Pago " + Engine.str(c["name"]), amt: -usd(pay, cur), type: "card", key: "card:" + Engine.idStr(c["id"]) + ":" + d.iso,
                                      form: "debt", srcId: Engine.idStr(c["id"]), cur: cur, a0: -pay))
            }
        }

        let groups: [(String, Double, String, String)] = [("expected_income", 1, "in", "income"), ("expected_expense", -1, "exp", "expense")]
        for g in groups {
            for e in list(g.0) {
                let cur = accCur(e["acc"])
                let amt = g.1 * usd(Engine.num(e["amount"]), cur)
                let form = payOf(e) != nil ? "cardpay" : g.3
                func make(_ d: LocalDate) -> EngineEvent {
                    EngineEvent(date: d, name: Engine.str(e["name"]), amt: amt, type: g.2, key: g.2 + ":" + Engine.idStr(e["id"]) + ":" + d.iso,
                                form: form, srcId: Engine.idStr(e["id"]), cur: cur, a0: g.1 * Engine.num(e["amount"]))
                }
                guard let first = LocalDate(iso: Engine.str(e["date"])) else { continue }
                var d = first
                var n = 0
                if d <= today {
                    ev.append(EngineEvent(date: today.adding(days: 1), name: Engine.str(e["name"]), amt: amt, type: g.2, pending: true, orig: Engine.str(e["date"])))
                } else if d <= end {
                    ev.append(make(d))
                }
                if JS.truthy(e["repeat"]), let rep = e["repeat"] {
                    let until = Engine.str(e["until"])
                    d = Engine.nextRep(d, rep)
                    while d <= today {
                        if n >= 400 { break }
                        n += 1
                        d = Engine.nextRep(d, rep)
                    }
                    n = 0
                    while d <= end {
                        if n >= 400 { break }
                        n += 1
                        if !until.isEmpty && d.iso > until { break }
                        ev.append(make(d))
                        d = Engine.nextRep(d, rep)
                    }
                }
            }
        }

        if !noSim {
            for j in list("jobs") where JS.truthy(j["sim"]) {
                let cur = accCur(j["acc"]), net = Engine.jobNet(j)
                let rep = Engine.jobRep(Engine.str(j["freq"]), j)
                let until = Engine.str(j["until"])
                guard var d = LocalDate(iso: Engine.str(j["start"])) else { continue }
                var n = 0
                while d <= today {
                    if n >= 400 { break }
                    n += 1
                    d = Engine.nextRep(d, rep)
                }
                n = 0
                while d <= end {
                    if n >= 400 { break }
                    n += 1
                    if !until.isEmpty && d.iso > until { break }
                    ev.append(EngineEvent(date: d, name: Engine.str(j["name"]) + " (simulado)", amt: usd(net, cur), type: "sim",
                                          key: "sim:job" + Engine.idStr(j["id"]) + ":" + d.iso, form: "job", srcId: Engine.idStr(j["id"])))
                    d = Engine.nextRep(d, rep)
                }
            }
            for p in list("planned") {
                if p["on"] == JSONValue.bool(false) { continue }
                if let skip = skip, p["id"] == JSONValue.string(skip) { continue }
                guard let d = LocalDate(iso: Engine.str(p["date"])) else { continue }
                if d > today && d <= end {
                    ev.append(EngineEvent(date: d, name: Engine.str(p["name"]), amt: Engine.num(p["amount"]), type: "sim", key: "sim:" + Engine.idStr(p["id"]),
                                          form: "sim", srcId: Engine.idStr(p["id"])))
                }
            }
        }

        let ovr = data["ovr"]?.objectValue ?? [:]
        var res: [EngineEvent] = []
        for var e in ev {
            if let key = e.key, e.type != "sim", let x = ovr[key], JS.truthy(x) {
                if JS.truthy(x["skip"]) {
                    if !keepSkipped { continue }
                    e.skipped = true
                } else {
                    if let a = x["amt"], !a.isNull { e.amt = (e.a0 < 0 ? -1 : 1) * usd(Engine.num(a), e.cur ?? "") }
                    if JS.truthy(x["date"]), let nd = LocalDate(iso: Engine.str(x["date"])) { e.date = nd }
                }
                e.edited = true
            }
            res.append(e)
        }
        return Engine.stableSort(res) { (a: EngineEvent, b: EngineEvent) -> Int in a.date.days - b.date.days }
    }

    // MARK: proyección

    var weeklyVariable: Double { variable ? Engine.num(settings["variable_weekly"]) : 0 }

    public static func dayLabel(_ d: LocalDate) -> String { weekdays[d.weekday] + " " + String(d.day) + " " + months[d.month0] }

    public func projection() -> ProjectionResult {
        let c = calc()
        let V = weeklyVariable
        let events = genEvents()
        var series: [SeriesPoint] = []
        for i in 0...Engine.weeks {
            let end = today.adding(days: 7 * i)
            var s = 0.0
            for e in events where e.date <= end { s += e.amt }
            series.append(SeriesPoint(date: end, v: c.balance + s - V * Double(i)))
        }
        var cum = 0.0
        var timeline: [TimelineEntry] = []
        for e in genEvents(keepSkipped: true).prefix(8) {
            if !e.skipped { cum += e.amt }
            let days = Double(e.date.days - today.days)
            timeline.append(TimelineEntry(name: e.name, date: Engine.dayLabel(e.date), amt: e.amt, type: e.type, key: e.key, edited: e.edited, skipped: e.skipped,
                                          after: c.balance + cum - (V * days) / 7))
        }
        var minV = series[0].v
        for p in series where p.v < minV { minV = p.v }
        let red = series.firstIndex(where: { $0.v < 0 })
        return ProjectionResult(V: V, series: series, timeline: timeline, minV: minV, firstRed: red)
    }

    /// Saldo proyectado día a día durante un año.
    public func dailySeries(noSim: Bool = false, skip: String? = nil, keepSkipped: Bool = false) -> [SeriesPoint] {
        let c = calc()
        let V = weeklyVariable
        let ev = genEvents(noSim: noSim, skip: skip, keepSkipped: keepSkipped)
        var out: [SeriesPoint] = []
        var k = 0
        var cum = 0.0
        for i in 0...(Engine.weeks * 7) {
            let d = today.adding(days: i)
            while k < ev.count && ev[k].date <= d { cum += ev[k].amt; k += 1 }
            out.append(SeriesPoint(date: d, v: c.balance + cum - (V * Double(i)) / 7))
        }
        return out
    }

    /// Impacto de un gasto simulado entre su fecha y otra (por defecto, el siguiente ingreso).
    public func simImpact(_ p: JSONValue) -> SimImpact? {
        let id = Engine.idStr(p["id"])
        let ser = dailySeries(), base = dailySeries(skip: id)
        let pdate = Engine.str(p["date"]), puntil = Engine.str(p["until"])
        var end = (!puntil.isEmpty && puntil > pdate) ? puntil : ""
        if end.isEmpty {
            if let nx = genEvents().first(where: { $0.type == "in" && $0.date.iso > pdate }) {
                end = nx.date.iso
            } else if let pdd = LocalDate(iso: pdate) {
                end = pdd.adding(days: 14).iso
            }
        }
        func window(_ a: [SeriesPoint]) -> [SeriesPoint] { a.filter { $0.date.iso >= pdate && $0.date.iso <= end } }
        let w1 = window(ser), w0 = window(base)
        if w1.isEmpty { return nil }
        func lowest(_ w: [SeriesPoint]) -> SeriesPoint {
            var m = w[0]
            for x in w where x.v < m.v { m = x }
            return m
        }
        let a = lowest(w1), b = w0.isEmpty ? a : lowest(w0)
        let cushion = Engine.num(settings["cushion"])
        return SimImpact(start: pdate, end: end, withMin: a.v, withDate: a.date, withoutMin: b.v, status: a.v < 0 ? "red" : (a.v < cushion ? "amber" : "ok"))
    }

    // MARK: pendientes

    /// Ingresos, gastos y pagos de deuda cuya fecha ya llegó y falta confirmar.
    public func pendingItems() -> [PendingItem] {
        let t = today.iso
        func due(_ e: JSONValue) -> Bool {
            let date = Engine.str(e["date"])
            if date > t { return false }
            let sn = Engine.str(e["snooze"])
            return !(!sn.isEmpty && sn > t)
        }
        var items: [PendingItem] = []
        for e in list("expected_income") where due(e) { items.append(PendingItem(kind: "in", id: Engine.idStr(e["id"]), date: Engine.str(e["date"]))) }
        for e in list("expected_expense") where due(e) { items.append(PendingItem(kind: "out", id: Engine.idStr(e["id"]), date: Engine.str(e["date"]))) }
        for c in list("cards") {
            guard let auto = c["auto"], JS.truthy(auto) else { continue }
            if !(Engine.num(c["balance"]) > 0.005) { continue }          // deuda pagada: el pago esperado se apaga solo
            if !(Engine.num(c["due_day"]) > 0) { continue }
            let next = Engine.str(auto["next"])
            if next.isEmpty || next > t { continue }
            let sn = Engine.str(auto["snooze"])
            if !sn.isEmpty && sn > t { continue }
            items.append(PendingItem(kind: "pay", id: Engine.idStr(c["id"]), date: next))
        }
        return Engine.stableSort(items) { (a: PendingItem, b: PendingItem) -> Int in a.date < b.date ? -1 : (a.date > b.date ? 1 : 0) }
    }

    /// Un ingreso o gasto editado en Proyección (`ovr`) también cambia lo que se ve en Resumen.
    func effItem(_ kind: String, _ e: JSONValue) -> JSONValue {
        let ovr = data["ovr"]?.objectValue ?? [:]
        guard let x = ovr[kind + ":" + Engine.idStr(e["id"]) + ":" + Engine.str(e["date"])], JS.truthy(x), !JS.truthy(x["skip"]) else { return e }
        var r = e
        if let a = x["amt"], !a.isNull { r["amount"] = a }
        if JS.truthy(x["date"]), let d = x["date"] { r["date"] = d }
        return r
    }

    public func nextIncome() -> IncomeItem? {
        let items = list("expected_income").map { effItem("in", $0) }
        let sorted = Engine.stableSort(items) { (a: JSONValue, b: JSONValue) -> Int in
            let da = Engine.str(a["date"]), db = Engine.str(b["date"])
            return da < db ? -1 : (da > db ? 1 : 0)
        }
        guard let e = sorted.first else { return nil }
        return IncomeItem(id: Engine.idStr(e["id"]), date: Engine.str(e["date"]), amount: Engine.num(e["amount"]))
    }

    // MARK: simulador de deudas

    /// Se paga el mínimo en todas las deudas y lo extra va a la de mayor interés. `kind`: nil/"all", "card" o "loan".
    public func payoff(extra: Double, kind: String? = nil) -> PayoffResult {
        struct D { var b: Double; var r: Double; var apr: Double; var p: Double }
        var ds: [D] = []
        for k in list("cards") {
            if let kind = kind, kind != "all", Engine.str(k["kind"]) != kind { continue }
            let cur = Engine.str(k["cur"])
            let bal = usd(Engine.num(k["balance"]), cur)
            let apr = Engine.num(k["apr"])
            let pay = Engine.num(k["payment"])
            let p = pay > 0 ? usd(pay, cur) : max(15, bal * 0.02)
            if bal > 0 { ds.append(D(b: bal, r: apr / 1200, apr: apr, p: p)) }
        }
        if ds.isEmpty { return PayoffResult(months: 0, interest: 0, ok: true) }
        var pool = 0.0
        for d in ds { pool += d.p }
        pool += extra
        let order = Engine.stableSort(Array(ds.indices)) { (i: Int, j: Int) -> Int in
            let x = ds[j].apr - ds[i].apr
            return x > 0 ? 1 : (x < 0 ? -1 : 0)
        }
        var interest = 0.0
        var m = 0
        while m < 600 && ds.contains(where: { $0.b > 0.005 }) {
            m += 1
            for i in ds.indices where ds[i].b > 0 {
                let int = ds[i].b * ds[i].r
                ds[i].b += int
                interest += int
            }
            var rest = pool
            for i in ds.indices {
                let x = min(ds[i].p, ds[i].b)
                ds[i].b -= x
                rest -= x
            }
            for i in order where rest > 0 && ds[i].b > 0 {
                let x = min(rest, ds[i].b)
                ds[i].b -= x
                rest -= x
            }
        }
        return PayoffResult(months: m, interest: interest, ok: !ds.contains(where: { $0.b > 0.005 }))
    }
}
