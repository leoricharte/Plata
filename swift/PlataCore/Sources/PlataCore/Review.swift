import Foundation

/// Una tarjeta de Revisión (`revScan` de la web): algo que «se ve raro» y que la persona puede aceptar o descartar.
public struct ReviewCard: Equatable, Sendable {
    public var kind: String          // xfer, pay2, dup, own, card, big, rec, gap
    public var k: String             // clave estable (para descartar)
    public var txIds: [String]
    public var score: Double
    public var hi = false, far = false
    public var label: String?        // own
    public var cur: String?          // own, rec
    public var out: Double?, inn: Double?   // own
    public var med: Double?          // big
    public var card: String?         // card
    public var acc: String?          // gap, rec
    public var miss: [String]?       // gap
    public var diff: Double?         // gap
    // rec
    public var type: String?         // job, sub, fix
    public var name: String?
    public var amt: Double?
    public var fixed: Bool?
    public var cad: String?
    public var neg: Bool?
    public var q: [Int]?
    public var brand: String?
    public var kindKey: String { kind == "rec" ? "rec_" + (type ?? "fix") : kind }
}

/// La marca de una suscripción conocida que reconoce un texto (la tabla vive en la app).
public struct ReviewBrand: Equatable, Sendable {
    public let id: String, key0: String
    public init(id: String, key0: String) { self.id = id; self.key0 = key0 }
}

public extension Engine {
    /// Lo que Revisión encuentra en los movimientos. `skip`: claves ya descartadas. `brandOf`: marca de suscripción de un texto, si la hay.
    func reviewScan(skip skipKeys: [String], brandOf: (String) -> ReviewBrand?) -> [ReviewCard] {
        Review(engine: self, skip: Set(skipKeys), brandOf: brandOf).scan()
    }
}

private struct Review {
    let e: Engine
    let skip: Set<String>
    let brandOf: (String) -> ReviewBrand?
    let T: [JSONValue]

    init(engine: Engine, skip: Set<String>, brandOf: @escaping (String) -> ReviewBrand?) {
        self.e = engine; self.skip = skip; self.brandOf = brandOf; self.T = engine.allTransactions
    }

    // MARK: utilidades

    static let PAY = "Pago de crédito", XFER = "Transferencia"
    func isPay(_ x: JSONValue) -> Bool { let c = Engine.text(x["category"]); return c == Review.PAY || c == Review.XFER }
    func amount(_ x: JSONValue) -> Double { Engine.number(x["amount"]) }
    func tid(_ x: JSONValue) -> String { Engine.identifier(x["id"]) }
    func U(_ x: JSONValue) -> Double { e.usd(abs(amount(x)), e.accCur(x["acc"])) }
    func day(_ x: JSONValue) -> LocalDate? { LocalDate(iso: Engine.text(x["date"])) }
    func dd(_ a: JSONValue, _ b: JSONValue) -> Double {
        guard let p = day(a), let q = day(b) else { return .nan }
        return Double(abs(p.days - q.days))
    }
    func tol(_ a: JSONValue, _ b: JSONValue) -> Bool { abs(U(a) - U(b)) <= max(0.5, max(U(a), U(b)) * 0.03) }
    func isDeb(_ x: JSONValue) -> Bool { e.allAccounts.contains { $0["id"] == x["acc"] } }
    func isCrd(_ x: JSONValue) -> Bool { e.allCards.contains { $0["id"] == x["acc"] } }
    func loose(_ x: JSONValue) -> Bool { !JS.truthy(x["pair"]) && !JS.truthy(x["job"]) }
    /// `x.id < y.id` de JS: números por valor, el resto como texto.
    func idLess(_ a: JSONValue, _ b: JSONValue) -> Bool {
        if case .number(let p)? = a["id"], case .number(let q)? = b["id"] { return p < q }
        return tid(a) < tid(b)
    }

    struct Cand { var card: ReviewCard; var order: Int }

    func mk(_ kind: String, _ txs: [JSONValue], _ score: Double) -> ReviewCard? {
        let k = kind + ":" + txs.map(tid).joined(separator: "+")
        if skip.contains(k) { return nil }
        return ReviewCard(kind: kind, k: k, txIds: txs.map(tid), score: score)
    }

    static let own: [(id: String, label: String, re: Rx)] = [
        ("secured", "Moved to / from Secured Deposit Account", Rx(#"moved (to|from) secured deposit"#, ci: true)),
        ("savings", "Transfer to / from Savings", Rx(#"transfer (to|from) (my )?(chime )?savings|online banking transfer (to|from) sav|round up to savings"#, ci: true)),
        ("internal", "Transfer from x… to x…", Rx(#"transfer from x?\d+ to x?\d+"#, ci: true)),
        ("visa", "Transfer to / from your Visa", Rx(#"transfer (to|from) (apple pay )?visa \d{4}"#, ci: true))]

    // MARK: revScan

    func scan() -> [ReviewCard] {
        var used = Set<String>()
        var res: [ReviewCard] = []
        var cands: [ReviewCard] = []
        var byDate: [String: [Int]] = [:]
        for (i, x) in T.enumerated() { byDate[Engine.text(x["date"]), default: []].append(i) }
        func near(_ i: Int) -> [Int] {
            guard let d0 = day(T[i]) else { return [] }
            var o: [Int] = []
            for k in -5...5 { for j in byDate[d0.adding(days: k).iso] ?? [] where j != i { o.append(j) } }
            return o
        }
        for xi in T.indices {
            let x = T[xi]
            if !loose(x) { continue }
            for yi in near(xi) {
                let y = T[yi]
                if !loose(y) { continue }
                let g = dd(x, y), ex = abs(U(x) - U(y)) < 0.01, sc = g * 1000 + abs(U(x) - U(y)), same = idLess(x, y)
                let xa = amount(x), ya = amount(y)
                if xa > 0 && isCrd(x) && (Engine.text(x["category"]) == Review.PAY || !isPay(x)) && ya < 0 && isDeb(y) && !isPay(y) && g <= 2 && tol(x, y) {
                    if let c = mk("pay2", [y, x], sc - 1) { cands.append(c) }
                } else if same && !isPay(x) && !isPay(y) && isDeb(x) && isDeb(y) && x["acc"] != y["acc"] && (xa < 0) != (ya < 0) && ((g <= 2 && tol(x, y)) || (g <= 5 && ex)) {
                    let o = xa < 0 ? x : y, i = xa < 0 ? y : x
                    if var c = mk("xfer", [o, i], sc) { c.hi = g <= 1 && ex; c.far = g > 2; cands.append(c) }
                } else if same && g <= 2 && x["acc"] == y["acc"] && JS.truthy(x["imp"]) != JS.truthy(y["imp"]) && xa == ya && !isPay(x) && !isPay(y) {
                    let man = JS.truthy(x["imp"]) ? y : x, imp = JS.truthy(x["imp"]) ? x : y
                    if let c = mk("dup", [man, imp], sc - 500) { cands.append(c) }
                }
            }
        }
        // pick: por puntaje (estable); una tarjeta no puede repetir un movimiento ya usado
        for c in cands.enumerated().sorted(by: { $0.element.score != $1.element.score ? $0.element.score < $1.element.score : $0.offset < $1.offset }).map(\.element) {
            if c.txIds.contains(where: { used.contains($0) }) { continue }
            c.txIds.forEach { used.insert($0) }
            res.append(c)
        }
        // movimientos de/hacia otra cuenta tuya que no está en Plata
        for g in Review.own {
            let m = T.filter { loose($0) && !used.contains(tid($0)) && !isPay($0) && isDeb($0) && g.re.test(Engine.text($0["note"])) }
            let k = "own:" + g.id
            if m.count < 2 || skip.contains(k) { continue }
            m.forEach { used.insert(tid($0)) }
            let cur0 = e.accCur(m[0]["acc"])
            let one = m.allSatisfy { e.accCur($0["acc"]) == cur0 }
            var c = ReviewCard(kind: "own", k: k, txIds: m.map(tid), score: -1)
            c.label = g.label; c.cur = one ? cur0 : ""
            if one {
                c.out = m.filter { amount($0) < 0 }.reduce(0) { $0 + -amount($1) }
                c.inn = m.filter { amount($0) > 0 }.reduce(0) { $0 + amount($1) }
            }
            res.append(c)
        }
        let lim = e.today.adding(days: -120).iso
        // gasto suelto que coincide con la cuota o el saldo de una tarjeta
        for t in T {
            if used.contains(tid(t)) || !loose(t) || amount(t) >= 0 || isPay(t) || !isDeb(t) || Engine.text(t["date"]) < lim { continue }
            let u = U(t)
            let card = e.allCards.first { k in
                Engine.number(k["balance"]) > 0.005 && [Engine.number(k["payment"]), Engine.number(k["balance"])].contains { v in
                    v > 0 && abs(e.usd(v, Engine.text(k["cur"])) - u) <= max(0.5, u * 0.01) }
            }
            if let card, var c = mk("card", [t], 5000) { c.card = Engine.identifier(card["id"]); used.insert(tid(t)); res.append(c) }
        }
        // monto muy por encima de lo habitual en su categoría
        var cat: [String: [Double]] = [:]
        for x in T where amount(x) < 0 && !isPay(x) && !JS.truthy(x["job"]) { cat[Engine.text(x["category"]), default: []].append(abs(amount(x))) }
        for k in cat.keys { cat[k]!.sort() }
        for t in T {
            if used.contains(tid(t)) || amount(t) >= 0 || isPay(t) || JS.truthy(t["job"]) || Engine.text(t["date"]) < lim { continue }
            let v = cat[Engine.text(t["category"])] ?? []
            if v.count < 6 { continue }
            let med = v[v.count / 2]
            let at = abs(amount(t))
            let tc = Engine.text(t["category"])
            let rep = T.enumerated().contains { (_, x) in x != t && Engine.text(x["category"]) == tc && abs(abs(amount(x)) - at) <= at * 0.02 }
            if med > 0 && !rep && at >= med * 10, var c = mk("big", [t], 9000) { c.med = med; res.append(c) }
        }
        // trabajos, suscripciones y gastos que se repiten
        for c in recFind(used: used) where !skip.contains(c.k) { res.append(c) }
        // estados que faltan
        for a in e.allAccounts {
            let aid = Engine.identifier(a["id"])
            let tx = T.filter { $0["acc"] == a["id"] }
            if tx.count < 20 || !tx.allSatisfy({ JS.truthy($0["imp"]) }) { continue }
            var have = Set<String>()
            for x in tx { have.insert(String(Engine.text(x["date"]).prefix(7))) }
            let ks = have.sorted()
            var miss: [String] = []
            var y = Int(ks[0].prefix(4)) ?? 0, m = Int(ks[0].dropFirst(5).prefix(2)) ?? 1
            let ey = Int(ks[ks.count - 1].prefix(4)) ?? 0, em = Int(ks[ks.count - 1].dropFirst(5).prefix(2)) ?? 1
            while y < ey || (y == ey && m <= em) {
                let q = "\(y)-" + (m < 10 ? "0\(m)" : "\(m)")
                if !have.contains(q) { miss.append(q) }
                m += 1; if m > 12 { m = 1; y += 1 }
            }
            let diff = Engine.roundCents(Engine.number(a["balance"]) - tx.reduce(0) { $0 + amount($1) })
            if miss.isEmpty && abs(diff) < 1 { continue }
            let k = "gap:" + aid + ":" + miss.joined(separator: ",") + ":" + String(Int((diff + 0.5).rounded(.down)))
            if skip.contains(k) { continue }
            var c = ReviewCard(kind: "gap", k: k, txIds: [], score: 8500)
            c.acc = aid; c.miss = miss; c.diff = abs(diff) >= 1 ? diff : 0
            res.append(c)
        }
        return res.enumerated().sorted { $0.element.score != $1.element.score ? $0.element.score < $1.element.score : $0.offset < $1.offset }.map(\.element)
    }

    // MARK: recurrentes

    static let stop: Set<String> = ["pos", "purchase", "debit", "card", "visa", "checkcard", "compra", "pago", "payment", "recurring", "www", "com", "inc", "llc", "des", "the", "ach", "web", "online", "pmt", "sq", "tst", "mktp"]
    static let bills: Set<String> = ["Servicios", "Hogar", "Casa", "Alquiler", "Estudios"]
    static let p2p = Rx(#"^(venmo|zelle|yape|plin|cash|paypal|cambio|exchange|transfer|retiro|deposito)\b"#)
    static let names: [String: String] = ["openai": "ChatGPT", "twitter-x": "X", "copilot": "GitHub Copilot", "applemusic": "Apple Music", "appletv": "Apple TV", "icloud": "iCloud", "youtube": "YouTube", "github": "GitHub", "linkedin": "LinkedIn", "playstation": "PlayStation", "xbox": "Xbox", "switch": "Nintendo Switch Online", "cursor-ai": "Cursor", "soundcloud": "SoundCloud", "amazon": "Amazon Prime", "google": "Google One", "microsoft": "Microsoft 365", "meta": "Meta"]
    static let tail = Rx(#"\s(id|indn|ppd|ccd|ref|conf)\b.*$"#), nonAlpha = Rx(#"[^a-z ]+"#), spaces = Rx(#"\s+"#)

    func title(_ w: [String]) -> String { w.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ") }
    func words(_ t: String) -> [String] {
        let s = Review.nonAlpha.replace(Review.tail.replace(Engine.bankNorm(t), " "), " ")
        let parts = s.components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 2 && !Review.stop.contains($0) }
        return Array(parts.prefix(3))
    }
    func recKey(_ t: String) -> String { if let b = brandOf(t) { return "b:" + b.id }; return words(t).joined(separator: " ") }
    func recDays(_ a: String, _ b: String) -> Int {
        guard let p = LocalDate(iso: a), let q = LocalDate(iso: b) else { return 0 }
        return q.days - p.days
    }
    func recMed(_ v: [Double]) -> Double { v.sorted()[v.count / 2] }

    func recFind(used: Set<String>) -> [ReviewCard] {
        struct Mine { var k: String; var w: Set<String>; var neg: Bool; var amt: Double; var day: Int; var cur: String }
        var mine: [Mine] = []
        func addM(_ o: JSONValue, _ neg: Bool, _ amt: Double, _ day: Int, _ cur: String) {
            let name = Engine.text(o["name"])
            if name.isEmpty { return }
            let ws = Review.nonAlpha.replace(Engine.bankNorm(name), " ").components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 4 && !Review.stop.contains($0) }
            mine.append(Mine(k: recKey(name), w: Set(ws), neg: neg, amt: abs(amt.isNaN ? 0 : amt), day: day, cur: cur))
        }
        func dom(_ o: JSONValue) -> Int {
            let d = Engine.text(o["date"])
            let rep = o["repeat"]
            if !d.isEmpty && (!JS.truthy(rep) || rep == .string("m")) { return Int(d.dropFirst(8).prefix(2)) ?? 0 }
            return 0
        }
        for x in e.subscriptionList { addM(x, true, Engine.number(x["amount"]), Int(Engine.number(x["day"])), Engine.text(x["cur"])) }
        for x in e.list("expected_expense") { addM(x, true, Engine.number(x["amount"]), dom(x), e.accCur(x["acc"])) }
        for x in e.list("expected_income") { addM(x, false, Engine.number(x["amount"]), dom(x), e.accCur(x["acc"])) }
        for x in e.list("jobs") { addM(x, false, Engine.jobNet(x), 0, e.accCur(x["acc"])) }
        for x in e.list("recurring") { addM(x, Engine.number(x["amount"]) < 0, Engine.number(x["amount"]), Int(Engine.number(x["day"])), e.primaryCurrency) }
        func dayNear(_ a: Int, _ b: Int) -> Bool { let d = abs(a - b); return min(d, 31 - d) <= 4 }

        struct Group { var k: String; var neg: Bool; var tx: [JSONValue] }
        var order: [String] = [], G: [String: Group] = [:]
        var ref = ""
        for t in T {
            let d = Engine.text(t["date"])
            if d > ref { ref = d }
            if used.contains(tid(t)) || isPay(t) || JS.truthy(t["pair"]) || JS.truthy(t["job"]) || !JS.truthy(t["note"]) || (amount(t) < 0 && e.txSub(t) != nil) { continue }
            let k = recKey(Engine.text(t["note"]))
            if k.isEmpty { continue }
            let g = (amount(t) < 0 ? "-" : "+") + k
            if G[g] == nil { G[g] = Group(k: k, neg: amount(t) < 0, tx: []); order.append(g) }
            G[g]!.tx.append(t)
        }
        var out: [ReviewCard] = []
        for g in order {
            let o = G[g]!
            let owords = o.k.split(separator: " ").map(String.init).filter { $0.count >= 4 }
            var seen = Set<String>(), L: [JSONValue] = []
            let sorted = o.tx.enumerated().sorted { a, b in
                let da = Engine.text(a.element["date"]), db = Engine.text(b.element["date"])
                return da != db ? da < db : a.offset < b.offset
            }.map(\.element)
            for t in sorted { let d = Engine.text(t["date"]); if !seen.contains(d) { seen.insert(d); L.append(t) } }
            let n = L.count
            let cur = e.accCur(L[0]["acc"])
            if n < 2 || L.contains(where: { e.accCur($0["acc"]) != cur }) { continue }
            var gaps: [Double] = []
            for i in 1..<n { gaps.append(Double(recDays(Engine.text(L[i - 1]["date"]), Engine.text(L[i]["date"])))) }
            let med = recMed(gaps)
            let cad = med >= 5 && med <= 9 ? "w" : med >= 12 && med <= 17 ? "b" : med >= 26 && med <= 35 ? "m" : ""
            if cad.isEmpty { continue }
            let win: (Double, Double) = cad == "w" ? (5, 9) : cad == "b" ? (12, 17) : (26, 35)
            if Double(gaps.filter { $0 >= win.0 && $0 <= win.1 }.count) / Double(gaps.count) < 0.75 { continue }
            let amts = L.map { abs(amount($0)) }
            let m = recMed(amts)
            if m < 1 { continue }
            let fixed = amts.allSatisfy { abs($0 - m) <= max(0.5, m * 0.05) }
            let brand = o.k.hasPrefix("b:")
            let looseAmt = amts.allSatisfy { abs($0 - m) <= m * (o.neg ? 0.35 : 0.15) } && (!o.neg || L.allSatisfy { Review.bills.contains(Engine.text($0["category"])) })
            if !fixed && !(looseAmt && cad == "m") { continue }
            if !brand && Review.p2p.test(o.k) { continue }
            if n < (cad == "m" ? (brand && fixed ? 2 : 3) : 4) { continue }
            if Double(recDays(Engine.text(L[n - 1]["date"]), ref)) > med * 1.7 + 3 { continue }
            let lastDay = Int(Engine.text(L[n - 1]["date"]).dropFirst(8).prefix(2)) ?? 0
            let tl = fixed ? 0.05 : 0.15
            let mapped = mine.contains { me in
                (!me.k.isEmpty && me.k == o.k) || (me.neg == o.neg && (
                    (!o.k.hasPrefix("b:") && owords.contains { me.w.contains($0) }) ||
                    (me.amt > 0 && (me.cur.isEmpty || me.cur == cur) && abs(me.amt - m) <= max(0.5, m * tl) && (me.day == 0 || dayNear(me.day, lastDay)))))
            }
            if mapped { continue }
            var q: [Int]?, cd = cad
            if !o.neg && cad == "b" {
                let dy = L.map { Int(Engine.text($0["date"]).dropFirst(8).prefix(2)) ?? 0 }
                let A = dy.filter { $0 >= 13 && $0 <= 17 }, B = dy.filter { $0 >= 27 || $0 <= 2 }
                if !A.isEmpty && !B.isEmpty && A.count + B.count == dy.count {
                    cd = "q"
                    let b2 = B.allSatisfy { $0 >= 27 } ? 30 : Int(recMed(B.map { Double($0 <= 2 ? 30 : $0) }))
                    q = [Int(recMed(A.map(Double.init))), b2]
                }
            }
            var accs: [String: Int] = [:], accOrder: [String] = []
            for t in L { let a = Engine.identifier(t["acc"]); if accs[a] == nil { accOrder.append(a) }; accs[a, default: 0] += 1 }
            let acc = accOrder.enumerated().sorted { accs[$0.element]! != accs[$1.element]! ? accs[$0.element]! > accs[$1.element]! : $0.offset < $1.offset }.first?.element
            let bd: ReviewBrand? = brand ? brandOf(Engine.text(L[0]["note"])) : nil
            let type = !o.neg ? "job" : (brand && cad == "m" ? "sub" : "fix")
            let nm: String
            if let bd { nm = Review.names[bd.id] ?? title(bd.key0.split(separator: " ").map(String.init)) } else { nm = title(o.k.split(separator: " ").map(String.init)) }
            var c = ReviewCard(kind: "rec", k: "rec:" + g, txIds: L.map(tid), score: type == "job" ? 6000 : type == "sub" ? 6100 : 6200)
            c.type = type; c.name = nm; c.amt = Engine.roundCents(m); c.fixed = fixed; c.cad = cd; c.cur = cur; c.q = q; c.acc = acc; c.brand = bd?.id; c.neg = o.neg
            out.append(c)
        }
        return out
    }
}
