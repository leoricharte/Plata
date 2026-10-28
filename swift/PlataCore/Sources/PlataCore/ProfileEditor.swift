import Foundation

/// Cambios al perfil con las mismas reglas que la web: un movimiento suma o resta al saldo de su cuenta; en una tarjeta, un gasto
/// sube la deuda y un pago la baja. Siempre sobre el perfil ya migrado. Quien llama sella (`SyncStamper`) y guarda después.
public enum ProfileEditor {
    public enum EditError: Error, Equatable { case notFound, incomeOnCard, invalidAmount }

    // MARK: cuentas

    /// Dónde está una cuenta o tarjeta (`accOf` de la web: cuentas, luego tarjetas, y si no existe, la primera cuenta).
    static func locate(_ p: JSONValue, _ id: JSONValue?) -> (col: String, index: Int)? {
        if let id = id, !id.isNull {
            if let i = (p["accounts"]?.arrayValue ?? []).firstIndex(where: { $0["id"] == id }) { return ("accounts", i) }
            if let i = (p["cards"]?.arrayValue ?? []).firstIndex(where: { $0["id"] == id }) { return ("cards", i) }
        }
        return (p["accounts"]?.arrayValue ?? []).isEmpty ? nil : ("accounts", 0)
    }

    public static func isCredit(_ p: JSONValue, accountId: JSONValue?) -> Bool { locate(p, accountId)?.col == "cards" }

    /// `applyTo` de la web: en débito suma; en crédito, un gasto (negativo) sube la deuda.
    static func applyTo(_ p: inout JSONValue, _ id: JSONValue?, _ signed: Double) {
        guard let loc = locate(p, id), case .array(var list)? = p[loc.col] else { return }
        var item = list[loc.index]
        let bal = Engine.num(item["balance"])
        item["balance"] = .number(Engine.round2(loc.col == "cards" ? bal - signed : bal + signed))
        list[loc.index] = item
        p[loc.col] = .array(list)
    }

    // MARK: movimientos

    /// Id nuevo: la hora en microsegundos con un poco de azar, o 1 más que el mayor existente (`nextTxId`).
    public static func nextTxId(_ p: JSONValue, now: Double, jitter: Int = Int.random(in: 0..<1000)) -> Double {
        var maxId = 0.0
        for t in p["transactions"]?.arrayValue ?? [] { let n = Engine.num(t["id"]); if n > maxId { maxId = n } }
        return max(now * 1000 + Double(jitter), 1 + maxId)
    }

    @discardableResult
    public static func addTransaction(_ p: inout JSONValue, date: String, amount: Double, category: String, note: String, account: String,
                                      now: Double, jitter: Int = Int.random(in: 0..<1000)) throws -> Double {
        guard amount != 0, amount.isFinite else { throw EditError.invalidAmount }
        if amount > 0 && category == "Ingreso" && isCredit(p, accountId: .string(account)) { throw EditError.incomeOnCard }
        let id = nextTxId(p, now: now, jitter: jitter)
        let accId = locate(p, .string(account)).flatMap { loc in p[loc.col]?.arrayValue?[loc.index]["id"] } ?? .string(account)
        let tx: JSONValue = .object(["id": .number(id), "date": .string(date), "amount": .number(amount), "category": .string(category),
                                     "note": .string(note), "acc": accId])
        var list = p["transactions"]?.arrayValue ?? []
        list.append(tx)
        p["transactions"] = .array(list)
        applyTo(&p, accId, amount)
        return id
    }

    static func txIndex(_ p: JSONValue, _ id: JSONValue) -> Int? { (p["transactions"]?.arrayValue ?? []).firstIndex(where: { $0["id"] == id }) }

    /// Borra un movimiento (y su pareja, si es una transferencia o un pago entre cuentas) y devuelve los saldos.
    public static func deleteTransaction(_ p: inout JSONValue, id: JSONValue) throws {
        guard let i = txIndex(p, id), var list = p["transactions"]?.arrayValue else { throw EditError.notFound }
        let t = list[i]
        var drop: [Int] = [i]
        if JS.truthy(t["pair"]), let j = list.indices.first(where: { $0 != i && list[$0]["pair"] == t["pair"] }) { drop.append(j) }
        for k in drop { applyTo(&p, list[k]["acc"], -Engine.num(list[k]["amount"])) }
        for k in drop.sorted(by: >) { list.remove(at: k) }
        p["transactions"] = .array(list)
    }

    /// Edita un movimiento: se devuelve el efecto anterior al saldo y se aplica el nuevo (`txSave` de la web).
    /// `amount` es positivo; `isOut` decide el signo salvo en pagos y transferencias, que conservan el suyo.
    public static func updateTransaction(_ p: inout JSONValue, id: JSONValue, amount: Double, isOut: Bool, category: String, account: String, date: String, note: String) throws {
        guard let i = txIndex(p, id), var list = p["transactions"]?.arrayValue else { throw EditError.notFound }
        guard amount > 0, amount.isFinite else { throw EditError.invalidAmount }
        var t = list[i]
        let cat = Engine.str(t["category"])
        let pay = cat == Engine.payCategory || cat == Engine.xferCategory
        let oldAmount = Engine.num(t["amount"]), oldAcc = t["acc"]
        let newAcc: JSONValue = .string(account)
        if !pay && !isOut && newAcc != oldAcc && isCredit(p, accountId: newAcc) { throw EditError.incomeOnCard }
        applyTo(&p, oldAcc, -oldAmount)
        let out = pay ? oldAmount < 0 : isOut
        let signed = pay ? (oldAmount < 0 ? -amount : amount) : (out ? -amount : amount)
        t["amount"] = .number(signed)
        t["acc"] = .string(account)
        t["date"] = .string(date)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { t["note"] = .string(trimmed) }
        if !pay {
            t["category"] = .string(out ? category : "Ingreso")
            if out, case .object(var o) = t { o["est"] = nil; t = .object(o) }
        }
        list[i] = t
        p["transactions"] = .array(list)
        applyTo(&p, t["acc"], signed)
        // pareja: transferencia o pago entre cuentas, con la conversión de moneda
        if JS.truthy(t["pair"]), let j = list.indices.first(where: { $0 != i && list[$0]["pair"] == t["pair"] }) {
            var pr = list[j]
            applyTo(&p, pr["acc"], -Engine.num(pr["amount"]))
            let c1 = currency(p, t["acc"]), c2 = currency(p, pr["acc"])
            let eng = Engine(profile: Profile(raw: p), today: LocalDate(days: 0))
            let conv = Engine.round2(eng.fromUSD(eng.usd(amount, c1), c2))
            let sign: Double = Engine.num(pr["amount"]) < 0 ? -1 : 1
            pr["amount"] = .number(sign * conv)
            pr["date"] = .string(date)
            list[j] = pr
            p["transactions"] = .array(list)
            applyTo(&p, pr["acc"], sign * conv)
        }
    }

    static func currency(_ p: JSONValue, _ id: JSONValue?) -> String {
        guard let loc = locate(p, id) else { return "" }
        return Engine.str(p[loc.col]?.arrayValue?[loc.index]["cur"])
    }
}
