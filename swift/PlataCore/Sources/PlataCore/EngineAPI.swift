import Foundation

// Lectura cómoda del perfil para las pantallas (sin que cada una tenga que conocer el JSON).

public extension LocalDate {
    /// Hoy en el calendario local (equivale a `getToday()` de la web).
    static func today(calendar: Calendar = .current, now: Date = Date()) -> LocalDate {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return LocalDate(year: c.year ?? 1970, month0: (c.month ?? 1) - 1, day: c.day ?? 1)
    }

    /// Mediodía de ese día en el calendario dado (para mostrarlo con `DateFormatter` / `Text(date, style:)`).
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date(timeIntervalSince1970: Double(days) * 86400)
    }
}

public extension Engine {
    static func number(_ v: JSONValue?) -> Double { num(v) }
    static func text(_ v: JSONValue?) -> String { str(v) }
    /// Identificador como texto (los de movimientos son números; los de cuentas, texto).
    static func identifier(_ v: JSONValue?) -> String { idStr(v) }
    /// ¿Es verdadero en JavaScript? (para banderas como `hid`)
    static func flag(_ v: JSONValue?) -> Bool { JS.truthy(v) }

    var insightsEnabled: Bool { insightsOn }
    var scoreEnabled: Bool { scoreOn }
    var customCurrency: String { settings["customCur"]?.stringValue ?? "" }

    /// Nombres de las categorías, en el orden de la persona.
    var categoryNames: [String] { catOrder }
    func categoryColor(_ name: String) -> String { catColor[name] ?? "#C9CBD1" }

    func accountCurrency(_ id: JSONValue?) -> String { accCur(id) }
    func accountName(_ id: JSONValue?) -> String { Engine.str(accOf(id)?["name"]) }

    /// Cuentas de débito visibles y tarjetas/préstamos visibles (`hid` las oculta en el resumen).
    var visibleAccounts: [JSONValue] { list("accounts").filter { !JS.truthy($0["hid"]) } }
    var visibleCards: [JSONValue] { list("cards").filter { !JS.truthy($0["hid"]) } }
    var allAccounts: [JSONValue] { list("accounts") }
    var allCards: [JSONValue] { list("cards") }
    var allTransactions: [JSONValue] { list("transactions") }
    var allIncomeItems: [JSONValue] { list("expected_income") }
    var allExpenseItems: [JSONValue] { list("expected_expense") }

    /// Suma de montos de una lista en moneda principal.
    func totalUSD(_ items: [JSONValue], amount: String = "balance") -> Double {
        var s = 0.0
        for i in items { s += usd(Engine.num(i[amount]), Engine.str(i["cur"])) }
        return s
    }
}

// Lo que muestra el Resumen además de lo que ya calcula `calc()`.
public extension Engine {
    /// El próximo gasto previsto (con las ediciones de Proyección aplicadas), el más cercano primero.
    func nextExpense() -> JSONValue? {
        let items = list("expected_expense").map { effItem("exp", $0) }
        let sorted = Engine.stableSort(items) { (a: JSONValue, b: JSONValue) -> Int in
            let da = Engine.str(a["date"]), db = Engine.str(b["date"])
            return da < db ? -1 : (da > db ? 1 : 0)
        }
        return sorted.first
    }

    /// Los próximos cobros de suscripciones (hasta `limit`, dentro de `days` días), del más cercano al más lejano.
    func upcomingSubscriptions(days: Int = 35, limit: Int = 3) -> [EngineEvent] {
        let horizon = today.adding(days: days)
        let subs = genEvents().filter { $0.type == "sub" && $0.date <= horizon }
        let sorted = Engine.stableSort(subs) { (a: EngineEvent, b: EngineEvent) -> Int in
            a.date < b.date ? -1 : (a.date > b.date ? 1 : 0)
        }
        return Array(sorted.prefix(limit))
    }

    /// Días desde el último movimiento registrado (hasta hoy); nil si no hay ninguno.
    func daysSinceLastTransaction() -> Int? {
        let t = today.iso
        var last = ""
        for tx in list("transactions") {
            let d = Engine.str(tx["date"])
            if d <= t && d > last { last = d }
        }
        guard !last.isEmpty, let day = LocalDate(iso: last) else { return nil }
        return today.days - day.days
    }
}

public extension Engine {
    /// Límites por categoría de un set de presupuesto (nil = presupuesto base).
    func budgetLimits(_ set: JSONValue?) -> [String: Double] {
        budOf(set).mapValues { Engine.num($0) }
    }
    var budgetSetList: [JSONValue] { list("budgetSets") }
    var subscriptionList: [JSONValue] { list("subs") }
}

public extension Engine {
    /// Monto de un movimiento en dólares (la moneda interna del motor).
    func transactionUSD(_ t: JSONValue) -> Double { txUSD(t) }
    static func jobNetPay(_ j: JSONValue) -> Double { jobNet(j) }
    var jobList: [JSONValue] { list("jobs") }
    var plannedList: [JSONValue] { list("planned") }
    var expectedExpenseList: [JSONValue] { list("expected_expense") }

    /// «cada mes», «cada semana»… (como `repLabel` de la web).
    static func repeatLabel(_ r: JSONValue?) -> String {
        guard let r else { return "una vez" }
        if isQ(r) { let d = qDays(r.stringValue ?? ""); return "los días \(d.0) y \(d.1) de cada mes" }
        if r == .string("m") { return "cada mes" }
        let n = num(r)
        return n == 7 ? "cada semana" : (n == 14 ? "cada 2 semanas" : "una vez")
    }
    static func jobRepeatLabel(_ j: JSONValue) -> String { repeatLabel(jobRep(str(j["freq"]), j)) }

    /// ¿Es un pago de crédito previsto? (tiene `card`)
    func paymentCard(_ e: JSONValue) -> JSONValue? { payOf(e) }
}

public extension Engine {
    /// Convierte un monto entre dos monedas con el cambio de la app (redondeado a centavos).
    func convert(_ n: Double, from: String, to: String) -> Double { Engine.round2(fromUSD(usd(n, from), to)) }
}

public extension Engine {
    static func isRepeatQuincenal(_ r: JSONValue) -> Bool { isQ(r) }
    static func quincenalDays(_ r: JSONValue) -> (Int, Int) { qDays(r.stringValue ?? "") }
}

public extension Engine {
    static func roundCents(_ n: Double) -> Double { round2(n) }
}

public extension Engine {
    static var cardColorsForApp: [String] { cardColors }
}


public extension Engine {
    /// El set que se está viendo: «base» (nil), uno elegido por id, o el que rige hoy (`viewSet` de la web).
    func viewSet(_ selection: String?) -> JSONValue? {
        if selection == "base" { return nil }
        if let selection, let s = list("budgetSets").first(where: { Engine.str($0["id"]) == selection }) { return s }
        return activeSet()
    }
}


public extension Engine {
    /// Del día 15 en adelante (o con half‑time forzado) y con mes anterior: la nota preliminar (`isHalfTime`).
    func isHalfTime(_ m: InsightsModel) -> Bool {
        scoreOn && m.hasPrev && (m.day >= 15 || Engine.flag(settings["forceHalf"]))
    }

    /// Tu primer half‑time: aparece aunque aún no haya mes anterior (`firstHalfOn`, sin escribir nada: ver `claimFirstHalf`).
    func firstHalfOn(_ m: InsightsModel) -> Bool {
        if !insightsOn || !scoreOn || m.cur.n < 5 { return false }
        if !(m.day >= 15 || Engine.flag(settings["forceHalf"])) { return false }
        let f = Engine.str(data["firstHalf"])
        if !f.isEmpty && f != m.mk { return false }
        return f == m.mk || !m.hasPrev
    }

    /// Qué valor de `firstHalf` hay que guardar ahora (nil = nada).
    func firstHalfClaim(_ m: InsightsModel) -> String? {
        if !insightsOn || !scoreOn || m.cur.n < 5 { return nil }
        if !(m.day >= 15 || Engine.flag(settings["forceHalf"])) { return nil }
        if !Engine.str(data["firstHalf"]).isEmpty { return nil }
        return m.hasPrev ? "2000-01" : m.mk
    }

    /// La nota que quedó guardada al llegar al half‑time de ese mes.
    func halfSnap(_ mk: String) -> (letter: String, score: Int)? {
        guard let s = data["halfSnaps"]?[mk], !Engine.str(s["letter"]).isEmpty else { return nil }
        return (Engine.str(s["letter"]), Int(Engine.num(s["score"])))
    }

    static func previousMonthKey(_ mk: String) -> String { prevMonthKey(mk) }
}


public extension Engine {
    /// Pago de tarjeta o préstamo (no cuenta como gasto en Insights).
    func isCreditPayment(_ t: JSONValue) -> Bool { isPay(t) }
    /// Monto de un movimiento en dólares (negativo = gasto).
    func amountUSD(_ t: JSONValue) -> Double { txUSD(t) }
}

// Confirmar ingresos, gastos y pagos esperados (`doConfirm` / `doConfirmPay` de la web).
public extension Engine {
    /// La fecha siguiente de una serie (`nextRep`).
    static func nextOccurrence(_ iso: String, _ rep: JSONValue) -> String {
        guard let d = LocalDate(iso: iso) else { return iso }
        return nextRep(d, rep).iso
    }

    /// Ingreso o gasto con las ediciones de Proyección aplicadas. `kind`: "in" o "exp".
    func effectiveItem(_ kind: String, _ e: JSONValue) -> JSONValue { effItem(kind, e) }

    /// El primer día `day` del mes que cae después de `after` (`dueAfter`).
    static func dueAfter(day: Int, after iso: String) -> String {
        guard let a = LocalDate(iso: iso) else { return iso }
        for m in 0..<3 {
            let mm = a.month0 + m
            let y = a.year + mm / 12, m0 = mm % 12
            let d = LocalDate(year: y, month0: m0, day: min(day, LocalDate.daysInMonth(year: y, month0: m0)))
            if d.days > a.days { return d.iso }
        }
        return iso
    }

    /// El trabajo al que pertenece un ingreso esperado (`jobOf`).
    func jobOf(_ e: JSONValue) -> JSONValue? {
        guard JS.truthy(e["job"]), let id = e["job"] else { return nil }
        return list("jobs").first(where: { $0["id"] == id })
    }

    /// Horas por pago de un trabajo (`jobHrs`); 0 si es sueldo fijo.
    static func jobHours(_ j: JSONValue) -> Double {
        if str(j["mode"]) == "s" { return 0 }
        return round2(num(j["hours"]) * (jobMult[str(j["freq"])] ?? 1))
    }

    /// Porcentaje descontado entre lo bruto (tarifa × horas) y lo que llegó (`taxPct`).
    static func taxPercent(amount: Double, rate: Double, hours: Double) -> Double {
        let g = rate * hours
        return g > 0 ? max(0, min(100, ((1 - amount / g) * 1000).rounded() / 10)) : 0
    }
}

// El avatar del perfil: aro y insignia con la nota del mes pasado (`avatarInfo` / `gradeCounts` de la web).
public struct AvatarInfo: Equatable, Sendable {
    /// Lo que dice la insignia: «B», «A+», «D-» o «S*» (Diamante).
    public var label: String
    /// La letra de la nota (S…F) y el nivel de racha, para elegir colores.
    public var letter: String
    public var level: StreakLevel
}

public extension Engine {
    /// La nota del mes anterior, si hay datos y las notas están activas; si no, nil.
    func avatarInfo() -> AvatarInfo? {
        guard insightsOn, scoreOn else { return nil }
        let m = insightsModel(month: Engine.prevMonthKey(String(today.iso.prefix(7))))
        if insightsLocked(m) != nil { return nil }
        let l = m.letter
        switch m.plus {
        case .diamond: return AvatarInfo(label: "S*", letter: l, level: .diamond)
        case .plus: return AvatarInfo(label: l + ((l == "D" || l == "F") ? "-" : "+"), letter: l, level: .plus)
        case .none: return AvatarInfo(label: l, letter: l, level: .none)
        }
    }

    /// Cuántos meses cerrados hay con cada nota, de S a F (para «Mostrar puntuaciones»).
    func gradeCounts() -> [(letter: String, count: Int)] {
        guard scoreOn else { return [] }
        let cmk = String(today.iso.prefix(7))
        var months = Set<String>()
        for t in list("transactions") {
            let k = String(Engine.str(t["date"]).prefix(7))
            if k < cmk { months.insert(k) }
        }
        var cnt: [String: Int] = [:]
        for k in months { if let s = monthScore(k) { cnt[s.letter, default: 0] += 1 } }
        return ["S", "A", "B", "C", "D", "F"].compactMap { l in cnt[l].map { (letter: l, count: $0) } }
    }
}
