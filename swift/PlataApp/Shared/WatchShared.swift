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
    var debt: Double        // deuda de tarjetas ese día
    var events: [WatchEvent]
}

struct WatchCat: Codable, Hashable {
    var name: String
    var spent: Double
    var limit: Double
}

struct WatchAccount: Codable, Hashable {
    var id: String
    var name: String
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
    var letter: String                  // nota de Insights (S, A, B…)
    var adjective: String
    var nextName: String
    var nextAmt: Double
    var nextIn: Int                     // días hasta el próximo cobro o pago (-1 = no hay)
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
