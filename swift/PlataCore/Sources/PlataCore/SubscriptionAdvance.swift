import Foundation

public extension ProfileEditor {
    /// «Adelantar cobro» (`subAdvance` de la web): registra hoy el cobro de la suscripción y salta el próximo cobro de la serie.
    /// `account` y `amount` los decide quien llama (la cuenta de la suscripción, o una de su moneda, y el monto ya convertido).
    @discardableResult
    static func advanceSubscription(_ p: inout JSONValue, id: JSONValue, account: JSONValue, amount: Double, today: String, now: Double,
                                    jitter: Int = Int.random(in: 0..<1000)) throws -> String {
        guard let sb = (p["subs"]?.arrayValue ?? []).first(where: { $0["id"] == id }) else { throw EditError.notFound }
        guard amount > 0, amount.isFinite else { throw EditError.invalidAmount }
        let day = Int(Engine.num(sb["day"])) == 0 ? 1 : Int(Engine.num(sb["day"]))
        let sid = Engine.idStr(sb["id"])
        var ovr = p["ovr"]?.objectValue ?? [:]
        var next = Engine.dueAfter(day: day, after: today)
        var i = 0
        while i < 24, let o = ovr["sub:" + sid + ":" + next], JS.truthy(o["skip"]) { next = Engine.dueAfter(day: day, after: next); i += 1 }
        let name = Engine.str(sb["name"])
        // la categoría del último cobro de esa suscripción; si no hay, «Ocio»
        var cat = "Ocio", best = ""
        for t in p["transactions"]?.arrayValue ?? [] where Engine.str(t["note"]) == name && Engine.num(t["amount"]) < 0 {
            let d = Engine.str(t["date"])
            if best.isEmpty || d > best { best = d; cat = Engine.str(t["category"]) }
        }
        let txId = nextTxId(p, now: now, jitter: jitter)
        let tx: JSONValue = .object(["id": .number(txId), "date": .string(today), "amount": .number(-amount), "category": .string(cat),
                                     "note": .string(name), "acc": account, "sub": sb["id"] ?? .null])
        var list = p["transactions"]?.arrayValue ?? []
        list.append(tx)
        p["transactions"] = .array(list)
        applyTo(&p, account, -amount)
        ovr["sub:" + sid + ":" + next] = .object(["skip": .bool(true)])
        p["ovr"] = .object(ovr)
        return next
    }
}
