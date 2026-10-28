import Foundation

/// Sellado de ediciones para sincronizar: la fecha de edición (`mod`) de cada elemento, las lápidas (`tomb`) de lo borrado y la fecha
/// de cambio de los campos sueltos (`fmod`). Es lo que `mergeData` necesita para decidir qué versión gana. Port de `syncStamp` de la web.
///
/// Se llama después de cada cambio al perfil (la web lo hace en `persist()`). Recuerda cómo estaba cada elemento la última vez,
/// así que debe vivir tanto como la sesión: la primera vez solo toma la foto y marca los elementos sin `mod` con 0.
public final class SyncStamper {
    static let collections = ["accounts", "cards", "savings", "subs", "transactions", "expected_income", "expected_expense", "planned", "jobs", "budgetSets"]
    static let fields = ["settings", "history", "recurring", "budget", "cats", "ovr", "firstHalf", "halfSnaps"]
    static let tombHorizon = 90.0 * 864e5

    private struct Seen {
        var order: [String] = []                 // orden de inserción, como el Map de JS
        var sig: [String: String] = [:]
    }

    private var started = false
    private var cols: [String: Seen] = [:]
    private var fieldSig: [String: String] = [:]

    public init() {}

    /// Firma de un elemento sin sus fechas de edición.
    private static func signature(_ v: JSONValue, skipMod: Bool) -> String {
        func strip(_ x: JSONValue) -> JSONValue {
            switch x {
            case .object(let o):
                var r: [String: JSONValue] = [:]
                for (k, y) in o where !(skipMod && k == "mod") { r[k] = strip(y) }
                return .object(r)
            case .array(let a): return .array(a.map(strip))
            default: return x
            }
        }
        let data = (try? strip(v).jsonData(sorted: true)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// Sella `profile` con la hora `now` (milisegundos desde 1970, como `Date.now()`).
    public func stamp(_ profile: inout JSONValue, now: Double) {
        guard case .object(var d) = profile else { return }
        let first = !started
        started = true

        let horizon = now - SyncStamper.tombHorizon
        var tomb: [JSONValue] = (d["tomb"]?.arrayValue ?? []).filter { x in
            guard JS.truthy(x), let t = x["t"] else { return false }
            return Engine.jsNumber(t) > horizon
        }

        for col in SyncStamper.collections {
            guard case .array(var list)? = d[col] else { continue }
            var prev = cols[col] ?? Seen()
            var seen = Set<String>()
            for i in list.indices {
                guard case .object(var it) = list[i], let idv = it["id"], !idv.isNull else { continue }
                let id = JS.string(idv)
                let sig = SyncStamper.signature(list[i], skipMod: true)
                seen.insert(id)
                if prev.sig[id] == nil {
                    if !JS.truthy(it["mod"]) { it["mod"] = .number(first ? 0 : now) }
                    if !first {
                        tomb = tomb.filter { x in !(x["c"] == JSONValue.string(col) && x["id"].map { JS.string($0) } == id) }
                    }
                    prev.order.append(id)
                } else if prev.sig[id] != sig {
                    it["mod"] = .number(now)
                }
                list[i] = .object(it)
                prev.sig[id] = SyncStamper.signature(list[i], skipMod: true)
            }
            for id in prev.order where !seen.contains(id) {
                prev.sig[id] = nil
                if !first { tomb.append(.object(["c": .string(col), "id": .string(id), "t": .number(now)])) }
            }
            prev.order.removeAll { !seen.contains($0) }
            cols[col] = prev
            d[col] = .array(list)
        }
        d["tomb"] = .array(tomb)

        var fmod: [String: JSONValue] = d["fmod"]?.objectValue ?? [:]
        for f in SyncStamper.fields {
            let s = SyncStamper.signature(d[f] ?? .null, skipMod: false)
            if let old = fieldSig[f], old != s { fmod[f] = .number(now) }
            fieldSig[f] = s
        }
        d["fmod"] = .object(fmod)
        profile = .object(d)
    }
}
