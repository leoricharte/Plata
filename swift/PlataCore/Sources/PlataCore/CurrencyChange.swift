import Foundation

/// Cambiar de moneda principal o segunda (`applyCurrencies` / `askCurChange` de la web).
public enum CurrencyChange {
    public enum Mode: Equatable, Sendable {
        case keep                 // mismos números
        case assigned             // al tipo de cambio asignado
        case manual(Double)       // al tipo que escribe la persona
    }

    /// Qué cambiaría: monedas que quedan fuera (en orden), tipo asignado cuando es una sola.
    public struct Plan: Equatable, Sendable {
        public var lost: [String]
        public var assigned: Double       // 0 si hay varias monedas perdidas
        public var single: Bool { lost.count == 1 }
        public var needsAsk: Bool { !lost.isEmpty }
    }

    private static let collections: [(key: String, kind: String)] = [("accounts", "account"), ("cards", "debt"), ("subs", "sub"), ("savings", "saving")]
    private static let moneyFields: [String: [String]] = ["account": ["balance"], "saving": ["goal", "balance", "monthly"], "debt": ["balance", "limit", "payment"], "sub": ["amount"]]

    private static func settings(_ p: JSONValue) -> (primary: String, secondary: String, fx: Double) {
        let s = p["settings"]
        let c1 = s?["currency"]?.stringValue ?? "USD"
        let pr = Currencies.table[c1] != nil || c1 == (s?["customCur"]?.stringValue ?? "~") ? c1 : "USD"
        let c2 = s?["currency2"]?.stringValue ?? ""
        let sec = (Currencies.table[c2] != nil || c2 == (s?["customCur"]?.stringValue ?? "~")) && c2 != pr ? c2 : ""
        return (pr, sec, s?["fx"]?.doubleValue ?? 0)
    }

    /// `curRateBetween`.
    static func rate(_ p: JSONValue, from: String, to: String) -> Double {
        let st = settings(p)
        let fx = st.fx > 0 ? st.fx : (st.secondary.isEmpty ? 1 : Onboarding.fxDefault(st.primary, st.secondary))
        if !st.secondary.isEmpty, from == st.primary, to == st.secondary { return fx }
        if !st.secondary.isEmpty, from == st.secondary, to == st.primary { return 1 / fx }
        let r = Onboarding.fxDefault(from, to)
        return r > 0 ? r : 1
    }

    private static func toPrecision4(_ v: Double) -> Double { Double(String(format: "%.4g", v)) ?? v }

    private static func lostItems(_ p: JSONValue, keep: [String]) -> [String] {
        var out: [String] = []
        for c in collections {
            for o in p[c.key]?.arrayValue ?? [] {
                let cur = o["cur"]?.stringValue ?? ""
                if !keep.contains(cur), !out.contains(cur) { out.append(cur) }
            }
        }
        return out
    }

    public static func plan(_ p: JSONValue, primary: String, secondary: String) -> Plan {
        let sec = secondary == primary ? "" : secondary
        let lost = lostItems(p, keep: [primary] + (sec.isEmpty ? [] : [sec]))
        let asg = lost.count == 1 ? toPrecision4(rate(p, from: lost[0], to: primary)) : 0
        return Plan(lost: lost, assigned: asg)
    }

    private static func rnd(_ x: Double, _ cur: String) -> Double {
        Currencies.table[cur]?.dec == 0 ? JS.round(x) : JS.round(x * 100) / 100
    }

    private static func scaleOwn(_ o: inout JSONValue, kind: String, f: Double, cur: String) {
        guard f > 0, f != 1 else { return }
        for m in moneyFields[kind] ?? [] {
            let v = o[m]?.doubleValue ?? 0
            if v != 0 { o[m] = .number(rnd(v * f, cur)) }
        }
        if kind == "saving", var log = o["log"]?.arrayValue {
            for i in log.indices { if let a = log[i]["amount"]?.doubleValue { log[i]["amount"] = .number(rnd(a * f, cur)) } }
            o["log"] = .array(log)
        }
    }

    /// Lo que se mide en la moneda de una cuenta o tarjeta: movimientos, previstos, simulados y trabajos que la usan.
    private static func scaleLinked(_ p: inout JSONValue, id: String, f: Double, cur: String) {
        guard f > 0, f != 1 else { return }
        var ids = Set<String>()
        func sc(_ key: String, _ fields: [String]) {
            guard var list = p[key]?.arrayValue else { return }
            for i in list.indices where list[i]["acc"].map({ Engine.str($0) }) == id {
                for k in fields {
                    if let v = list[i][k]?.doubleValue, v != 0 { list[i][k] = .number(rnd(v * f, cur)) }
                }
                if let rid = list[i]["id"] { ids.insert(Engine.str(rid).isEmpty ? String(Int(rid.doubleValue ?? 0)) : Engine.str(rid)) }
            }
            p[key] = .array(list)
        }
        sc("transactions", ["amount"]); sc("expected_income", ["amount"]); sc("expected_expense", ["amount"]); sc("planned", ["amount"]); sc("jobs", ["rate"])
        if var ovr = p["ovr"]?.objectValue {
            for (k, x) in ovr {
                let q = k.split(separator: ":", omittingEmptySubsequences: false)
                if q.count > 1, ids.contains(String(q[1])), let a = x["amt"]?.doubleValue {
                    var nx = x; nx["amt"] = .number(rnd(a * f, cur)); ovr[k] = nx
                }
            }
            p["ovr"] = .object(ovr)
        }
    }

    /// Aplica las nuevas monedas. `mode` solo importa si `plan(...)` pide decidir qué hacer con los montos.
    public static func apply(_ p: inout JSONValue, primary: String, secondary: String, mode: Mode) {
        let sec = secondary == primary ? "" : secondary
        let old = settings(p)
        if primary == old.primary && sec == old.secondary { return }
        let keep = [primary] + (sec.isEmpty ? [] : [sec])
        // lo que sale de las monedas elegidas, con el tipo de cambio de antes del cambio
        var plan: [(key: String, index: Int, kind: String, factor: Double)] = []
        for c in collections {
            for (i, o) in (p[c.key]?.arrayValue ?? []).enumerated() {
                let cur = o["cur"]?.stringValue ?? ""
                if keep.contains(cur) { continue }
                let f: Double
                switch mode {
                case .keep: f = 1
                case .assigned: f = rate(p, from: cur, to: primary)
                case .manual(let r): f = r
                }
                plan.append((c.key, i, c.kind, f))
            }
        }
        var s = p["settings"] ?? .object([:])
        if primary == old.secondary && sec == old.primary && old.fx > 0 { s["fx"] = .number(toPrecision4(1 / old.fx)) }
        else if !sec.isEmpty { s["fx"] = .number(Onboarding.fxDefault(primary, sec)) }
        s["currency"] = .string(primary); s["currency2"] = .string(sec)
        p["settings"] = s
        for x in plan {
            guard var list = p[x.key]?.arrayValue, x.index < list.count else { continue }
            list[x.index]["cur"] = .string(primary)
            p[x.key] = .array(list)
        }
        for x in plan {
            guard var list = p[x.key]?.arrayValue, x.index < list.count else { continue }
            scaleOwn(&list[x.index], kind: x.kind, f: x.factor, cur: primary)
            let id = list[x.index]["id"].map { Engine.str($0) } ?? ""
            p[x.key] = .array(list)
            if x.kind == "account" || x.kind == "debt", !id.isEmpty { scaleLinked(&p, id: id, f: x.factor, cur: primary) }
        }
    }
}
