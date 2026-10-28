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
