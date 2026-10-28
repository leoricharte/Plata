import Foundation

/// Perfiles de demostración. Los archivos traen las fechas ancladas a un día (`__anchor`); al cargarlos se mueven a hoy,
/// igual que `rebaseProfile` de la web: los movimientos se mueven por meses completos, lo previsto por días y lo futuro se descarta.
public enum DemoProfile {
    public static func rebase(_ source: JSONValue, today t: LocalDate) -> JSONValue {
        var d = source
        guard let anchorText = d["__anchor"]?.stringValue, let a = LocalDate(iso: anchorText) else {
            d["__anchor"] = nil
            return d
        }
        d["__anchor"] = nil
        let dd = t.days - a.days
        if dd == 0 { return d }
        let mm = (t.year * 12 + t.month0) - (a.year * 12 + a.month0)
        let tm = String(t.iso.prefix(7))
        let dl = max(0, t.day - a.day)
        let tt = t.iso

        func text(_ v: JSONValue?) -> String { v?.stringValue ?? "" }
        // corre por días
        func sh(_ v: JSONValue?) -> JSONValue? {
            guard let v, case .string(let s) = v, !s.isEmpty, let p = LocalDate(iso: s) else { return v }
            return .string(p.adding(days: dd).iso)
        }
        // corre por meses completos, conservando el día del mes (con tope al fin de mes)
        func shmText(_ s: String) -> String {
            guard !s.isEmpty, let p = LocalDate(iso: s) else { return s }
            let n = p.year * 12 + p.month0 + mm
            let y = LocalDate.floorDiv(n, 12), mo = LocalDate.floorMod(n, 12)
            return LocalDate(year: y, month0: mo, day: min(p.day, LocalDate.daysInMonth(year: y, month0: mo))).iso
        }
        func shm(_ v: JSONValue?) -> JSONValue? {
            guard let v, case .string(let s) = v else { return v }
            return .string(shmText(s))
        }
        // meses completos y, si cae en el mes actual, unos días más
        func shxText(_ s: String) -> String {
            var r = shmText(s)
            if !r.isEmpty, r.hasPrefix(tm), dl > 0, let p = LocalDate(iso: r) { r = p.adding(days: dl).iso }
            return r
        }

        let subNames = Set((d["subs"]?.arrayValue ?? []).map { text($0["name"]).lowercased() })

        // movimientos
        var txs: [JSONValue] = []
        for var x in d["transactions"]?.arrayValue ?? [] {
            if x["date"] == nil { continue }   // sin fecha: la web lo descarta al comparar con hoy
            let note = text(x["note"]).lowercased()
            let date = text(x["date"])
            x["date"] = .string(!note.isEmpty && subNames.contains(note) ? shmText(date) : shxText(date))
            if text(x["date"]) <= tt { txs.append(x) }
        }
        d["transactions"] = .array(txs)

        // aportes al ahorro
        var savings: [JSONValue] = []
        for var s in d["savings"]?.arrayValue ?? [] {
            if let log = s["log"]?.arrayValue {
                var kept: [JSONValue] = []
                for var l in log {
                    if l["date"] == nil { continue }
                    l["date"] = .string(shxText(text(l["date"])))
                    if text(l["date"]) <= tt { kept.append(l) }
                }
                s["log"] = .array(kept)
            }
            savings.append(s)
        }
        d["savings"] = .array(savings)

        // ingresos y gastos previstos
        for key in ["expected_income", "expected_expense"] {
            var list: [JSONValue] = []
            for var e in d[key]?.arrayValue ?? [] {
                if let v = sh(e["date"]) { e["date"] = v }
                if e["until"] != nil, let v = sh(e["until"]) { e["until"] = v }
                if let r = e["repeat"], Engine.isQ(r) {
                    e["date"] = .string(Engine.qNext(t, r.stringValue ?? "", inclusive: true).iso)
                }
                list.append(e)
            }
            d[key] = .array(list)
        }

        // planeados
        var planned: [JSONValue] = []
        for var p in d["planned"]?.arrayValue ?? [] {
            if let v = sh(p["date"]) { p["date"] = v }
            if p["until"] != nil, let v = sh(p["until"]) { p["until"] = v }
            planned.append(p)
        }
        d["planned"] = .array(planned)

        // sets de presupuesto
        var sets: [JSONValue] = []
        for var b in d["budgetSets"]?.arrayValue ?? [] {
            if b["from"] != nil, let v = shm(b["from"]) { b["from"] = v }
            if b["to"] != nil, let v = shm(b["to"]) { b["to"] = v }
            sets.append(b)
        }
        if d["budgetSets"] != nil { d["budgetSets"] = .array(sets) }

        // tarjetas con pago automático
        var cards: [JSONValue] = []
        for var c in d["cards"]?.arrayValue ?? [] {
            if var auto = c["auto"], auto.objectValue != nil, let v = sh(auto["next"]) {
                auto["next"] = v
                c["auto"] = auto
            }
            cards.append(c)
        }
        d["cards"] = .array(cards)

        // historial mensual ("AAAA-MM")
        var history: [JSONValue] = []
        for var h in d["history"]?.arrayValue ?? [] {
            let parts = text(h["month"]).split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                let n = parts[0] * 12 + (parts[1] - 1) + mm
                let y = LocalDate.floorDiv(n, 12), mo = LocalDate.floorMod(n, 12) + 1
                h["month"] = .string(String(y) + "-" + (mo < 10 ? "0" : "") + String(mo))
            }
            history.append(h)
        }
        d["history"] = .array(history)
        return d
    }

    /// Un perfil de demostración listo para usar: fechas movidas a hoy, migrado y marcado como demo.
    public static func load(_ data: Data, today: LocalDate) throws -> Profile {
        let v = try JSONValue(jsonData: data)
        var migrated = try Migration.migrate(Profile(raw: rebase(v, today: today))).raw
        if !JS.truthy(migrated["firstHalf"]) { migrated["firstHalf"] = .string("2000-01") }
        migrated["demo"] = .bool(true)
        return Profile(raw: migrated)
    }
}
