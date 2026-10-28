import Foundation

/// Lo necesario para deshacer una acción de Revisión: los movimientos como estaban y, si se creó algo, qué y dónde.
public struct ReviewUndo: Equatable, Sendable {
    public var snap: [JSONValue]
    public var coll: String?
    public var madeId: JSONValue?
}

public extension ProfileEditor {
    private static func replaceTx(_ p: inout JSONValue, _ id: JSONValue, _ f: (inout JSONValue) -> Void) {
        var list = p["transactions"]?.arrayValue ?? []
        guard let i = list.firstIndex(where: { $0["id"] == id }) else { return }
        f(&list[i])
        p["transactions"] = .array(list)
    }

    private static func tx(_ p: JSONValue, _ ids: [String]) -> [JSONValue] {
        let all = p["transactions"]?.arrayValue ?? []
        return ids.compactMap { id in all.first { Engine.idStr($0["id"]) == id } }
    }

    /// Descarta una tarjeta («No es»): su clave queda en `settings.rv_off` (las últimas 300).
    static func reviewDismiss(_ p: inout JSONValue, key: String) {
        var settings = p["settings"] ?? .object([:])
        var off = (settings["rv_off"]?.arrayValue ?? [])
        off.append(.string(key))
        settings["rv_off"] = .array(Array(off.suffix(300)))
        p["settings"] = settings
    }

    /// «Mostrar las descartadas».
    static func reviewReset(_ p: inout JSONValue) {
        var settings = p["settings"] ?? .object([:])
        settings["rv_off"] = .array([])
        p["settings"] = settings
    }

    /// Cierra el aviso de Resumen hasta que haya más sugerencias que ahora.
    static func reviewBanner(_ p: inout JSONValue, count: Int) {
        var settings = p["settings"] ?? .object([:])
        settings["rv_bn"] = .number(Double(count))
        p["settings"] = settings
    }

    /// Acepta una tarjeta de Revisión (`revAct`). Devuelve cómo deshacerla (nil si no se puede) y el aviso que se muestra.
    /// `big` y `gap` no cambian nada aquí: la pantalla abre la edición del movimiento o la importación.
    @discardableResult
    static func reviewAccept(_ p: inout JSONValue, card r: ReviewCard, engine e: Engine, now: Double, newId: () -> String) throws -> (undo: ReviewUndo?, message: String) {
        let txs = tx(p, r.txIds)
        let XFER = Engine.xferCategory, PAY = Engine.payCategory
        func snap() -> ReviewUndo { ReviewUndo(snap: txs, coll: nil, madeId: nil) }
        func set(_ x: JSONValue, _ f: (inout JSONValue) -> Void) { replaceTx(&p, x["id"] ?? .null, f) }
        switch r.kind {
        case "xfer":
            guard txs.count == r.txIds.count else { throw EditError.notFound }
            let u = snap(), pid = JSONValue.string(newId())
            for x in txs { set(x) { $0["category"] = .string(XFER); $0["pair"] = pid } }
            return (u, "Transferencia registrada")
        case "own":
            let u = snap()
            for x in txs { set(x) { $0["category"] = .string(XFER) } }
            return (u, "Transferencia registrada")
        case "pay2":
            guard txs.count == 2 else { throw EditError.notFound }
            let u = snap(), ex = txs[0], pay = txs[1]
            let kd = Engine.str(e.accOf(pay["acc"])?["name"])
            let pid = JSONValue.string(newId()), wasPay = Engine.str(pay["category"]) == PAY
            set(ex) { $0["category"] = .string(PAY); $0["note"] = .string("Pago a " + kd); $0["pair"] = pid }
            set(pay) { $0["pair"] = pid; if !wasPay { $0["category"] = .string(PAY); $0["note"] = .string("Pago de " + kd) } }
            return (u, "Pago registrado")
        case "dup":
            guard let t = txs.first else { throw EditError.notFound }
            try deleteTransaction(&p, id: t["id"] ?? .null)
            return (nil, "Movimiento eliminado")
        case "card":
            guard let t = txs.first, let cardId = r.card,
                  let card = (p["cards"]?.arrayValue ?? []).first(where: { Engine.idStr($0["id"]) == cardId }),
                  let acc = e.accOf(t["acc"]) else { throw EditError.notFound }
            var list = p["transactions"]?.arrayValue ?? []
            list.removeAll { $0["id"] == t["id"] }
            p["transactions"] = .array(list)
            applyTo(&p, acc["id"], -Engine.num(t["amount"]))
            let amt = Engine.round2(e.fromUSD(e.usd(-Engine.num(t["amount"]), Engine.str(acc["cur"])), Engine.str(card["cur"])))
            let from = Engine.round2(e.fromUSD(e.usd(amt, Engine.str(card["cur"])), Engine.str(acc["cur"])))
            registerPay(&p, card: card["id"] ?? .null, amount: amt, fromAmount: from, date: Engine.str(t["date"]), from: acc["id"],
                        note: "Pago de " + Engine.str(card["name"]), now: now, pair: newId())
            return (nil, "Pago registrado")
        case "rec":
            guard let first = txs.first, let last = txs.last, txs.count == r.txIds.count else { throw EditError.notFound }
            let id = JSONValue.string(newId())
            let lastDate = Engine.str(last["date"])
            let lastDay = Double(Int(lastDate.dropFirst(8).prefix(2)) ?? 0)
            var u = snap()
            let name = r.name ?? "", amt = r.amt ?? 0, cur = r.cur ?? "", acc = JSONValue.string(r.acc ?? "")
            switch r.type {
            case "sub":
                var subs = p["subs"]?.arrayValue ?? []
                subs.append(.object(["id": id, "since": first["date"] ?? .null, "name": .string(name), "amount": .number(amt), "cur": .string(cur),
                                     "day": .number(lastDay != 0 ? lastDay : 1), "acc": acc]))
                p["subs"] = .array(subs)
                for x in txs { set(x) { $0["sub"] = id } }
                u.coll = "subs"; u.madeId = id
                return (u, "Suscripción creada")
            case "fix":
                let rep: JSONValue = r.cad == "m" ? .string("m") : r.cad == "w" ? .number(7) : .number(14)
                var ee = p["expected_expense"]?.arrayValue ?? []
                let d = LocalDate(iso: lastDate).map { Engine.nextRep($0, rep).iso } ?? lastDate
                ee.append(.object(["id": id, "name": .string(name), "amount": .number(amt), "acc": acc, "date": .string(d), "repeat": rep, "until": .string("")]))
                p["expected_expense"] = .array(ee)
                u.coll = "expected_expense"; u.madeId = id
                return (u, "Gasto fijo creado")
            default:
                let f = r.cad ?? "m"
                let rate = f == "m" ? amt : f == "w" ? Engine.round2(amt * 52 / 12) : Engine.round2(amt * 2)
                var jo: JSONValue = .object(["id": id, "mode": .string("s"), "name": .string(name), "rate": .number(rate), "hours": .number(0), "tax": .number(0),
                                             "freq": .string(f), "acc": acc, "start": .string(""), "until": .string(""), "sim": .number(0)])
                if let q = r.q, q.count == 2 {
                    let jq = Engine.qDays("q\(q[0]),\(q[1])")
                    jo["q1"] = .number(Double(jq.0)); jo["q2"] = .number(Double(jq.1))
                }
                if let d = LocalDate(iso: lastDate) { jo["start"] = .string(Engine.nextRep(d, Engine.jobRep(f, jo)).iso) }
                var jobs = p["jobs"]?.arrayValue ?? []
                jobs.append(jo)
                p["jobs"] = .array(jobs)
                for x in txs { set(x) { $0["job"] = id } }
                syncJobs(&p, newId: newId())
                u.coll = "jobs"; u.madeId = id
                return (u, "Trabajo creado")
            }
        default:
            throw EditError.notFound
        }
    }

    /// «Convertir N casi seguras»: todas las transferencias casi seguras de una vez.
    static func reviewAcceptAll(_ p: inout JSONValue, cards: [ReviewCard], newId: () -> String) -> ReviewUndo {
        var u = ReviewUndo(snap: [], coll: nil, madeId: nil)
        for r in cards where r.kind == "xfer" && r.hi {
            let pid = JSONValue.string(newId())
            for x in tx(p, r.txIds) {
                u.snap.append(x)
                replaceTx(&p, x["id"] ?? .null) { $0["category"] = .string(Engine.xferCategory); $0["pair"] = pid }
            }
        }
        return u
    }

    /// Deshace la última acción: devuelve los movimientos como estaban y quita lo que se creó.
    static func reviewUndo(_ p: inout JSONValue, _ u: ReviewUndo) {
        var list = p["transactions"]?.arrayValue ?? []
        for s in u.snap { if let i = list.firstIndex(where: { $0["id"] == s["id"] }) { list[i] = s } }
        p["transactions"] = .array(list)
        if let coll = u.coll, let id = u.madeId {
            var c = p[coll]?.arrayValue ?? []
            c.removeAll { $0["id"] == id }
            p[coll] = .array(c)
            if coll == "jobs" { syncJobs(&p, newId: "") }
        }
    }
}
