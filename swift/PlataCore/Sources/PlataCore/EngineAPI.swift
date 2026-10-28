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
