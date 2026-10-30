import Foundation

// Lo que el iPhone le manda al reloj (y lo que el reloj le devuelve). Se compila en las dos apps.
// El iPhone calcula todo con PlataCore; el reloj solo muestra, así no lleva el motor ni el cifrado de Plata Cloud.

struct WatchEvent: Codable, Hashable {
    var name: String
    var amt: Double
    var type: String        // in, exp, sub, card, rec
}

struct WatchDay: Codable, Hashable {
    var iso: String         // 2026-10-29
    var cash: Double        // saldo en caja al cierre del día
    var credit: Double      // crédito disponible ese día (límites menos deuda)
    var events: [WatchEvent]
}

struct WatchCat: Codable, Hashable {
    var name: String
    var spent: Double
    var limit: Double
    var color: String? = nil    // #RRGGBB de la categoría
}

struct WatchAccount: Codable, Hashable {
    var id: String
    var name: String
    var last4: String? = nil
    var credit: Bool? = nil
    var symbol: String? = nil           // SF Symbol si no hay logo
    var logo: Data? = nil               // solo el glifo del banco (PNG blanco, sin fondo), si existe
}

/// Una categoría tal como se ve en la cuadrícula del reloj.
struct WatchCategory: Codable, Hashable {
    var name: String                    // el nombre real (lo que se guarda)
    var label: String                   // traducido, para mostrar
    var symbol: String
    var color: String
}

struct WatchSnapshot: Codable {
    var stamp: Double                   // ms desde 1970
    var sym: String                     // símbolo de la moneda
    var dec: Int                        // decimales
    var spentToday: Double
    var allowance: Double               // lo que puedes gastar hoy según el presupuesto (0 = sin presupuesto)
    var daysLeft: Int
    var cats: [WatchCat]
    var days: [WatchDay]                // hoy + 27 días
    var accounts: [WatchAccount]
    var categories: [String]
    var catInfo: [WatchCategory]? = nil
    var letter: String                  // nota de Insights (S, A, B…)
    var adjective: String
    var tier: String? = nil             // racha de la nota: none / plus / diamond
    var nextName: String
    var nextAmt: Double
    var nextIn: Int                     // días hasta el próximo cobro o pago (-1 = no hay)
    var hasCredit: Bool                 // hay tarjetas con límite
    var lang: String? = nil             // idioma de la app (es / en) para textos del reloj
    var monthBudget: Double? = nil      // tope total del mes (suma de límites); nil/0 = sin presupuesto
    var monthLeft: Double? = nil        // tope − gastado del mes; negativo = te pasaste
}

/// Un movimiento anotado en el reloj, pendiente de guardarse en el iPhone.
struct WatchEntry: Codable, Hashable {
    var id: String
    var amount: Double                  // negativo = gasto
    var category: String
    var account: String
    var note: String
    var date: String                    // iso
}

enum WatchKey {
    static let snapshot = "snap"
    static let entry = "entry"
}

enum WatchFormat {
    static func money(_ n: Double, sym: String, dec: Int, signed: Bool = false) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = dec
        f.maximumFractionDigits = dec
        f.locale = Locale(identifier: "en_US")
        let s = f.string(from: NSNumber(value: abs(n))) ?? String(Int(abs(n)))
        let sign = n < 0 ? "-" : (signed && n > 0 ? "+" : "")
        return sign + sym + s
    }
}

/// El reloj y sus widgets comparten el último resumen por un App Group.
enum WatchShare {
    static let group = "group.net.plataapp.plata"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    static func save(_ data: Data) { defaults.set(data, forKey: WatchKey.snapshot) }
    static func load() -> WatchSnapshot? {
        guard let d = defaults.data(forKey: WatchKey.snapshot) else { return nil }
        guard let s = try? JSONDecoder().decode(WatchSnapshot.self, from: d) else { return nil }
        Tr.forced = s.lang
        return s
    }
}
