import Foundation

/// Combinación de perfiles de 3 vías, portada línea por línea de `mergeData` (dev/app/src/app.html).
/// Con la última versión sincronizada como base: lo que cambió de un solo lado gana sin discusión; si cambió de los dos, gana la edición
/// más reciente; los saldos se suman por diferencia; lo borrado se respeta con lápidas (que caducan a los 90 días).
/// Los vectores de `Tests/.../Fixtures/merge.json` salen de ejecutar el código de la web, así que Swift debe dar el mismo resultado.
public enum Merge {
    static let collections = ["accounts", "cards", "savings", "subs", "transactions", "expected_income", "expected_expense", "planned", "jobs", "budgetSets"]
    static let fields = ["settings", "history", "recurring", "budget", "cats", "ovr", "firstHalf", "halfSnaps"]
    static let objectFields: Set<String> = ["settings", "budget", "ovr", "halfSnaps"]
    static let deltaFields: [String: [String]] = ["accounts": ["balance"], "cards": ["balance"], "savings": ["balance"]]

    // MARK: comparaciones

    /// `mgSig`: undefined cuenta como null.
    private static func same(_ a: JSONValue?, _ b: JSONValue?) -> Bool { (a ?? .null) == (b ?? .null) }

    /// `mgCmp`: compara ignorando el campo `mod` en cualquier nivel.
    private static func stripMod(_ v: JSONValue) -> JSONValue {
        switch v {
        case .object(let o):
            var r: [String: JSONValue] = [:]
            for (k, x) in o where k != "mod" { r[k] = stripMod(x) }
            return .object(r)
        case .array(let a): return .array(a.map(stripMod))
        default: return v
        }
    }
    private static func cmpEq(_ a: JSONValue, _ b: JSONValue) -> Bool { stripMod(a) == stripMod(b) }

    private static func isEmpty(_ v: JSONValue?) -> Bool {
        switch v {
        case .none, .some(.null): return true
        case .some(.string(let s)): return s.isEmpty
        case .some(.array(let a)): return a.isEmpty
        case .some(.object(let o)): return o.isEmpty
        default: return false
        }
    }

    private static func idString(_ item: JSONValue) -> String? {
        guard case .object = item, let id = item["id"], !id.isNull else { return nil }
        return JS.string(id)
    }

    private static func itemMap(_ v: JSONValue?) -> [String: JSONValue] {
        var m: [String: JSONValue] = [:]
        for it in v?.arrayValue ?? [] { if let id = idString(it) { m[id] = it } }
        return m
    }

    /// Mapa que conserva el orden de inserción (el de `Map` de JS), porque el orden de las lápidas sale en el resultado.
    private struct Ordered {
        var keys: [String] = []
        var values: [String: Double] = [:]
        mutating func put(_ k: String, _ v: Double) { if values[k] == nil { keys.append(k) }; values[k] = v }
    }

    // MARK: colecciones

    private static func round2(_ n: Double) -> Double { JS.round(n * 100) / 100 }

    private static func mergeCollection(_ col: String, _ B: JSONValue?, _ L: JSONValue?, _ R: JSONValue?, _ tL: [String: Double], _ tR: [String: Double]) -> [JSONValue] {
        let bm = itemMap(B), lm = itemMap(L), rm = itemMap(R)
        var seen = Set<String>(), order: [String] = []
        for it in (L?.arrayValue ?? []) + (R?.arrayValue ?? []) {
            if let id = idString(it), !seen.contains(id) { seen.insert(id); order.append(id) }
        }
        var out: [JSONValue] = []
        for id in order {
            let l = lm[id], r = rm[id], b = bm[id]
            if let l, let r {
                if cmpEq(l, r) {
                    // `l.mod >= r.mod`: con un campo ausente la comparación de JS da falso y se queda r
                    if let lmod = l["mod"]?.doubleValue, let rmod = r["mod"]?.doubleValue, lmod >= rmod { out.append(l) } else { out.append(r) }
                    continue
                }
                if let b, cmpEq(l, b) { out.append(r); continue }
                if let b, cmpEq(r, b) { out.append(l); continue }
                var w = JS.mod(r) > JS.mod(l) ? r : l   // gana la edición más reciente; empate: este dispositivo
                for f in deltaFields[col] ?? [] {
                    if let b, let bv = b[f]?.doubleValue, let lv = l[f]?.doubleValue, let rv = r[f]?.doubleValue {
                        w[f] = .number(round2(bv + (lv - bv) + (rv - bv)))
                    }
                }
                if col == "savings" {
                    var seenKeys = Set<String>(), log: [JSONValue] = []
                    for x in (l["log"]?.arrayValue ?? []) + (r["log"]?.arrayValue ?? []) {
                        let k = logKey(x)
                        if !seenKeys.contains(k) { seenKeys.insert(k); log.append(x) }
                    }
                    let indexed = log.enumerated().sorted { a, c in
                        let da = Array((a.element["date"]?.stringValue ?? "").utf16), dc = Array((c.element["date"]?.stringValue ?? "").utf16)
                        if da == dc { return a.offset < c.offset }      // desempate estable, como Array.sort de JS
                        return da.lexicographicallyPrecedes(dc)
                    }
                    w["log"] = .array(indexed.map(\.element))
                }
                w["mod"] = .number(max(JS.mod(l), JS.mod(r)))
                out.append(w)
                continue
            }
            let it = (l ?? r)!
            let tomb = l != nil ? tR : tL
            let t = tomb[col + "|" + id]
            if let t, t > JS.mod(it) { continue }                      // el otro lado lo borró después de la última edición
            if b != nil, t == nil, cmpEq(it, b!) { continue }          // estaba en la base, el otro lado ya no lo tiene y aquí no cambió: se fue
            out.append(it)
        }
        return out
    }

    /// `x.date + '|' + x.amount + '|' + (x.from || '')`
    private static func logKey(_ x: JSONValue) -> String {
        let d = x["date"].map { JS.string($0) } ?? "undefined"
        let a = x["amount"].map { JS.string($0) } ?? "undefined"
        let f = JS.truthy(x["from"]) ? JS.string(x["from"]!) : ""
        return d + "|" + a + "|" + f
    }

    // MARK: objetos por llave

    private static func mergeObject(_ B: JSONValue?, _ L: JSONValue?, _ R: JSONValue?) -> JSONValue {
        let lo = L?.objectValue ?? [:], ro = R?.objectValue ?? [:], bo = B?.objectValue
        var out: [String: JSONValue] = [:]
        for k in Set(lo.keys).union(ro.keys) {
            let l = lo[k], r = ro[k], b = bo?[k]
            let inL = lo[k] != nil, inR = ro[k] != nil
            let bTruthy = JS.truthy(B)
            if inL && inR {
                if same(l, r) { out[k] = l }
                else if bTruthy && same(l, b) { out[k] = r }
                else if bTruthy && same(r, b) { out[k] = l }
                else if isEmpty(l) && !isEmpty(r) { out[k] = r }
                else { out[k] = l }
            } else if inL {
                if !(bTruthy && bo?[k] != nil && same(l, b)) { out[k] = l }
            } else {
                if !(bTruthy && bo?[k] != nil && same(r, b)) { out[k] = r }
            }
        }
        return .object(out)
    }

    // MARK: perfil completo

    private static func tombMap(_ d: JSONValue, horizon: Double) -> Ordered {
        var m = Ordered()
        for x in d["tomb"]?.arrayValue ?? [] {
            guard let t = x["t"]?.doubleValue, t > horizon, let c = x["c"]?.stringValue, let idv = x["id"] else { continue }
            let key = c + "|" + JS.string(idv)
            m.put(key, max(m.values[key] ?? 0, t))
        }
        return m
    }

    /// `base` es la última versión sincronizada (nil la primera vez). `now` es la hora actual en milisegundos (se inyecta para poder probar).
    public static func profiles(base: JSONValue?, local: JSONValue, remote: JSONValue, now: Double = Date().timeIntervalSince1970 * 1000) -> JSONValue {
        let B: JSONValue? = (base?.isNull ?? true) ? nil : base
        let horizon = now - 90 * 864e5
        let tL = tombMap(local, horizon: horizon), tR = tombMap(remote, horizon: horizon)
        var out = remote.objectValue ?? [:]
        for (k, v) in local.objectValue ?? [:] { out[k] = v }          // Object.assign({}, remote, local)

        for c in collections {
            out[c] = .array(mergeCollection(c, B?[c], local[c], remote[c], tL.values, tR.values))
        }

        var fmod: [String: JSONValue] = [:]
        for f in fields {
            let l = local[f], r = remote[f], b = B?[f]
            let fl = local["fmod"]?[f]?.doubleValue ?? 0, fr = remote["fmod"]?[f]?.doubleValue ?? 0
            var chosen: JSONValue?
            if objectFields.contains(f) {
                chosen = mergeObject(b, l, r)
            } else if same(l, r) { chosen = l }
            else if B != nil && same(l, b) { chosen = r }
            else if B != nil && same(r, b) { chosen = l }
            else { chosen = fr > fl ? r : l }
            if let chosen { out[f] = chosen } else { out.removeValue(forKey: f) }   // undefined: la clave desaparece al serializar
            fmod[f] = .number(max(fl, fr))
        }
        out["fmod"] = .object(fmod)

        var all = Ordered()
        for m in [tL, tR] { for k in m.keys { all.put(k, max(all.values[k] ?? 0, m.values[k]!)) } }
        var tombs: [JSONValue] = []
        for k in all.keys {
            guard let i = k.firstIndex(of: "|") else { continue }
            let c = String(k[k.startIndex..<i]), id = String(k[k.index(after: i)...])
            let t = all.values[k]!
            let live = (out[c]?.arrayValue ?? []).contains { x in
                guard let xid = idString(x) else { return false }
                return xid == id && JS.mod(x) >= t
            }
            if !live { tombs.append(.object(["c": .string(c), "id": .string(id), "t": .number(t)])) }
        }
        out["tomb"] = .array(tombs)
        out["demo"] = .bool(false)
        return .object(out)
    }
}
