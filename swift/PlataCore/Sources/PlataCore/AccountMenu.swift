import Foundation

// Cuentas y tarjetas en los menús donde se elige una: las que más usas primero y, junto al nombre,
// cuánto dinero tienen (o cuánto te queda disponible, si son de crédito).

public extension Engine {
    /// Cuántos días hacia atrás cuentan como «uso reciente» para ordenar los menús de cuentas.
    static let recentUseDays = 90

    /// Cuántos movimientos tuvo cada cuenta o tarjeta en los últimos `days` días (id → cantidad).
    /// Un movimiento sin cuenta cuenta para la primera, igual que en el resto del motor. Los futuros no cuentan.
    func recentUse(days: Int = Engine.recentUseDays) -> [String: Int] {
        let from = today.adding(days: -days).iso
        let to = today.iso
        let firstId = Engine.str(allAccounts.first?["id"])
        var out: [String: Int] = [:]
        for tx in allTransactions {
            let d = Engine.str(tx["date"])
            guard d >= from && d <= to else { continue }
            let acc = Engine.str(tx["acc"])
            out[acc.isEmpty ? firstId : acc, default: 0] += 1
        }
        return out
    }

    /// Las cuentas (o tarjetas) con más movimientos recientes primero. Si empatan, queda el orden que ya tenían.
    func orderedByUse(_ items: [JSONValue]) -> [JSONValue] {
        let use = recentUse()
        return items.enumerated().sorted { a, b in
            let ua = use[Engine.str(a.element["id"])] ?? 0
            let ub = use[Engine.str(b.element["id"])] ?? 0
            return ua != ub ? ua > ub : a.offset < b.offset
        }.map { $0.element }
    }

    var accountsByUse: [JSONValue] { orderedByUse(allAccounts) }
    var cardsByUse: [JSONValue] { orderedByUse(allCards) }
    /// Cuentas y tarjetas juntas, para los menús que las mezclan en una sola lista.
    var accountsAndCardsByUse: [JSONValue] { orderedByUse(allAccounts + allCards) }

    /// Lo que se muestra de una cuenta o tarjeta en un menú:
    /// - débito: `Nombre · ● 1234 · S/ 1,240` (el saldo, en la moneda de la cuenta; negativo si está en rojo);
    /// - tarjeta con límite: `Nombre · ● 1234 · S/ 860 disponible`;
    /// - préstamo, o tarjeta sin límite: `Nombre · ● 1234 · S/ 500 pendiente` (lo que todavía se debe).
    /// `available` y `owed` son esas palabras ya traducidas.
    func menuLabel(_ a: JSONValue, available: String, owed: String) -> String {
        var s = Engine.str(a["name"])
        let l4 = Engine.str(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        let cur = Engine.str(a["cur"])
        let custom = customCurrency
        let balance = Engine.num(a["balance"])
        let kind = Engine.str(a["kind"])
        if kind == "loan" {
            return s + " · " + Money.whole(balance, cur, custom: custom) + " " + owed
        }
        if kind == "card" || a["limit"] != nil {
            let limit = Engine.num(a["limit"])
            if limit > 0 { return s + " · " + Money.whole(max(0, limit - balance), cur, custom: custom) + " " + available }
            return s + " · " + Money.whole(balance, cur, custom: custom) + " " + owed
        }
        return s + " · " + Money.whole(balance, cur, custom: custom)
    }
}
