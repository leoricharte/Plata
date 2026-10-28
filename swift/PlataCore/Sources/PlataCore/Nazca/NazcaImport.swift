import Foundation

/// La revisión de una importación (`ui.imp`, `impBuild` e `impGoOne` de la web), sin pantalla.
/// Se crea con un archivo ya leído, se ajusta (cuenta, invertir signos, monedas, saldo, qué movimientos entran) y al final se aplica al perfil.
/// Todo cambio de ajuste llama a `build(_:)` para recalcular las filas.
public struct ImportReview {
    public enum Why: String, Sendable { case none = "", exact, near, cur, future, fxc, fxs }
    public enum BalanceMode: String, Sendable { case adjust, keep, stmt }
    public enum FxMode: String, Sendable { case skip, convert, split }

    public struct Orig: Equatable, Sendable { public var amount: Double; public var cur: String }

    public struct Row: Identifiable, Equatable, Sendable {
        public var i: Int
        public var id: Int { i }
        public var line: Int
        public var date: String
        public var desc: String
        public var amount: Double
        public var cur: String
        public var balance: Double?
        public var orig: Orig?
        public var fp = ""
        public var why: Why = .none
        public var cat = ""
        /// Va a la cuenta aparte de la otra moneda.
        public var side = false
        /// La moneda en que se muestra el monto.
        public var dc = ""
        public var on = false
    }

    public struct Statement: Equatable, Sendable { public var balance: Double; public var date: String }

    public static let maxFiles = 3
    public static let perPage = 20

    public var name: String
    public var guess: String
    public let analysis: Nazca.Analysis
    public private(set) var extracted: [Nazca.Item]
    public private(set) var unreadable: Int
    public private(set) var colOverrides: [String: Int] = [:]
    public var account: String
    public var flip: Bool?
    public var balanceMode: BalanceMode?
    public var selection: [Int: Bool] = [:]
    public var catPick: [Int: String] = [:]
    public var fxMode: FxMode?
    public var fxRate: Double = 0
    /// Cuenta que recibe los movimientos de la otra moneda; vacío = crear una nueva.
    public var fxAccount = ""
    public private(set) var rows: [Row] = []
    public private(set) var foreignCurrency = ""
    private var primary = "", secondary = ""

    /// Lee las filas con las columnas detectadas y escoge la cuenta: la indicada, si no una cuenta de la moneda del archivo, si no la primera.
    public init?(name: String, analysis: Nazca.Analysis, engine: Engine, preferredAccount: String? = nil, guess: String = "") {
        let ex = Nazca.extract(analysis)
        if ex.items.isEmpty { return nil }
        self.name = String(name.prefix(80))
        self.guess = String(guess.prefix(40))
        self.analysis = analysis
        self.extracted = ex.items
        self.unreadable = ex.skipped.unreadable
        let fileCur = Self.topCurrency(ex.items.map(\.cur), excluding: "")
        let accounts = engine.allAccounts, cards = engine.allCards
        let all = accounts + cards
        let pick = all.first { Engine.identifier($0["id"]) == preferredAccount }
            ?? (fileCur.isEmpty ? nil : accounts.first { Engine.str($0["cur"]) == fileCur })
            ?? accounts.first
        guard let pick else { return nil }
        self.account = Engine.identifier(pick["id"])
        build(engine)
    }

    // MARK: ajustes

    /// Cambia qué columna es cada cosa y vuelve a leer el archivo (reinicia selección, categorías elegidas, signos y saldo).
    public mutating func setColumn(_ role: String, _ index: Int, engine: Engine) {
        colOverrides[role] = index
        let ex = Nazca.extract(analysis, Nazca.Options(cols: colOverrides))
        extracted = ex.items
        unreadable = ex.skipped.unreadable
        selection = [:]; catPick = [:]; flip = nil; balanceMode = nil
        build(engine)
    }

    /// Las columnas en uso: las detectadas más lo que la persona cambió.
    public var columns: Nazca.Columns {
        var c = analysis.cols
        for (k, v) in colOverrides { c[k] = v }
        return c
    }

    public mutating func chooseAccount(_ id: String, engine: Engine) {
        account = id; flip = nil; balanceMode = nil; selection = [:]; fxMode = nil; fxRate = 0; fxAccount = ""
        build(engine)
    }

    public mutating func setFlip(_ on: Bool, engine: Engine) { flip = on; selection = [:]; catPick = [:]; build(engine) }
    public mutating func setFxMode(_ m: FxMode, engine: Engine) { fxMode = m; selection = [:]; build(engine) }
    public mutating func setFxRate(_ r: Double, engine: Engine) { if r > 0 { fxRate = r; selection = [:]; build(engine) } }
    public mutating func setFxAccount(_ id: String, engine: Engine) { fxAccount = id; selection = [:]; build(engine) }

    public mutating func setCategory(_ i: Int, _ cat: String) {
        catPick[i] = cat
        if let k = rows.firstIndex(where: { $0.i == i }) { rows[k].cat = cat }
    }

    /// Marca o desmarca un movimiento. Los de fecha futura o de otra moneda no se pueden marcar; devuelve por qué no.
    @discardableResult
    public mutating func toggle(_ i: Int) -> Why? {
        guard let k = rows.firstIndex(where: { $0.i == i }) else { return nil }
        if rows[k].why == .future || rows[k].why == .cur { return rows[k].why }
        rows[k].on.toggle(); selection[i] = rows[k].on
        return nil
    }

    public mutating func setOn(_ indices: [Int], _ want: Bool) {
        for i in indices {
            guard let k = rows.firstIndex(where: { $0.i == i }), rows[k].why != .future, rows[k].why != .cur else { continue }
            rows[k].on = want; selection[i] = want
        }
    }

    // MARK: cálculo

    /// La moneda que más aparece (la primera, si empatan), sin contar la excluida ni las filas sin moneda.
    static func topCurrency(_ curs: [String], excluding: String) -> String {
        var counts: [String: Int] = [:], order: [String] = []
        for c in curs where !c.isEmpty && c != excluding { if counts[c] == nil { order.append(c) }; counts[c, default: 0] += 1 }
        var best = "", n = 0
        for c in order where counts[c]! > n { best = c; n = counts[c]! }
        return best
    }

    static func conv(_ n: Double, _ from: String, _ to: String, _ e: Engine) -> Double {
        if from == to { return n }
        let curP = e.primaryCurrency, curS = e.secondaryCurrency
        let active = curS.isEmpty ? [curP] : [curP, curS]
        if active.contains(from) && active.contains(to) {
            let inP = from == curP ? n : n / e.fx
            return to == curP ? inP : inP * e.fx
        }
        let rf = Currencies.table[from]?.rate ?? 1, rt = Currencies.table[to]?.rate ?? 1
        return n * rt / rf
    }

    /// ¿Se puede abrir una cuenta aparte en esa moneda? Solo si ya es una de las dos de Plata, o si hay lugar para la segunda.
    public static func splitAllowed(_ f: String, _ e: Engine) -> Bool { f == e.primaryCurrency || f == e.secondaryCurrency || e.secondaryCurrency.isEmpty }

    /// Cuentas (o tarjetas, si la importada es una tarjeta) en la moneda `f`, distintas de la importada.
    public func fxPool(_ e: Engine) -> [JSONValue] {
        guard let loc = ProfileEditor.locate(e.data, .string(account)) else { return [] }
        let pool = loc.col == "cards" ? e.allCards.filter { Engine.str($0["kind"]) == "card" } : e.allAccounts
        return pool.filter { Engine.str($0["cur"]) == foreignCurrency && Engine.identifier($0["id"]) != account }
    }

    static func known(_ e: Engine) -> [Nazca.Known] {
        e.allTransactions.map {
            Nazca.Known(acc: Engine.identifier($0["acc"]), date: Engine.str($0["date"]), amount: Engine.num($0["amount"]),
                        note: Engine.str($0["note"]), category: Engine.str($0["category"]), imp: Engine.str($0["imp"]))
        }
    }

    public mutating func build(_ e: Engine) {
        guard let loc = ProfileEditor.locate(e.data, .string(account)), let acc = e.data[loc.col]?.arrayValue?[loc.index] else { rows = []; return }
        let credit = loc.col == "cards", accCur = Engine.str(acc["cur"]), accId = Engine.identifier(acc["id"]), today = e.today.iso
        primary = e.primaryCurrency; secondary = e.secondaryCurrency
        if flip == nil { flip = credit && extracted.filter { $0.amount > 0 }.count * 2 > extracted.count }
        var items = extracted.map { it -> Nazca.Item in var x = it; if flip == true { x.amount = -x.amount }; return x }

        // monedas: la que más aparece y no es la de la cuenta
        let F = Self.topCurrency(extracted.map(\.cur), excluding: accCur)
        foreignCurrency = F
        if !F.isEmpty {
            if fxMode == nil { fxMode = (F == e.primaryCurrency || F == e.secondaryCurrency) ? .split : .skip }
            if fxMode == .split && !Self.splitAllowed(F, e) { fxMode = .skip }
            if !(fxRate > 0) { fxRate = Double(String(format: "%.4g", Self.conv(1, F, accCur, e))) ?? 1 }
            let pool = fxPool(e)
            if fxAccount.isEmpty || !pool.contains(where: { Engine.identifier($0["id"]) == fxAccount }) {
                let l4 = Engine.str(acc["last4"])
                let m = pool.first { !Engine.str($0["last4"]).isEmpty && Engine.str($0["last4"]) == l4 }
                fxAccount = m.map { Engine.identifier($0["id"]) } ?? ""
            }
        }
        let mode: FxMode = F.isEmpty ? .skip : (fxMode ?? .skip)
        var origs: [Int: Orig] = [:]
        if mode == .convert {
            for k in items.indices where items[k].cur == F {
                origs[k] = Orig(amount: items[k].amount, cur: F)
                items[k].amount = Engine.round2(items[k].amount * fxRate)
            }
        }
        let known = Self.known(e)
        let dups = Nazca.markDuplicates(items, existing: known, acc: accId)
        let guesser = Nazca.categorizer(e.categoryNames, history: known)
        var dupF: [Int: Nazca.Duplicate] = [:]
        if mode == .split && !fxAccount.isEmpty {
            let idx = items.indices.filter { items[$0].cur == F }
            let d2 = Nazca.markDuplicates(idx.map { items[$0] }, existing: known, acc: fxAccount)
            for (k, i) in idx.enumerated() { dupF[i] = d2[k].dup }
        }
        let names = Set(e.categoryNames)
        rows = items.enumerated().map { i, it in
            let fx = !F.isEmpty && it.cur == F && mode != .skip
            let foreign = !it.cur.isEmpty && it.cur != accCur
            let why: Why
            if it.date > today { why = .future }
            else if foreign && !fx { why = .cur }
            else if fx {
                let d = mode == .split ? (dupF[i] ?? .none) : dups[i].dup
                why = d != .none ? Why(rawValue: d.rawValue)! : (mode == .split ? .fxs : .fxc)
            } else { why = Why(rawValue: dups[i].dup.rawValue)! }
            let cat: String
            if it.amount > 0 { cat = credit ? Engine.payCategory : "Ingreso" }
            else if let c = catPick[i], names.contains(c) { cat = c }
            else { cat = guesser(it.desc, it.amount) }
            let hard = why == .future || why == .cur, soft = why == .fxc || why == .fxs
            let side = fx && mode == .split
            var r = Row(i: i, line: it.line, date: it.date, desc: it.desc, amount: it.amount, cur: it.cur, balance: it.balance, orig: origs[i])
            r.fp = dups[i].fp; r.why = why; r.cat = cat; r.side = side; r.dc = side ? F : accCur
            r.on = hard ? false : (selection[i] ?? (soft || why == .none))
            return r
        }
        let st = statement(credit: credit)
        if balanceMode == nil || (balanceMode == .stmt && st == nil) {
            let last = e.allTransactions.filter { Engine.identifier($0["acc"]) == accId }.map { Engine.str($0["date"]) }.max() ?? ""
            balanceMode = (st != nil && st!.date >= last) ? .stmt : .adjust
        }
    }

    // MARK: lectura de lo calculado

    /// El saldo que trae el archivo, si lo trae (el de la fila más reciente).
    public func statement(credit: Bool) -> Statement? {
        if credit { return nil }
        let rs = rows.filter { $0.balance != nil }
        guard let first = rs.first, let last = rs.last else { return nil }
        let newestFirst = first.date > last.date
        let maxD = rs.map(\.date).max()!
        let same = rs.filter { $0.date == maxD }
        guard let r = newestFirst ? same.first : same.last, let b = r.balance else { return nil }
        return Statement(balance: b, date: r.date)
    }

    public func statement(_ e: Engine) -> Statement? {
        statement(credit: ProfileEditor.isCredit(e.data, accountId: .string(account)))
    }

    public var enabled: [Row] { rows.filter(\.on) }

    /// Suma de lo que entra a la cuenta principal y el saldo (o deuda) resultante.
    public func projected(_ e: Engine) -> (net: Double, before: Double, after: Double, cur: String, credit: Bool)? {
        guard let loc = ProfileEditor.locate(e.data, .string(account)), let acc = e.data[loc.col]?.arrayValue?[loc.index] else { return nil }
        let credit = loc.col == "cards", bal = Engine.num(acc["balance"])
        let net = Engine.round2(enabled.filter { !$0.side }.reduce(0) { $0 + $1.amount })
        return (net, bal, Engine.round2(credit ? bal - net : bal + net), Engine.str(acc["cur"]), credit)
    }

    public func count(_ why: Why) -> Int { rows.filter { $0.why == why }.count }

    // MARK: aplicar y deshacer

    public struct Applied: Equatable, Sendable {
        public struct Part: Equatable, Sendable {
            public var ids: [Double]
            public var acc: String
            public var before: Double
            public var created: String?
            public var cur2: String?
        }
        public struct Done: Equatable, Sendable {
            public var n: Int
            public var account: String
            public var balance: Double
            public var cur: String
            public var credit: Bool
            public var created: Bool
        }
        public var parts: [Part]
        public var dones: [Done]
        public var total: Int { dones.reduce(0) { $0 + $1.n } }
    }

    static func l4(_ o: JSONValue) -> String {
        let s = Engine.str(o["last4"])
        return s.isEmpty ? "" : " ··" + s
    }

    /// Importa los movimientos marcados (`impGoOne`). `newAccountId` se usa si hay que abrir una cuenta aparte para otra moneda.
    public func apply(to p: inout JSONValue, now: Double, newAccountId: String) -> Applied? {
        let on = rows.filter(\.on)
        guard !on.isEmpty, let loc0 = ProfileEditor.locate(p, .string(account)), let acc0 = p[loc0.col]?.arrayValue?[loc0.index] else { return nil }
        let accId = Engine.identifier(acc0["id"]), credit = loc0.col == "cards"
        let st = statement(credit: credit)
        let main = on.filter { !$0.side }.sorted { $0.date != $1.date ? $0.date < $1.date : $0.i < $1.i }
        let side = on.filter(\.side).sorted { $0.date != $1.date ? $0.date < $1.date : $0.i < $1.i }
        var parts: [Applied.Part] = [], dones: [Applied.Done] = []
        let mode = balanceMode ?? .adjust

        func push(_ r: Row, acc id: JSONValue, note: String) -> Double {
            let amt = Engine.round2(Migration.clampAmt(r.amount))
            let tid = ProfileEditor.nextTxId(p, now: now)
            var list = p["transactions"]?.arrayValue ?? []
            list.append(.object(["id": .number(tid), "date": .string(r.date), "amount": .number(amt), "category": .string(r.cat), "note": .string(note), "acc": id, "imp": .string(r.fp)]))
            p["transactions"] = .array(list)
            return tid
        }
        func bal(_ id: String) -> Double {
            guard let l = ProfileEditor.locate(p, .string(id)) else { return 0 }
            return Engine.num(p[l.col]?.arrayValue?[l.index]["balance"])
        }
        func setBal(_ id: String, _ v: Double) {
            guard let l = ProfileEditor.locate(p, .string(id)), case .array(var list)? = p[l.col] else { return }
            list[l.index]["balance"] = .number(v)
            p[l.col] = .array(list)
        }
        func summary(_ id: String, n: Int, created: Bool) -> Applied.Done {
            let l = ProfileEditor.locate(p, .string(id))!
            let o = p[l.col]!.arrayValue![l.index]
            return Applied.Done(n: n, account: Engine.str(o["name"]) + Self.l4(o), balance: Engine.num(o["balance"]), cur: Engine.str(o["cur"]), credit: l.col == "cards", created: created)
        }

        if !main.isEmpty {
            let before = bal(accId)
            var ids: [Double] = []
            for r in main {
                var note = r.desc.isEmpty ? r.cat : r.desc
                if let o = r.orig { note += " (" + Money.exact(abs(o.amount), o.cur) + ")" }
                let tid = push(r, acc: acc0["id"] ?? .string(accId), note: note)
                ids.append(tid)
                if mode == .adjust { ProfileEditor.applyTo(&p, acc0["id"], Engine.round2(Migration.clampAmt(r.amount))) }
            }
            if mode == .stmt, let st { setBal(accId, Engine.round2(st.balance)) }
            parts.append(.init(ids: ids, acc: accId, before: before, created: nil, cur2: nil))
            dones.append(summary(accId, n: ids.count, created: false))
        }
        if !side.isEmpty {
            let F = foreignCurrency
            var a2Id = fxAccount, created2: String?, cur2: String?
            if a2Id.isEmpty || ProfileEditor.locate(p, .string(a2Id)).flatMap({ Engine.identifier(p[$0.col]?.arrayValue?[$0.index]["id"]) == a2Id ? $0 : nil }) == nil {
                let base = Engine.str(acc0["name"]).replacingOccurrences(of: #"\s+(Soles|Pesos|Dólares)$"#, with: "", options: .regularExpression)
                let nm = base + " " + (F == "USD" ? "Dólares" : F)
                let l4 = Engine.str(acc0["last4"])
                let o: JSONValue = credit
                    ? .object(["id": .string(newAccountId), "kind": .string("card"), "name": .string(nm), "cur": .string(F), "limit": .number(0), "balance": .number(0),
                               "apr": acc0["apr"] ?? .number(0), "payment": .number(0), "due_day": acc0["due_day"] ?? .number(1), "color": .string(""), "icon": .string(""), "last4": .string(l4)])
                    : .object(["id": .string(newAccountId), "name": .string(nm), "type": .string("checking"), "cur": .string(F), "apy": .number(0), "balance": .number(0),
                               "color": .string(""), "icon": .string(""), "last4": .string(l4)])
                let col = credit ? "cards" : "accounts"
                var list = p[col]?.arrayValue ?? []
                list.append(o)
                p[col] = .array(list)
                a2Id = newAccountId; created2 = newAccountId
            }
            if F != primary && F != secondary && secondary.isEmpty {
                var s = p["settings"] ?? .object([:])
                s["currency2"] = .string(F)
                p["settings"] = s
                cur2 = F
            }
            let before2 = bal(a2Id)
            var ids2: [Double] = []
            let a2Json = ProfileEditor.locate(p, .string(a2Id)).flatMap { p[$0.col]?.arrayValue?[$0.index]["id"] } ?? .string(a2Id)
            for r in side {
                let tid = push(r, acc: a2Json, note: r.desc.isEmpty ? r.cat : r.desc)
                ids2.append(tid)
                if mode != .keep { ProfileEditor.applyTo(&p, a2Json, Engine.round2(Migration.clampAmt(r.amount))) }
            }
            parts.append(.init(ids: ids2, acc: a2Id, before: before2, created: created2, cur2: cur2))
            dones.append(summary(a2Id, n: ids2.count, created: created2 != nil))
        }
        return parts.isEmpty ? nil : Applied(parts: parts, dones: dones)
    }

    /// Deshace una importación (`impUndo`): quita los movimientos, devuelve el saldo y borra la cuenta o la segunda moneda que creó.
    public static func undo(_ a: Applied, in p: inout JSONValue) {
        for part in a.parts.reversed() {
            let ids = Set(part.ids)
            let kept = (p["transactions"]?.arrayValue ?? []).filter { t in
                if case .number(let n)? = t["id"] { return !ids.contains(n) }
                return true
            }
            p["transactions"] = .array(kept)
            if let l = ProfileEditor.locate(p, .string(part.acc)), case .array(var list)? = p[l.col], Engine.identifier(list[l.index]["id"]) == part.acc {
                list[l.index]["balance"] = .number(part.before)
                p[l.col] = .array(list)
            }
            if let c2 = part.cur2, Engine.str(p["settings"]?["currency2"]) == c2 {
                let others = ((p["accounts"]?.arrayValue ?? []) + (p["cards"]?.arrayValue ?? [])).contains {
                    Engine.str($0["cur"]) == c2 && Engine.identifier($0["id"]) != (part.created ?? "")
                }
                if !others { var s = p["settings"] ?? .object([:]); s["currency2"] = .string(""); p["settings"] = s }
            }
            if let created = part.created, !(p["transactions"]?.arrayValue ?? []).contains(where: { Engine.identifier($0["acc"]) == created }) {
                for col in ["accounts", "cards"] {
                    p[col] = .array((p[col]?.arrayValue ?? []).filter { Engine.identifier($0["id"]) != created })
                }
            }
        }
    }
}
