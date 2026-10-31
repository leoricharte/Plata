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

    /// Lo que se sabe de un estado de cuenta leído por el lector de un banco (PDF, Excel o CSV propio); un CSV genérico no lo tiene.
    public struct Source: Equatable, Sendable {
        public var bank: String?
        public var label: String
        public var card: Bool
        public var cardInfo: Nazca.StatementResult.CardInfo
        public var check: Nazca.StatementResult.Check?
        /// Un resultado de comprobación por cada archivo unido (en el orden de `names`).
        public var checks: [Nazca.StatementResult.Check?]
        public var period: Nazca.StatementResult.Period?
        /// El saldo (o la deuda) con que cierra el estado.
        public var stmtEnd: Statement?
        /// La cuenta que se crearía.
        public var newAcc: JSONValue
        /// La cuenta que se sugiere para fusionar, o la que eligió la persona.
        public var mergeId: String?
    }

    public static let maxFiles = 3
    public static let perPage = 20
    /// El id provisional de la cuenta que aún no existe: se crea al importar.
    public static let newId = "__new"

    public var name: String
    public var guess: String
    /// Leído de un PDF de un banco que Nazca no conoce (lectura genérica): sin sello de verificado ni columnas que ajustar.
    public var gen = false
    /// Una captura (sin huella de importación): los repetidos se buscan también entre lo ya importado.
    public var loose = false
    public internal(set) var names: [String]
    /// Filas repetidas entre archivos unidos que se omitieron.
    public internal(set) var mdup = 0
    /// Filas sin leer por archivo (mismo orden que `names`), solo cuando se unieron varios.
    public internal(set) var unr: [Int]?
    public internal(set) var source: Source?
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
        self.names = [String(name.prefix(80))]
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

    /// Una revisión a partir de un estado de cuenta ya leído por el lector de un banco (`impFromPdf` de la web): sugiere fusionar con una cuenta de ese banco o crea una nueva.
    public init?(name: String, statement r: Nazca.StatementResult, engine e: Engine) {
        if r.items.isEmpty { return nil }
        let own = r.bank.map { Nazca.bankShort($0) } ?? r.name, last4 = r.last4
        func bankIs(_ o: JSONValue) -> Bool {
            if own.isEmpty { return false }
            let nm = Engine.str(o["name"])
            if let b = r.bank, Nazca.bankKeys(ofName: nm)?.contains(b) == true { return true }
            return Engine.bankNorm(nm).contains(Engine.bankNorm(own))
        }
        let card = r.kind == "tarjeta"
        let pool = card ? e.allCards.filter { Engine.str($0["kind"]) == "card" } : e.allAccounts
        var hit = pool.first { bankIs($0) && !last4.isEmpty && Engine.str($0["last4"]) == last4 }
            ?? pool.first { bankIs($0) && Engine.str($0["cur"]) == r.cur && Engine.str($0["last4"]).isEmpty }
            // una captura no trae los últimos 4 dígitos: se sugiere la cuenta o tarjeta de esa institución y moneda aunque la persona sí los tenga anotados
            ?? (last4.isEmpty && r.bank == nil ? pool.first { bankIs($0) && (r.cur.isEmpty || Engine.str($0["cur"]) == r.cur) } : nil)
        // Constancia de Plin (aunque salga de BBVA, Interbank…): se sugiere la cuenta de Yape o Plin que más se use, si la persona la tiene; si no, la del banco.
        if !card && r.name == "Plin" {
            let txs = e.data["transactions"]?.arrayValue ?? []
            func used(_ o: JSONValue) -> Int { txs.filter { Engine.identifier($0["acc"]) == Engine.identifier(o["id"]) }.count }
            let w = pool.filter { Engine.str($0["cur"]) == r.cur && (Engine.str($0["name"]).lowercased().contains("yape") || Engine.str($0["name"]).lowercased().contains("plin")) }
            if let best = w.enumerated().max(by: { (used($0.element), -$0.offset) < (used($1.element), -$1.offset) })?.element { hit = best }
        }
        let cd = (card ? r.card : nil) ?? Nazca.StatementResult.CardInfo()
        let nueva: JSONValue
        if card {
            nueva = .object(["id": .string(Self.newId), "kind": .string("card"), "name": .string(own.isEmpty ? "Tarjeta" : own), "cur": .string(r.cur),
                             "limit": .number(cd.limit ?? 0), "balance": .number(0), "apr": .number(cd.apr ?? 20), "payment": .number(cd.minPayment ?? 0),
                             "due_day": .number(Double(cd.dueDay.map { max(1, min(31, $0)) } ?? 1)), "color": .string(""), "icon": .string(""), "last4": .string(last4)])
        } else {
            let apy = r.kind == "ahorro" && (r.apy ?? 0) > 0 && (r.apy ?? 0) < 100 ? Nazca.jsRound((r.apy ?? 0) * 100) / 100 : 0
            nueva = .object(["id": .string(Self.newId), "name": .string((r.bank == nil ? (own.isEmpty ? "Cuenta" : own) : Nazca.bankShort(r.bank)) + (r.cur == "USD" ? " Dólares" : r.cur == "CLP" ? " Pesos" : " Soles")),
                             "type": .string(r.kind == "ahorro" ? "savings" : "checking"), "cur": .string(r.cur), "apy": .number(apy), "balance": .number(0),
                             "color": .string(""), "icon": .string(""), "last4": .string(last4)])
        }
        self.name = String(name.prefix(80))
        self.names = [String(name.prefix(80))]
        self.guess = ""
        self.analysis = .blank
        self.extracted = r.items
        self.unreadable = r.unreadable
        let hitId = hit.map { Engine.identifier($0["id"]) }
        self.account = hitId ?? Self.newId
        let end = r.check?.end.map { Statement(balance: $0, date: r.period?.to ?? "") }
        self.source = Source(bank: r.bank, label: r.label, card: card, cardInfo: cd, check: r.check, checks: [r.check], period: r.period,
                             stmtEnd: end, newAcc: nueva, mergeId: hitId)
        build(e)
    }

    /// La cuenta que se está revisando (la nueva, si todavía no existe) y si es una tarjeta.
    func resolve(_ data: JSONValue) -> (acc: JSONValue, credit: Bool)? {
        if account == Self.newId { return source.map { ($0.newAcc, $0.card) } }
        guard let loc = ProfileEditor.locate(data, .string(account)), let a = data[loc.col]?.arrayValue?[loc.index] else { return nil }
        return (a, loc.col == "cards")
    }

    /// La cuenta que se usa al elegir «Fusionar»: la sugerida, la que ya eligió la persona o la primera de la misma moneda.
    public func mergeTarget(_ e: Engine) -> String? {
        guard let s = source else { return nil }
        let pool = s.card ? e.allCards.filter { Engine.str($0["kind"]) == "card" } : e.allAccounts
        if pool.isEmpty { return nil }
        if let m = s.mergeId { return m }
        let cur = Engine.str(s.newAcc["cur"])
        return Engine.identifier((pool.first { Engine.str($0["cur"]) == cur } ?? pool[0])["id"])
    }

    public var isStatement: Bool { source != nil }

    /// La moneda de la cuenta que se está revisando.
    public func accountCurrency(_ e: Engine) -> String { resolve(e.data).map { Engine.str($0.acc["cur"]) } ?? e.primaryCurrency }

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
        if source != nil && id != Self.newId { source!.mergeId = id }
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
        guard let cur = resolve(e.data) else { return [] }
        let pool = cur.credit ? e.allCards.filter { Engine.str($0["kind"]) == "card" } : e.allAccounts
        return pool.filter { Engine.str($0["cur"]) == foreignCurrency && Engine.identifier($0["id"]) != account }
    }

    static func known(_ e: Engine) -> [Nazca.Known] {
        e.allTransactions.map {
            Nazca.Known(acc: Engine.identifier($0["acc"]), date: Engine.str($0["date"]), amount: Engine.num($0["amount"]),
                        note: Engine.str($0["note"]), category: Engine.str($0["category"]), imp: Engine.str($0["imp"]))
        }
    }

    public mutating func build(_ e: Engine) {
        guard let cur0 = resolve(e.data) else { rows = []; return }
        let acc = cur0.acc, credit = cur0.credit, accCur = Engine.str(acc["cur"]), accId = Engine.identifier(acc["id"]), today = e.today.iso
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
        let dups = Nazca.markDuplicates(items, existing: known, acc: accId, includeImported: loose)
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

    // MARK: varios archivos

    static func joinKey(_ x: String) -> String { x.lowercased().split(whereSeparator: { " \t\n\r".contains($0) }).joined(separator: " ") }
    static func compact(_ t: String) -> String { String(t.lowercased().unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(Character.init)) }

    /// ¿Son dos estados del mismo banco y la misma cuenta (o dos CSV del mismo origen)? Se unen en una sola revisión (`impSame`).
    public func isSame(as b: ImportReview) -> Bool {
        if (source != nil) != (b.source != nil) { return false }
        if let x = source, let y = b.source {
            if x.card != y.card || Engine.str(x.newAcc["cur"]) != Engine.str(y.newAcc["cur"]) { return false }
            let l1 = Engine.str(x.newAcc["last4"]), l2 = Engine.str(y.newAcc["last4"])
            if !l1.isEmpty && !l2.isEmpty && l1 != l2 { return false }
            if x.bank != nil || y.bank != nil { return x.bank == y.bank }
            return !Self.compact(x.label).isEmpty && Self.compact(x.label) == Self.compact(y.label)
        }
        return !Self.compact(guess).isEmpty && Self.compact(guess) == Self.compact(b.guess)
    }

    static func aggCheck(_ list: [Nazca.StatementResult.Check?]) -> Nazca.StatementResult.Check? {
        let cs = list.compactMap { $0 }.filter { $0.ok != nil }
        if cs.isEmpty { return nil }
        let ok: Bool? = cs.count < list.count ? nil : cs.allSatisfy { $0.ok == true } ? true : cs.contains { $0.ok == false } ? false : nil
        return .init(ok: ok, end: nil, n: cs.count)
    }

    /// Une `a` a esta revisión (`impMerge`): suma sus movimientos (sin los que ya estaban), el periodo, el saldo más reciente y los datos de la tarjeta.
    public mutating func merge(_ a: ImportReview, engine: Engine) {
        func key(_ it: Nazca.Item) -> String { it.date + "|" + Self.joinKey(it.desc) + "|" + String(it.amount) }
        var have: [String: Int] = [:]
        for it in extracted { have[key(it), default: 0] += 1 }
        var add: [Nazca.Item] = []
        for it in a.extracted {
            let k = key(it)
            if have[k, default: 0] > 0 { have[k]! -= 1; mdup += 1 } else { add.append(it) }
        }
        unr = (unr ?? [unreadable]) + [a.unreadable]
        extracted += add
        unreadable += a.unreadable
        if var s = source, let o = a.source {
            if let p = o.period {
                s.period = s.period.map { .init(from: min(p.from, $0.from), to: max(p.to, $0.to)) } ?? p
            }
            if let e = o.stmtEnd, s.stmtEnd.map({ e.date >= $0.date }) ?? true {
                s.stmtEnd = e
                if o.card { s.cardInfo = Self.overlay(s.cardInfo, o.cardInfo) }
            }
            s.checks += o.checks.isEmpty ? [o.check] : o.checks
            s.check = Self.aggCheck(s.checks)
            source = s
        }
        names += a.names
        mdup += a.mdup
        selection = [:]; catPick = [:]; flip = nil; balanceMode = nil
        build(engine)
    }

    static func overlay(_ b: Nazca.StatementResult.CardInfo, _ a: Nazca.StatementResult.CardInfo) -> Nazca.StatementResult.CardInfo {
        var o = b
        if a.limit != nil { o.limit = a.limit }
        if a.apr != nil { o.apr = a.apr }
        if a.minPayment != nil { o.minPayment = a.minPayment }
        if a.dueDay != nil { o.dueDay = a.dueDay }
        if a.dueDate != nil { o.dueDate = a.dueDate }
        return o
    }

    // MARK: lectura de lo calculado

    /// El saldo que trae el archivo, si lo trae (el de la fila más reciente).
    public func statement(credit: Bool) -> Statement? {
        let end = source?.stmtEnd.flatMap { $0.date.isEmpty ? nil : $0 }
        if credit { return end }
        let rs = rows.filter { $0.balance != nil }
        guard let first = rs.first, let last = rs.last else { return end }
        let newestFirst = first.date > last.date
        let maxD = rs.map(\.date).max()!
        let same = rs.filter { $0.date == maxD }
        guard let r = newestFirst ? same.first : same.last, let b = r.balance else { return nil }
        return Statement(balance: b, date: r.date)
    }

    public func statement(_ e: Engine) -> Statement? {
        statement(credit: resolve(e.data)?.credit ?? false)
    }

    public var enabled: [Row] { rows.filter(\.on) }

    /// Suma de lo que entra a la cuenta principal y el saldo (o deuda) resultante.
    public func projected(_ e: Engine) -> (net: Double, before: Double, after: Double, cur: String, credit: Bool)? {
        guard let cur = resolve(e.data) else { return nil }
        let acc = cur.acc, credit = cur.credit, bal = Engine.num(acc["balance"])
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
        public init(parts: [Part], dones: [Done]) { self.parts = parts; self.dones = dones }
        public var total: Int { dones.reduce(0) { $0 + $1.n } }
    }

    public static func l4(_ o: JSONValue) -> String {
        let s = Engine.str(o["last4"])
        return s.isEmpty ? "" : " ··" + s
    }

    /// Importa los movimientos marcados (`impGoOne`). `newAccountId` se usa si hay que abrir una cuenta (la del estado de cuenta); `sideAccountId`, si además hay que abrir una cuenta aparte para otra moneda.
    public func apply(to p: inout JSONValue, now: Double, newAccountId: String, sideAccountId: String? = nil) -> Applied? {
        let on = rows.filter(\.on)
        guard !on.isEmpty, let cur0 = resolve(p) else { return nil }
        let isNew = account == Self.newId
        var acc0 = cur0.acc
        if isNew { acc0["id"] = .string(newAccountId) }
        let accId = Engine.identifier(acc0["id"]), credit = cur0.credit
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
            // cuenta nueva: se crea al importar, no antes
            if isNew {
                let col = credit ? "cards" : "accounts"
                var list = p[col]?.arrayValue ?? []
                list.append(acc0)
                p[col] = .array(list)
            }
            let before = isNew ? 0 : bal(accId)
            var ids: [Double] = []
            for r in main {
                var note = r.desc.isEmpty ? r.cat : r.desc
                if let o = r.orig { note += " (" + Money.exact(abs(o.amount), o.cur) + ")" }
                let tid = push(r, acc: acc0["id"] ?? .string(accId), note: note)
                ids.append(tid)
                if mode == .adjust { ProfileEditor.applyTo(&p, acc0["id"], Engine.round2(Migration.clampAmt(r.amount))) }
            }
            if mode == .stmt, let st { setBal(accId, Engine.round2(st.balance)) }
            parts.append(.init(ids: ids, acc: accId, before: before, created: isNew ? accId : nil, cur2: nil))
            dones.append(summary(accId, n: ids.count, created: isNew))
        }
        if !side.isEmpty {
            let F = foreignCurrency, sideId = sideAccountId ?? (isNew ? newAccountId + "-2" : newAccountId)
            var a2Id = fxAccount, created2: String?, cur2: String?
            if a2Id.isEmpty || ProfileEditor.locate(p, .string(a2Id)).flatMap({ Engine.identifier(p[$0.col]?.arrayValue?[$0.index]["id"]) == a2Id ? $0 : nil }) == nil {
                let base = Engine.str(acc0["name"]).replacingOccurrences(of: #"\s+(Soles|Pesos|Dólares)$"#, with: "", options: .regularExpression)
                let nm = base + " " + (F == "USD" ? "Dólares" : F)
                let l4 = Engine.str(acc0["last4"])
                let o: JSONValue = credit
                    ? .object(["id": .string(sideId), "kind": .string("card"), "name": .string(nm), "cur": .string(F), "limit": .number(0), "balance": .number(0),
                               "apr": acc0["apr"] ?? .number(0), "payment": .number(0), "due_day": acc0["due_day"] ?? .number(1), "color": .string(""), "icon": .string(""), "last4": .string(l4)])
                    : .object(["id": .string(sideId), "name": .string(nm), "type": .string("checking"), "cur": .string(F), "apy": .number(0), "balance": .number(0),
                               "color": .string(""), "icon": .string(""), "last4": .string(l4)])
                let col = credit ? "cards" : "accounts"
                var list = p[col]?.arrayValue ?? []
                list.append(o)
                p[col] = .array(list)
                a2Id = sideId; created2 = sideId
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
