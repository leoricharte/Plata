import Foundation

public enum MigrationError: Error, Equatable {
    case notAProfile      // no es un objeto
    case empty            // no trae movimientos, tarjetas ni cuentas
    case legacyFormat     // versión anterior a 3 (la web la completa con datos de ejemplo; aquí no se admite)
}

/// Lee un perfil de cualquier origen (archivo, nube) y lo deja en la forma que espera el resto del código:
/// `migrate` + `safeProfile` + `anRead`/`anStamp` de la web. Lo que la web descarta también se descarta aquí (campos de primer nivel que no conoce).
public enum Migration {
    public static func migrate(_ profile: Profile) throws -> Profile { Profile(raw: try migrate(profile.raw)) }

    public static func migrate(_ input: JSONValue) throws -> JSONValue {
        guard case .object(let o) = input else { throw MigrationError.notAProfile }
        if o["transactions"]?.arrayValue == nil && o["cards"]?.arrayValue == nil && o["accounts"]?.arrayValue == nil { throw MigrationError.empty }
        guard let ver = o["version"]?.doubleValue, ver >= 3 else { throw MigrationError.legacyFormat }

        func objs(_ v: JSONValue?) -> [[String: JSONValue]] { (v?.arrayValue ?? []).compactMap { $0.objectValue } }
        func truthy(_ v: JSONValue?) -> Bool { JS.truthy(v) }

        // --- ajustes ---
        var st: [String: JSONValue] = ["currency": .string("USD"), "fx": .number(3.5), "cushion": .number(300), "variable_weekly": .number(230)]
        if let so = o["settings"]?.objectValue { for (k, v) in so { st[k] = v } }
        st["demo_today"] = nil

        var accounts = objs(o["accounts"])
        if accounts.isEmpty {
            let c = o["settings"]?["currency"]?.stringValue ?? ""
            accounts = [["id": .string("bank"), "name": .string("Cuenta principal"), "type": .string("checking"),
                         "cur": .string(Currencies.table[c] != nil ? c : "USD"), "balance": .number(0)]]
        }
        var transactions = objs(o["transactions"])
        var cards = objs(o["cards"])
        var subs = objs(o["subs"])
        var savings = objs(o["savings"])
        var planned = objs(o["planned"])
        var jobs = objs(o["jobs"]).filter { truthy($0["id"]) }

        // --- sello de análisis (anRead / anStamp) ---
        if let m = anRead(o) {
            st["an"] = .object(["id": .string(m.id), "at": .string(m.at)])
            func stamp(_ l: inout [[String: JSONValue]]) { for i in l.indices { l[i]["an"] = .string(m.id) } }
            stamp(&transactions); stamp(&accounts); stamp(&cards); stamp(&subs); stamp(&savings); stamp(&jobs)
        }

        // --- monedas ---
        st["customCur"] = .string(regCustom(st["customCur"]))
        let custom = st["customCur"]?.stringValue ?? ""
        func known(_ c: String) -> Bool { Currencies.table[c] != nil || (!custom.isEmpty && c == custom) }
        let hasPEN = (accounts + cards + subs + savings).contains { $0["cur"] == JSONValue.string("PEN") }
        var cur1 = st["currency"]?.stringValue ?? ""
        if !known(cur1) { cur1 = "USD"; st["currency"] = .string("USD") }
        var cur2: String
        if st["currency2"] == nil { cur2 = (hasPEN && cur1 != "PEN") ? "PEN" : "" } else { cur2 = st["currency2"]?.stringValue ?? "\u{0}" }
        if !known(cur2) || cur2 == cur1 { cur2 = "" }
        st["currency2"] = .string(cur2)
        func okC(_ v: JSONValue?) -> JSONValue {
            if let c = v?.stringValue, c == cur1 || (!cur2.isEmpty && c == cur2) { return .string(c) }
            return .string(cur1)
        }

        for i in accounts.indices {
            if !truthy(accounts[i]["id"]) { accounts[i]["id"] = .string("a\(i)") }
            accounts[i]["cur"] = okC(accounts[i]["cur"])
            if !truthy(accounts[i]["type"]) { accounts[i]["type"] = .string("checking") }
        }
        for i in cards.indices {
            if !truthy(cards[i]["id"]) { cards[i]["id"] = .string("c\(i)") }
            if !truthy(cards[i]["kind"]) { cards[i]["kind"] = .string("card") }
            cards[i]["cur"] = okC(cards[i]["cur"])
        }
        for i in subs.indices {
            if !truthy(subs[i]["id"]) { subs[i]["id"] = .string("s\(i)") }
            subs[i]["cur"] = okC(subs[i]["cur"])
        }
        for i in savings.indices {
            if !truthy(savings[i]["id"]) { savings[i]["id"] = .string("v\(i)") }
            savings[i]["cur"] = okC(savings[i]["cur"])
        }
        for i in planned.indices {
            if !truthy(planned[i]["id"]) { planned[i]["id"] = .string("p\(i)") }
            if planned[i]["on"] == nil || planned[i]["on"] == JSONValue.null { planned[i]["on"] = .bool(true) }
        }

        // --- ingresos y gastos previstos (la web los reconstruye campo por campo) ---
        let firstAcc: JSONValue = accounts[0]["id"] ?? .null
        func put(_ out: inout [String: JSONValue], _ e: [String: JSONValue], _ key: String) { if let v = e[key] { out[key] = v } }
        func orUndefined(_ v: JSONValue?) -> JSONValue? { truthy(v) ? v : nil }
        var expectedIncome: [JSONValue] = []
        for (i, e) in objs(o["expected_income"]).enumerated() {
            var r: [String: JSONValue] = [:]
            r["id"] = truthy(e["id"]) ? e["id"] : JSONValue.string("i\(i)")
            put(&r, e, "name"); put(&r, e, "amount")
            r["acc"] = truthy(e["acc"]) ? e["acc"] : firstAcc
            if let d = truthy(e["date"]) ? e["date"] : e["next"] { r["date"] = d }
            if let rep = e["repeat"], !rep.isNull { r["repeat"] = rep } else { r["repeat"] = truthy(e["every_days"]) ? e["every_days"] : JSONValue.number(0) }
            r["until"] = truthy(e["until"]) ? e["until"] : JSONValue.string("")
            put(&r, e, "snooze")
            if let j = orUndefined(e["job"]) { r["job"] = j }
            if let j = orUndefined(e["jstart"]) { r["jstart"] = j }
            put(&r, e, "mod")
            expectedIncome.append(.object(r))
        }
        var expectedExpense: [JSONValue] = []
        for (i, e) in objs(o["expected_expense"]).enumerated() {
            var r: [String: JSONValue] = [:]
            r["id"] = truthy(e["id"]) ? e["id"] : JSONValue.string("x\(i)")
            put(&r, e, "name")
            r["amount"] = .number(abs(Engine.num(truthy(e["amount"]) ? e["amount"] : nil)))
            r["acc"] = truthy(e["acc"]) ? e["acc"] : firstAcc
            put(&r, e, "date")
            if let rep = e["repeat"], !rep.isNull { r["repeat"] = rep } else { r["repeat"] = .number(0) }
            r["until"] = truthy(e["until"]) ? e["until"] : JSONValue.string("")
            r["cat"] = truthy(e["cat"]) ? e["cat"] : JSONValue.string("Otros")
            put(&r, e, "snooze")
            if let c = orUndefined(e["card"]) { r["card"] = c }
            put(&r, e, "mod")
            expectedExpense.append(.object(r))
        }

        // --- categorías ---
        var cats: [JSONValue] = []
        let rawCats = o["cats"]?.arrayValue ?? []
        if rawCats.isEmpty {
            for c in Currencies.defaultCategories { cats.append(.object(["name": .string(c.name), "color": .string(c.color), "icon": .string("")])) }
        } else {
            for c in rawCats {
                cats.append(.object(["name": .string(c["name"].map { JS.string($0) } ?? "undefined"),
                                     "color": truthy(c["color"]) ? c["color"]! : .string("#C9CBD1"),
                                     "icon": truthy(c["icon"]) ? c["icon"]! : .string("")]))
            }
        }
        if !cats.contains(where: { $0["name"] == JSONValue.string("Otros") }) {
            cats.append(.object(["name": .string("Otros"), "color": .string("#C9CBD1"), "icon": .string("")]))
        }

        // --- movimientos ---
        let cardIds = cards.compactMap { $0["id"] }
        for i in transactions.indices {
            if !truthy(transactions[i]["id"]) { transactions[i]["id"] = .number(Double(1000 + i)) }
            if Engine.num(transactions[i]["amount"]) > 0, transactions[i]["category"] == JSONValue.string("Ingreso"),
               let acc = transactions[i]["acc"], cardIds.contains(acc) {
                transactions[i]["category"] = .string("Pago de crédito")
            }
        }

        // --- topes de monto ---
        let clampKeys = ["balance", "limit", "payment", "goal", "monthly", "amount", "income", "expense"]
        func clampItem(_ e: inout [String: JSONValue]) {
            for k in clampKeys { if case .number(let n)? = e[k] { e[k] = .number(clampAmt(n)) } }
            if case .array(var log)? = e["log"] {
                for i in log.indices { if case .number(let n)? = log[i]["amount"] { log[i]["amount"] = .number(clampAmt(n)) } }
                e["log"] = .array(log)
            }
        }
        func clampList(_ l: inout [[String: JSONValue]]) { for i in l.indices { clampItem(&l[i]) } }
        clampList(&accounts); clampList(&cards); clampList(&subs); clampList(&savings); clampList(&transactions); clampList(&planned)
        func clampJSONList(_ l: [JSONValue]) -> [JSONValue] {
            l.map { v in
                guard case .object(var e) = v else { return v }
                clampItem(&e)
                return .object(e)
            }
        }
        expectedIncome = clampJSONList(expectedIncome)
        expectedExpense = clampJSONList(expectedExpense)
        let history = clampJSONList(o["history"]?.arrayValue ?? [])

        func clampBudget(_ v: JSONValue?) -> [String: JSONValue] {
            guard var b = v?.objectValue else { return [:] }
            for (k, x) in b { if case .number(let n) = x { b[k] = .number(clampAmt(n)) } }
            return b
        }
        let budget = clampBudget(o["budget"])
        var budgetSets: [JSONValue] = []
        for b in (o["budgetSets"]?.arrayValue ?? []) {
            guard let id = b["id"], truthy(id), let from = b["from"]?.stringValue, let to = b["to"]?.stringValue, isDay(from), isDay(to) else { continue }
            var r: [String: JSONValue] = ["id": .string(JS.string(id)), "from": .string(from), "to": .string(to)]
            let name = truthy(b["name"]) ? JS.string(b["name"]!) : "Set"
            r["name"] = .string(slice16(name, 40))
            r["cur"] = .string(b["cur"]?.stringValue ?? "")
            r["budget"] = .object(clampBudget(b["budget"]))
            if let m = b["mod"] { r["mod"] = m }
            budgetSets.append(.object(r))
        }
        for k in ["cushion", "variable_weekly"] { if case .number(let n)? = st[k] { st[k] = .number(clampAmt(n)) } }

        // --- lápidas, marcas de edición, trabajos ---
        var tomb: [JSONValue] = []
        for x in o["tomb"]?.arrayValue ?? [] {
            guard truthy(x["c"]), let id = x["id"], !id.isNull, let t = x["t"], Engine.jsNumber(t) > 0 else { continue }
            tomb.append(.object(["c": .string(JS.string(x["c"]!)), "id": .string(JS.string(id)), "t": .number(Engine.jsNumber(t))]))
        }
        var fmod: JSONValue = .object([:])
        if case .object? = o["fmod"] { fmod = o["fmod"]! }
        var ovr: JSONValue = .object([:])
        if case .object? = o["ovr"] { ovr = o["ovr"]! }

        var halfSnaps: [String: JSONValue] = [:]
        func snap(_ letter: JSONValue, _ score: JSONValue?) -> JSONValue {
            let n = score.map { Engine.jsNumber($0) } ?? .nan
            return .object(["letter": .string(JS.string(letter)), "score": .number((n.isNaN || n == 0) ? 0 : n)])
        }
        for (k, v) in o["halfSnaps"]?.objectValue ?? [:] where truthy(v["letter"]) { halfSnaps[k] = snap(v["letter"]!, v["score"]) }
        if let hs = o["halfSnap"], truthy(hs["mk"]), truthy(hs["letter"]), let mk = hs["mk"] {
            let key = JS.string(mk)
            if !truthy(halfSnaps[key]) { halfSnaps[key] = snap(hs["letter"]!, hs["score"]) }
        }

        var out: [String: JSONValue] = [
            "version": .number(3),
            "demo": .bool(o["demo"] == JSONValue.bool(true)),
            "settings": .object(st),
            "accounts": .array(accounts.map { .object($0) }),
            "transactions": .array(transactions.map { .object($0) }),
            "history": .array(history),
            "cards": .array(cards.map { .object($0) }),
            "recurring": .array(o["recurring"]?.arrayValue ?? []),
            "subs": .array(subs.map { .object($0) }),
            "savings": .array(savings.map { .object($0) }),
            "budget": .object(budget),
            "budgetSets": .array(budgetSets),
            "expected_income": .array(expectedIncome),
            "planned": .array(planned.map { .object($0) }),
            "tomb": .array(tomb),
            "fmod": fmod,
            "jobs": .array(jobs.map { .object($0) }),
            "ovr": ovr,
            "firstHalf": .string(o["firstHalf"]?.stringValue ?? ""),
            "halfSnaps": .object(halfSnaps),
            "expected_expense": .array(expectedExpense),
            "cats": .array(cats),
        ]
        if let m = anRead(o) { out["analysis"] = .object(["v": .number(1), "id": .string(m.id), "at": .string(m.at)]) }
        return safe(.object(out))
    }

    // MARK: utilidades

    static let maxAmount = 999_999_999.0
    static func clampAmt(_ n: Double) -> Double { n.isFinite ? max(-maxAmount, min(maxAmount, n)) : 0 }

    static func isDay(_ s: String) -> Bool {
        let u = Array(s.utf8)
        guard u.count == 10, u[4] == 45, u[7] == 45 else { return false }
        for (i, c) in u.enumerated() where i != 4 && i != 7 { if c < 48 || c > 57 { return false } }
        return true
    }

    static func isHex(_ s: String, count: Int) -> Bool {
        let u = Array(s.utf8)
        return u.count == count && u.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }

    /// El sello de análisis (id de 8 hex y fecha), buscado en los lugares donde la web lo ha guardado.
    static func anRead(_ o: [String: JSONValue]) -> (id: String, at: String)? {
        var id = "", at = ""
        func take(_ m: JSONValue?) {
            guard let m = m, m.objectValue != nil else { return }
            let mid = m["id"].map { JS.string($0) } ?? ""
            let mat = m["at"].map { JS.string($0) } ?? ""
            if id.isEmpty && isHex(mid, count: 8) { id = mid }
            if at.isEmpty && isDay(mat) { at = mat }
        }
        take(o["analysis"]); take(o["meta"]?["analysis"]); take(o["settings"]?["an"])
        for k in ["transactions", "accounts", "cards", "subs", "savings", "jobs"] where id.isEmpty {
            for item in o[k]?.arrayValue ?? [] {
                guard let a = item["an"], isHex(JS.string(a), count: 8) else { continue }
                id = JS.string(a)
                break
            }
        }
        if id.isEmpty && at.isEmpty { return nil }
        if id.isEmpty {
            var h: UInt32 = 5381
            for u in at.utf16 { h = (h &* 33) ^ UInt32(u) }
            let hex = String(h, radix: 16)
            id = String(("00000000" + hex).suffix(8))
        }
        return (id, at)
    }

    /// Código de moneda propia: hasta 3 letras, números o símbolos de moneda, que no choque con las incluidas.
    static func regCustom(_ v: JSONValue?) -> String {
        guard truthy(v), let v = v else { return "" }
        let raw = JS.string(v).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let noSpace = raw.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        let three = noSpace.prefix(3)
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: three)
        let s = String(scalars)
        let symbols: Set<Unicode.Scalar> = ["$", "€", "£", "¥", "₿", "₽", "₩", "₹", "₫", "₺", "₴"]
        guard !s.isEmpty, three.allSatisfy({ CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || symbols.contains($0) }),
              Currencies.table[s] == nil else { return "" }
        return s
    }
    private static func truthy(_ v: JSONValue?) -> Bool { JS.truthy(v) }

    // MARK: safeProfile

    static let idKeys: Set<String> = ["id", "acc", "card", "job", "pair", "from", "to", "srcId"]
    static let labelKeys: Set<String> = ["name", "category", "cat", "nick", "first", "bank", "brand", "label", "letter"]

    static func safeId(_ s: String) -> String {
        let ok = s.unicodeScalars.filter { c in
            (c.value >= 48 && c.value <= 57) || (c.value >= 65 && c.value <= 90) || (c.value >= 97 && c.value <= 122) || "_.:@+-".unicodeScalars.contains(c)
        }
        var v = String.UnicodeScalarView(); v.append(contentsOf: ok.prefix(80))
        return String(v)
    }

    /// `slice(0, n)` de JS: cuenta unidades UTF-16.
    static func slice16(_ s: String, _ limit: Int) -> String {
        if s.utf16.count <= limit { return s }
        var out = String.UnicodeScalarView(), n = 0
        for u in s.unicodeScalars { n += u.value > 0xFFFF ? 2 : 1; if n > limit { break }; out.append(u) }
        return String(out)
    }

    static func safeLabel(_ s: String) -> String {
        let kept = String(s.unicodeScalars.filter { !"<>\"`".unicodeScalars.contains($0) }.map { Character($0) })
        return slice16(kept, 120)
    }

    static func isSafeColor(_ s: String) -> Bool {
        let u = Array(s.utf8)
        guard u.count >= 4, u.count <= 9, u[0] == 35 else { return false }
        return u.dropFirst().allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 70) || ($0 >= 97 && $0 <= 102) }
    }

    static func isSafeIcon(_ s: String) -> Bool {
        let u = Array(s.utf8)
        return u.count <= 40 && u.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 122) || $0 == 45 }
    }

    static func isPrimitive(_ v: JSONValue) -> Bool {
        switch v { case .array, .object, .null: return false; default: return true }
    }

    static func safeKeys(_ o: [String: JSONValue], _ f: (String) -> String) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for k in o.keys.sorted() where k != "__proto__" && k != "constructor" && k != "prototype" { out[f(k)] = o[k] }
        return out
    }

    /// Reduce a su forma válida los campos que la app usa dentro de atributos o estilos (identificadores, etiquetas, colores, iconos, últimos 4 dígitos).
    static func safe(_ v: JSONValue) -> JSONValue {
        switch v {
        case .array(let a): return .array(a.map { safe($0) })
        case .object(let o):
            var out: [String: JSONValue] = [:]
            for (k, x) in o {
                if k == "__proto__" || k == "constructor" || k == "prototype" { continue }
                if idKeys.contains(k), case .string(let s) = x { out[k] = .string(safeId(s)); continue }
                if labelKeys.contains(k), case .string(let s) = x { out[k] = .string(safeLabel(s)); continue }
                if k == "budget", case .object(let b) = x { out[k] = .object(safeKeys(b, safeLabel)); continue }
                if k == "ovr" || k == "fmod", case .object(let b) = x { out[k] = safe(.object(safeKeys(b, safeId))); continue }
                let lower = k.lowercased()
                if lower.hasSuffix("color") || lower.hasSuffix("colour"), isPrimitive(x) {
                    out[k] = isSafeColor(JS.string(x)) ? x : .string("#8E8E93"); continue
                }
                if k == "icon", isPrimitive(x) { out[k] = isSafeIcon(JS.string(x)) ? x : .string(""); continue }
                if k == "last4", isPrimitive(x) {
                    let digits = JS.string(x).unicodeScalars.filter { $0.value >= 48 && $0.value <= 57 }.prefix(4)
                    var u = String.UnicodeScalarView(); u.append(contentsOf: digits)
                    out[k] = .string(String(u)); continue
                }
                out[k] = safe(x)
            }
            return .object(out)
        default: return v
        }
    }
}
