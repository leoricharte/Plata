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

// MARK: - Transferencias e ingresos / gastos previstos

public extension ProfileEditor {
    enum FormError: Error, Equatable { case missingName, invalidAmount, invalidDays, endBeforeStart, sameAccount, invalidHours, missingStart, missingCard }

    /// Transferencia entre cuentas (`xferSubmit` de la web): dos movimientos con el mismo `pair`, y una comisión opcional.
    static func addTransfer(_ p: inout JSONValue, from: String, to: String, amount: Double, received: Double, commission: Double,
                            note: String, date: String, now: Double, pair: String) throws {
        guard amount > 0, amount.isFinite else { throw FormError.invalidAmount }
        guard from != to else { throw FormError.sameAccount }
        guard let a = locate(p, .string(from)), let b = locate(p, .string(to)) else { throw EditError.notFound }
        let fromId = p[a.col]?.arrayValue?[a.index]["id"] ?? .string(from)
        let toId = p[b.col]?.arrayValue?[b.index]["id"] ?? .string(to)
        let recv = Engine.round2(received > 0 ? received : amount)
        let comm = Engine.round2(commission)
        func push(_ amt: Double, _ cat: String, _ note: String, _ acc: JSONValue, pair: String?) {
            let id = nextTxId(p, now: now)
            var tx: [String: JSONValue] = ["id": .number(id), "date": .string(date), "amount": .number(amt), "category": .string(cat), "note": .string(note), "acc": acc]
            if let pair { tx["pair"] = .string(pair) }
            var list = p["transactions"]?.arrayValue ?? []
            list.append(.object(tx))
            p["transactions"] = .array(list)
            applyTo(&p, acc, amt)
        }
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        push(-amount, "Transferencia", n, fromId, pair: pair)
        push(recv, "Transferencia", n, toId, pair: pair)
        if comm > 0 { push(-comm, "Otros", "Comisión de transferencia", fromId, pair: nil) }
    }

    /// Guarda (crea o reemplaza por id) un ingreso o gasto previsto, normalizando la repetición como `saveForm` de la web.
    static func saveExpected(_ p: inout JSONValue, collection: String, item: JSONValue) throws {
        guard collection == "expected_income" || collection == "expected_expense" else { throw EditError.notFound }
        var o = item
        let name = Engine.str(o["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { throw FormError.missingName }
        guard abs(Engine.num(o["amount"])) > 0 else { throw FormError.invalidAmount }
        let rep = o["repeat"]
        if rep == .string("q") {
            let a = Engine.num(o["q1"]).rounded(), b = Engine.num(o["q2"]).rounded()
            guard a >= 1, a <= 31, b >= 1, b <= 31 else { throw FormError.invalidDays }
            let r = Engine.qMake(.number(a), .number(b))
            o["repeat"] = .string(r)
            if let d = LocalDate(iso: Engine.str(o["date"])) { o["date"] = .string(Engine.qNext(d, r, inclusive: true).iso) }
        } else if rep == .string("m") || (rep.map { Engine.isQ($0) } ?? false) {
            // se queda como está
        } else {
            o["repeat"] = .number(Double(Engine.str(rep)) ?? Engine.num(rep))
        }
        o["q1"] = nil; o["q2"] = nil; o["snooze"] = nil
        if !Engine.flag(o["repeat"]) { o["until"] = .string("") }
        let until = Engine.str(o["until"])
        if !until.isEmpty && until < Engine.str(o["date"]) { throw FormError.endBeforeStart }
        o["name"] = .string(name)
        var list = p[collection]?.arrayValue ?? []
        if let i = list.firstIndex(where: { $0["id"] == o["id"] }) { list[i] = o } else { list.append(o) }
        p[collection] = .array(list)
    }

    static func deleteExpected(_ p: inout JSONValue, collection: String, id: JSONValue) {
        guard var list = p[collection]?.arrayValue else { return }
        list.removeAll { $0["id"] == id }
        p[collection] = .array(list)
    }

    // MARK: trabajos

    static func saveJob(_ p: inout JSONValue, item: JSONValue, newId: String) throws {
        var o = item
        if o["id"] == nil || Engine.str(o["id"]).isEmpty { o["id"] = .string(newId) }
        let name = Engine.str(o["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { throw FormError.missingName }
        guard abs(Engine.num(o["rate"])) > 0 else { throw FormError.invalidAmount }
        if Engine.str(o["mode"]) == "s" { o["hours"] = .number(0); o["tax"] = .number(0) } else { o["mode"] = .string("h") }
        var freq = Engine.str(o["freq"])
        if !["w", "b", "q", "m"].contains(freq) { freq = "b"; o["freq"] = .string(freq) }
        if freq == "q" {
            let a = Engine.num(o["q1"]).rounded(), b = Engine.num(o["q2"]).rounded()
            guard a >= 1, a <= 31, b >= 1, b <= 31 else { throw FormError.invalidDays }
            let x = Engine.qDays("q\(Int(a)),\(Int(b))")
            o["q1"] = .number(Double(x.0)); o["q2"] = .number(Double(x.1))
            if let d = LocalDate(iso: Engine.str(o["start"])) {
                o["start"] = .string(Engine.qNext(d, Engine.str(Engine.jobRep("q", o)), inclusive: true).iso)
            }
        } else { o["q1"] = nil; o["q2"] = nil }
        o["sim"] = .number(Engine.num(o["sim"]) != 0 ? 1 : 0)
        o["tax"] = .number(max(0, min(90, Engine.num(o["tax"]))))
        o["hours"] = .number(max(0, min(168, Engine.num(o["hours"]))))
        if Engine.str(o["mode"]) != "s" && !(Engine.num(o["hours"]) > 0) { throw FormError.invalidHours }
        if Engine.str(o["start"]).isEmpty { throw FormError.missingStart }
        let until = Engine.str(o["until"])
        if !until.isEmpty && until < Engine.str(o["start"]) { throw FormError.endBeforeStart }
        o["name"] = .string(name)
        var list = p["jobs"]?.arrayValue ?? []
        if let i = list.firstIndex(where: { $0["id"] == o["id"] }) { list[i] = o } else { list.append(o) }
        p["jobs"] = .array(list)
        syncJobs(&p, newId: newId)
    }

    static func deleteJob(_ p: inout JSONValue, id: JSONValue) {
        var list = p["jobs"]?.arrayValue ?? []
        list.removeAll { $0["id"] == id }
        p["jobs"] = .array(list)
        syncJobs(&p, newId: "")
    }

    /// Cada trabajo real genera un ingreso previsto recurrente (`syncJobs` de la web).
    static func syncJobs(_ p: inout JSONValue, newId: String) {
        let all = p["expected_income"]?.arrayValue ?? []
        var old: [String: JSONValue] = [:]
        for e in all where !Engine.str(e["job"]).isEmpty { old[Engine.str(e["job"])] = e }
        var out = all.filter { Engine.str($0["job"]).isEmpty }
        for j in p["jobs"]?.arrayValue ?? [] {
            if Engine.num(j["sim"]) != 0 { continue }
            let jid = Engine.str(j["id"])
            let rep = Engine.jobRep(Engine.str(j["freq"]), j)
            let o = old[jid]
            let keep = o != nil && Engine.str(o!["jstart"]) == Engine.str(j["start"]) && Engine.str(o!["date"]) > Engine.str(j["start"]) && o!["repeat"] == rep
            let id = o?["id"] ?? .string(String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased())
            out.append(.object(["id": id, "job": j["id"] ?? .null, "jstart": j["start"] ?? .null, "name": j["name"] ?? .null,
                                "amount": .number(Engine.jobNet(j)), "acc": j["acc"] ?? .null,
                                "date": keep ? (o!["date"] ?? .null) : (j["start"] ?? .null), "repeat": rep,
                                "until": .string(Engine.str(j["until"]))]))
        }
        p["expected_income"] = .array(out)
    }

    // MARK: gastos simulados y pagos de crédito

    /// Guarda un gasto simulado (`planned`); el monto ya viene en USD como lo guarda la web.
    static func savePlanned(_ p: inout JSONValue, item: JSONValue) throws {
        var o = item
        if Engine.str(o["kind"]) == "pay" {
            guard (p["cards"]?.arrayValue ?? []).contains(where: { $0["id"] == o["card"] }) else { throw FormError.missingCard }
        } else { o["card"] = nil }
        let name = Engine.str(o["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { throw FormError.missingName }
        guard abs(Engine.num(o["amount"])) > 0 else { throw FormError.invalidAmount }
        o["name"] = .string(name)
        var list = p["planned"]?.arrayValue ?? []
        if let i = list.firstIndex(where: { $0["id"] == o["id"] }) { list[i] = o } else { list.append(o) }
        p["planned"] = .array(list)
    }

    static func deletePlanned(_ p: inout JSONValue, id: JSONValue) {
        var list = p["planned"]?.arrayValue ?? []
        list.removeAll { $0["id"] == id }
        p["planned"] = .array(list)
    }

    static func setPlannedOn(_ p: inout JSONValue, id: JSONValue, on: Bool) {
        var list = p["planned"]?.arrayValue ?? []
        for i in list.indices where list[i]["id"] == id { list[i]["on"] = .bool(on) }
        p["planned"] = .array(list)
    }

    /// Pago a una tarjeta o préstamo (`registerPay`): sube el saldo de la tarjeta y, si hay cuenta de origen, la descuenta.
    static func registerPay(_ p: inout JSONValue, card: JSONValue, amount: Double, fromAmount: Double, date: String,
                            from: JSONValue?, note: String, now: Double, pair: String) {
        func push(_ amt: Double, _ note: String, _ acc: JSONValue, pair: String?) {
            let id = nextTxId(p, now: now)
            var tx: [String: JSONValue] = ["id": .number(id), "date": .string(date), "amount": .number(amt), "category": .string(Engine.payCategory), "note": .string(note), "acc": acc]
            if let pair { tx["pair"] = .string(pair) }
            var list = p["transactions"]?.arrayValue ?? []
            list.append(.object(tx))
            p["transactions"] = .array(list)
            applyTo(&p, acc, amt)
        }
        let hasFrom = from.map { f in (p["accounts"]?.arrayValue ?? []).contains(where: { $0["id"] == f }) } ?? false
        push(amount, note, card, pair: hasFrom ? pair : nil)
        if hasFrom, let from { push(-fromAmount, "Pago a " + Engine.str(((p["cards"]?.arrayValue ?? []).first { $0["id"] == card })?["name"]), from, pair: pair) }
    }

    /// Ejecuta un gasto simulado hoy: lo registra como movimiento real y lo quita de la lista.
    static func execPlannedExpense(_ p: inout JSONValue, id: JSONValue, amount: Double, account: String, category: String, note: String,
                                   date: String, now: Double) throws {
        guard amount > 0 else { throw FormError.invalidAmount }
        _ = try addTransaction(&p, date: date, amount: -amount, category: category, note: note, account: account, now: now)
        deletePlanned(&p, id: id)
    }
}
