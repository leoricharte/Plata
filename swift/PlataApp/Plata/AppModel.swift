import Foundation
import Observation
import PlataCore

/// El estado de la app: el perfil (migrado y sellado), el motor de cálculo y los cambios que hacen las pantallas.
/// Todo lo que cambia el perfil pasa por `commit`: aplica el cambio, sella las ediciones para la nube y guarda en disco.
@MainActor
@Observable
final class AppModel {
    private(set) var profile: Profile
    private(set) var today: LocalDate
    private(set) var engine: Engine { didSet { WatchBridge.shared.push(); WidgetBridge.shared.push(); Reminders.shared.schedule() } }
    /// Cambios hechos en esta sesión (para refrescar vistas derivadas, como el archivo de exportación).
    private(set) var changes = 0
    var errorMessage: String?
    /// La pestaña abierta (para que los enlaces del Resumen puedan cambiarla).
    var tab: AppTab = .resumen
    /// Pantallas abiertas encima del Resumen (Movimientos, Ajustes…).
    var path: [Route] = []
    var showAddTransaction = false
    /// Cuenta con la que se abre el movimiento nuevo y meta que se elige en «Aportar» (al deslizar una fila); se limpian al cerrar.
    var addAccountPreset: String?
    var contribPreset: String?
    /// Posición en pantalla de los botones que el tutorial resalta (`tourAnchor`).
    var tourFrames: [String: CGRect] = [:]
    /// Novedades (historias), «Historia de Plata» y el pedido de opinión: los presenta `RootView`.
    var showNews = false
    /// La bienvenida (se muestra hasta que la termines, o si no hay datos y nunca la viste).
    var showWelcome = false
    var showHistory = false
    /// «Importar movimientos» (Nazca): pantalla completa que presenta `RootView`.
    var showImport = false
    /// Abrir el importador directo en «Importar captura» (desde Nuevo movimiento).
    var importAtCapture = false
    /// Constancias compartidas desde Yape/Plin que necesitan que la persona las revise.
    var inboxReviews: [ImportReview] = []
    var showInboxReview = false
    /// Constancias de Yape/Plin que llegaron por «Compartir» y esperan a que la persona las revise (nada se añade solo).
    var pendingConstancias: [ConstanciaInbox.Entry] = []
    var showFeedback = false
    var feedbackManual = false
    /// Hoja abierta desde el botón «+» o desde las listas (transferir, ingreso o gasto previsto).
    var activeSheet: ActiveSheet?
    /// Cómo deshacer lo último que se aceptó en Revisión (solo mientras la pantalla está abierta).
    var reviewUndoState: ReviewUndo?
    /// La pestaña de Revisión que se está viendo.
    var reviewTab = ""
    /// Set de presupuesto que se está viendo: nil = el que rige hoy, «base» o el id de un set.
    var bsel: String?
    var viewSet: JSONValue? { engine.viewSet(bsel) }
    /// Última vez que se guardó en el dispositivo (la web lo muestra bajo «Guardado»).
    private(set) var lastSaved: Date? = {
        let t = UserDefaults.standard.double(forKey: "plata.lastSaved")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }()

    @ObservationIgnored private let store: ProfileStore
    @ObservationIgnored private let stash: ProfileStore   // tus datos reales mientras ves un perfil de demostración
    @ObservationIgnored private var stamper = SyncStamper()
    /// Plata Cloud: avisa que hubo una edición (para sincronizar en unos segundos) y que se salió de un demo.
    @ObservationIgnored var onEdited: (() -> Void)?
    @ObservationIgnored var onDemoExit: (() -> Void)?

    init() {
        let dir = URL.applicationSupportDirectory.appending(path: "Plata", directoryHint: .isDirectory)
        let store = ProfileStore(directory: dir)
        let loaded = store.load() ?? Profile.empty
        var p = (try? Migration.migrate(loaded)) ?? ((try? Migration.migrate(Profile.empty)) ?? Profile.empty)
        let stamper = SyncStamper()
        var raw = p.raw
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)   // primera pasada: solo toma la foto
        p = Profile(raw: raw)
        let t = LocalDate.today()
        self.store = store
        self.stash = ProfileStore(directory: dir.appending(path: "stash", directoryHint: .isDirectory))
        self.stamper = stamper
        self.profile = p
        self.today = t
        self.engine = Engine(profile: p, today: t)
        self.showWelcome = !Welcome.seen && !p.hasData && !p.isDemo
        Self.syncTrNames(engine)
    }

    /// Los nombres que el traductor reemplaza por `{n}` (apodo y nombre, como `userNames` en la web).
    private static func syncTrNames(_ e: Engine) {
        let s = e.data["settings"]
        var out: [String] = []
        for k in ["nick", "first"] {
            let x = Engine.text(s?[k]).trimmingCharacters(in: .whitespaces)
            if x.count >= 2 && !out.contains(x) { out.append(x) }
        }
        Tr.names = out
    }

    var isDemo: Bool { profile.isDemo }

    /// Hay algo que valga la pena guardar antes de abrir un demo (igual que `demoHasReal` de la web).
    var hasRealData: Bool {
        let e = engine
        return !e.allTransactions.isEmpty || !e.allCards.isEmpty || e.allAccounts.count > 1
            || e.allAccounts.contains { Engine.number($0["balance"]) != 0 }
            || !(e.data["savings"]?.arrayValue ?? []).isEmpty
    }

    var fmt: Fmt { Fmt(currency: engine.primaryCurrency, custom: engine.customCurrency) }

    func refreshToday() {
        let t = LocalDate.today()
        guard t != today else { return }
        today = t
        engine = Engine(profile: profile, today: t)
        Self.syncTrNames(engine)
    }

    // MARK: cambios

    private func commit(_ change: (inout JSONValue) throws -> Void) throws {
        var raw = profile.raw
        try change(&raw)
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        Self.syncTrNames(engine)
        changes += 1
        do { try store.save(profile); stampSaved() } catch { errorMessage = Tr.t("No se pudo guardar en el dispositivo") + ": \(error.localizedDescription)" }
        onEdited?()
    }

    /// Importa los movimientos marcados de una revisión de Nazca. Devuelve lo necesario para mostrar el resumen y deshacerla.
    func importApply(_ review: ImportReview) -> ImportReview.Applied? {
        var out: ImportReview.Applied?
        let nid = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        _ = try? commit { raw in out = review.apply(to: &raw, now: Date().timeIntervalSince1970 * 1000, newAccountId: nid) }
        return out
    }

    func importUndo(_ applied: ImportReview.Applied) {
        _ = try? commit { raw in ImportReview.undo(applied, in: &raw) }
    }

    func addTransaction(date: LocalDate, amount: Double, category: String, note: String, account: String, src: String? = nil) throws {
        try commit { raw in
            _ = try ProfileEditor.addTransaction(&raw, date: date.iso, amount: amount, category: category, note: note, account: account,
                                             now: Date().timeIntervalSince1970 * 1000, src: src)
        }
    }

    func updateTransaction(id: JSONValue, amount: Double, isOut: Bool, category: String, account: String, date: LocalDate, note: String) throws {
        try commit { raw in
            try ProfileEditor.updateTransaction(&raw, id: id, amount: amount, isOut: isOut, category: category, account: account, date: date.iso, note: note)
        }
    }

    func postponeTransaction(id: JSONValue, date: LocalDate) throws {
        let nid = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        let cats = engine.categoryNames
        try commit { raw in try ProfileEditor.postponeTransaction(&raw, id: id, date: date.iso, newId: nid, categories: cats) }
    }

    func toggleCardAuto(id: JSONValue) {
        let t = today.iso
        try? commit { raw in ProfileEditor.toggleCardAuto(&raw, id: id, today: t) }
    }

    func deleteTransaction(id: JSONValue) throws {
        try commit { raw in try ProfileEditor.deleteTransaction(&raw, id: id) }
    }

    private func stampSaved() {
        let d = Date()
        lastSaved = d
        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "plata.lastSaved")
    }

    /// Oculta o vuelve a mostrar una cuenta o tarjeta (`hid`).
    func setAccountHidden(id: String, hidden: Bool) {
        try? commit { raw in
            for key in ["accounts", "cards"] {
                guard var list = raw[key]?.arrayValue else { continue }
                for i in list.indices where Engine.identifier(list[i]["id"]) == id {
                    list[i]["hid"] = hidden ? .bool(true) : nil
                }
                raw[key] = .array(list)
            }
        }
    }

    func addTransfer(from: String, to: String, amount: Double, received: Double, commission: Double, note: String, date: LocalDate) throws {
        let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        try commit { raw in
            try ProfileEditor.addTransfer(&raw, from: from, to: to, amount: amount, received: received, commission: commission, note: note,
                                          date: date.iso, now: Date().timeIntervalSince1970 * 1000, pair: pair)
        }
    }

    func saveExpected(collection: String, item: JSONValue) throws {
        try commit { raw in try ProfileEditor.saveExpected(&raw, collection: collection, item: item) }
    }

    func setEventOverride(key: String, entry: JSONValue?) {
        try? commit { raw in ProfileEditor.setEventOverride(&raw, key: key, entry: entry) }
    }

    func deleteExpected(collection: String, id: JSONValue) throws {
        try commit { raw in ProfileEditor.deleteExpected(&raw, collection: collection, id: id) }
    }

    func saveJob(_ item: JSONValue) throws {
        let nid = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        try commit { raw in try ProfileEditor.saveJob(&raw, item: item, newId: nid) }
    }

    func deleteJob(id: JSONValue) throws {
        try commit { raw in ProfileEditor.deleteJob(&raw, id: id) }
    }

    func savePlanned(_ item: JSONValue) throws {
        try commit { raw in try ProfileEditor.savePlanned(&raw, item: item) }
    }

    func deletePlanned(id: JSONValue) throws {
        try commit { raw in ProfileEditor.deletePlanned(&raw, id: id) }
    }

    func setPlannedOn(id: JSONValue, on: Bool) {
        try? commit { raw in ProfileEditor.setPlannedOn(&raw, id: id, on: on) }
    }

    /// Ejecuta un gasto o pago simulado hoy. `amount` en USD, como se guarda.
    func executePlanned(_ pl: JSONValue) throws {
        let e = engine
        let usd = abs(Engine.number(pl["amount"]))
        let now = Date().timeIntervalSince1970 * 1000
        let day = LocalDate.today(now: Date()).iso
        if Engine.text(pl["kind"]) == "pay", let card = e.allCards.first(where: { $0["id"] == pl["card"] }) {
            let cardCur = Engine.text(card["cur"])
            let amtC = Engine.roundCents(e.fromUSD(usd, cardCur))
            guard amtC > 0 else { throw ProfileEditor.FormError.invalidAmount }
            let fromId = pl["acc"]
            let fromCur = e.accountCurrency(fromId)
            let fromAmt = Engine.roundCents(e.fromUSD(usd, fromCur))
            let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
            try commit { raw in
                ProfileEditor.registerPay(&raw, card: card["id"] ?? .null, amount: amtC, fromAmount: fromAmt, date: day, from: fromId,
                                          note: "Pago de " + Engine.text(card["name"]), now: now, pair: pair)
                ProfileEditor.deletePlanned(&raw, id: pl["id"] ?? .null)
            }
        } else {
            let acc = Engine.text(pl["acc"])
            let amt = Engine.roundCents(e.fromUSD(usd, e.accountCurrency(pl["acc"])))
            let cat = e.categoryNames.contains(Engine.text(pl["cat"])) ? Engine.text(pl["cat"]) : "Otros"
            let note = Engine.text(pl["name"]).replacingOccurrences(of: "\\s*\\(simulado\\)", with: "", options: [.regularExpression, .caseInsensitive])
            try commit { raw in
                try ProfileEditor.execPlannedExpense(&raw, id: pl["id"] ?? .null, amount: amt, account: acc, category: cat, note: note, date: day, now: now)
            }
        }
    }

    // MARK: pendientes por confirmar

    /// Lo próximo que falta confirmar (ingreso, gasto o pago de tarjeta) y cuántos hay.
    func nextPending() -> (item: PendingItem, count: Int)? {
        let l = engine.pendingItems()
        return l.first.map { ($0, l.count) }
    }

    /// Abre la hoja de confirmar si hay algo vencido y no hay otra hoja abierta (`checkPending`).
    var splashDone = false

    /// Lee las constancias que dejó «Compartir». Nunca crea movimientos: quedan en espera (banner del Resumen y «Constancias» en Revisión)
    /// hasta que la persona las revise. Las que ya están en sus movimientos (repetidas) se quitan solas.
    func processConstanciaInbox() {
        let all = ConstanciaInbox.all()
        var gone = Set<String>()
        var keep: [ConstanciaInbox.Entry] = []
        for e in all {
            if let rev = ImportReview(name: "Constancia", statement: e.statement, engine: engine), !rev.rows.allSatisfy({ $0.why == .exact }) { keep.append(e) }
            else { gone.insert(e.id) }
        }
        ConstanciaInbox.remove(ids: gone)
        if keep != pendingConstancias { pendingConstancias = keep }
    }

    /// Abre la revisión de Nazca con las constancias en espera (o solo con las indicadas).
    func reviewConstancias(_ ids: Set<String>? = nil) {
        let list = pendingConstancias.filter { ids?.contains($0.id) ?? true }
        let revs = list.compactMap { ImportReview(name: "Constancia", statement: $0.statement, engine: engine) }
        guard !revs.isEmpty else { return }
        inboxReviews = Array(revs.prefix(ImportReview.maxFiles))
        showInboxReview = true
    }

    func discardConstancia(_ id: String) {
        ConstanciaInbox.remove(ids: [id])
        pendingConstancias.removeAll { $0.id == id }
    }

    /// Texto del aviso: «Yape», «Plin» o «Yape y Plin» según lo que haya.
    var constanciaBrands: String {
        let b = Set(pendingConstancias.map { $0.brand.lowercased() })
        return b.contains("yape") && b.contains("plin") ? "Yape y Plin" : b.contains("plin") ? "Plin" : "Yape"
    }

    func checkPending() {
        guard activeSheet == nil, !showAddTransaction, let p = nextPending() else { return }
        activeSheet = .confirm(kind: p.item.kind, id: p.item.id, pick: false)
    }

    private func tomorrow() -> String { today.adding(days: 1).iso }

    /// Confirma un ingreso o gasto esperado con el monto real. `hours`: horas trabajadas (ingresos de un trabajo).
    func confirmExpected(kind: String, id: String, amount: Double, hours: Double) throws {
        guard amount > 0 else { throw ProfileEditor.FormError.invalidAmount }
        let e = engine
        let out = kind == "out"
        let coll = out ? "expected_expense" : "expected_income"
        guard let item = e.data[coll]?.arrayValue?.first(where: { Engine.identifier($0["id"]) == id }) else { return }
        let itemId = item["id"] ?? .null
        let acc = item["acc"] ?? .null
        let rawDate = Engine.text(item["date"])
        let day = rawDate <= today.iso ? rawDate : today.iso
        let now = Date().timeIntervalSince1970 * 1000
        var next: String?
        if Engine.flag(item["repeat"]), let rep = item["repeat"] {
            let n = Engine.nextOccurrence(rawDate, rep)
            let until = Engine.text(item["until"])
            next = (!until.isEmpty && n > until) ? nil : n
        }
        let card = out ? e.paymentCard(item) : nil
        let cat = e.categoryNames.contains(Engine.text(item["cat"])) ? Engine.text(item["cat"]) : "Otros"
        let est = Engine.number(e.effectiveItem(out ? "exp" : "in", item)["amount"])
        let job = out ? nil : e.jobOf(item)
        let cur = e.accountCurrency(acc)
        try commit { raw in
            if let card {
                let cardAmt = Engine.roundCents(e.fromUSD(e.usd(amount, cur), Engine.text(card["cur"])))
                let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
                let name = Engine.text(item["name"])
                ProfileEditor.registerPay(&raw, card: card["id"] ?? .null, amount: cardAmt, fromAmount: amount, date: day, from: acc,
                                          note: name.isEmpty ? "Pago de " + Engine.text(card["name"]) : name, now: now, pair: pair)
            } else if out {
                _ = try ProfileEditor.addTransaction(&raw, date: day, amount: -amount, category: cat, note: Engine.text(item["name"]),
                                                     account: Engine.identifier(acc), now: now)
            } else {
                ProfileEditor.confirmIncome(&raw, date: day, amount: amount, name: Engine.text(item["name"]), account: acc, estimate: est,
                                            job: job, rate: Engine.number(job?["rate"]), hours: hours > 0 ? hours : (job.map { Engine.jobHours($0) } ?? 0), now: now)
            }
            ProfileEditor.finishExpected(&raw, collection: coll, id: itemId, next: next)
        }
    }

    /// «Adelantar a hoy»: un ingreso o gasto previsto pasa a hoy y se vuelve a preguntar.
    func moveExpectedToToday(collection: String, id: JSONValue) {
        try? commit { raw in ProfileEditor.finishExpected(&raw, collection: collection, id: id, next: today.iso) }
    }

    /// «Aún no llegó / se cobró / pagué»: pregunta mañana.
    func snoozePending(kind: String, id: String) {
        let e = engine
        if kind == "pay" {
            guard let c = e.allCards.first(where: { Engine.identifier($0["id"]) == id }) else { return }
            try? commit { raw in ProfileEditor.snoozeCardAuto(&raw, id: c["id"] ?? .null, until: tomorrow()) }
        } else {
            let coll = kind == "out" ? "expected_expense" : "expected_income"
            guard let item = e.data[coll]?.arrayValue?.first(where: { Engine.identifier($0["id"]) == id }) else { return }
            try? commit { raw in ProfileEditor.snoozeExpected(&raw, collection: coll, id: item["id"] ?? .null, until: tomorrow()) }
        }
    }

    /// Pago de crédito hecho a mano (`submitSheet` con tipo «Pago»). `auto`: dejar activado el pago esperado.
    func registerCardPayment(card id: String, amount: Double, from: String, date: LocalDate, note: String, auto: Bool) throws {
        guard amount > 0 else { throw ProfileEditor.FormError.invalidAmount }
        let e = engine
        guard let card = e.allCards.first(where: { Engine.identifier($0["id"]) == id }) else { throw ProfileEditor.FormError.missingCard }
        let fromJSON: JSONValue? = from.isEmpty ? nil : .string(from)
        let fromAmt = from.isEmpty ? 0 : Engine.roundCents(e.fromUSD(e.usd(amount, Engine.text(card["cur"])), e.accountCurrency(.string(from))))
        let left = Engine.roundCents(Engine.number(card["balance"]) - amount)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.isEmpty ? "Pago de " + Engine.text(card["name"]) + ((Engine.number(card["payment"]) > 0 && left <= 0.005) ? " · final" : "") : trimmed
        let dueDay = Int(Engine.number(card["due_day"]))
        let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        let now = Date().timeIntervalSince1970 * 1000
        try commit { raw in
            ProfileEditor.registerPay(&raw, card: card["id"] ?? .null, amount: amount, fromAmount: fromAmt, date: date.iso, from: fromJSON, note: text, now: now, pair: pair)
            if auto, dueDay > 0, left > 0.005 {
                ProfileEditor.enableCardAuto(&raw, id: card["id"] ?? .null, from: from, next: Engine.dueAfter(day: dueDay, after: date.iso))
            }
        }
    }

    /// Confirma el pago esperado de una tarjeta o préstamo. `from`: cuenta de origen ("" = sin descontar).
    func confirmCardPay(id: String, amount: Double, from: String) throws {
        guard amount > 0 else { throw ProfileEditor.FormError.invalidAmount }
        let e = engine
        guard let card = e.allCards.first(where: { Engine.identifier($0["id"]) == id }), let auto = card["auto"] else { return }
        let nextDate = Engine.text(auto["next"])
        let day = nextDate <= today.iso ? nextDate : today.iso
        let fromJSON: JSONValue? = from.isEmpty ? nil : .string(from)
        let fromAmt = from.isEmpty ? 0 : Engine.roundCents(e.fromUSD(e.usd(amount, Engine.text(card["cur"])), e.accountCurrency(.string(from))))
        let left = Engine.roundCents(Engine.number(card["balance"]) - amount)
        let final = Engine.number(card["payment"]) > 0 && left <= 0.005
        let note = "Pago de " + Engine.text(card["name"]) + (final ? " · final" : "")
        let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        let now = Date().timeIntervalSince1970 * 1000
        try commit { raw in
            ProfileEditor.registerPay(&raw, card: card["id"] ?? .null, amount: amount, fromAmount: fromAmt, date: day, from: fromJSON, note: note, now: now, pair: pair)
            ProfileEditor.advanceCardAuto(&raw, id: card["id"] ?? .null, from: from, today: today.iso)
        }
    }

    func saveSaving(_ item: JSONValue) throws {
        try commit { raw in try ProfileEditor.saveSaving(&raw, item: item) }
    }

    func deleteSaving(id: JSONValue) throws {
        try commit { raw in ProfileEditor.deleteSaving(&raw, id: id) }
    }

    func contribute(savingId: JSONValue, amount: Double) throws {
        let day = LocalDate.today(now: Date()).iso
        try commit { raw in try ProfileEditor.contribute(&raw, savingId: savingId, amount: amount, date: day) }
    }

    /// `linkFactor`: por cuánto se convirtieron los montos al cambiar de moneda en el formulario (1 = no se convirtieron):
    /// lo que depende de la cuenta (movimientos, previstos, simulados, trabajos) se convierte igual.
    func saveAccount(_ item: JSONValue, linkFactor: Double = 1) throws {
        try commit { raw in
            try ProfileEditor.saveAccount(&raw, item: item)
            if linkFactor > 0, linkFactor != 1 { CurrencyChange.scaleLinked(&raw, id: Engine.identifier(item["id"]), factor: linkFactor, cur: Engine.text(item["cur"])) }
        }
    }
    func saveDebt(_ item: JSONValue, linkFactor: Double = 1) throws {
        try commit { raw in
            try ProfileEditor.saveDebt(&raw, item: item)
            if linkFactor > 0, linkFactor != 1 { CurrencyChange.scaleLinked(&raw, id: Engine.identifier(item["id"]), factor: linkFactor, cur: Engine.text(item["cur"])) }
        }
    }

    /// «Adelantar cobro»: registra hoy el cobro de la suscripción y salta el próximo de la serie.
    func advanceSubscription(id: String) throws {
        let e = engine
        guard let sb = e.subscriptionList.first(where: { Engine.identifier($0["id"]) == id }) else { throw ProfileEditor.EditError.notFound }
        let cur = Engine.text(sb["cur"])
        let own = Engine.flag(sb["acc"]) ? (e.allAccounts + e.allCards).first(where: { $0["id"] == sb["acc"] }) : nil
        guard let acc = own ?? e.allAccounts.first(where: { Engine.text($0["cur"]) == cur }) ?? e.allAccounts.first else { throw ProfileEditor.EditError.notFound }
        let accCur = Engine.text(acc["cur"])
        let amount = Engine.number(sb["amount"])
        let amt = accCur == cur ? amount : Engine.roundCents(e.fromUSD(e.usd(amount, cur), accCur))
        let now = Date().timeIntervalSince1970 * 1000
        let day = today.iso
        try commit { raw in
            try ProfileEditor.advanceSubscription(&raw, id: sb["id"] ?? .null, account: acc["id"] ?? .null, amount: amt, today: day, now: now)
        }
    }
    func saveSub(_ item: JSONValue) throws { try commit { raw in try ProfileEditor.saveSub(&raw, item: item) } }
    func deleteSub(id: JSONValue) throws { try commit { raw in ProfileEditor.deleteSub(&raw, id: id) } }
    func deleteAccountCascade(id: JSONValue) throws { try commit { raw in try ProfileEditor.deleteAccountCascade(&raw, id: id) } }

    func saveCategory(original: String?, name: String, color: String, icon: String, limitUSD: Double) throws {
        let setId = viewSet?["id"]
        try commit { raw in try ProfileEditor.saveCategory(&raw, original: original, name: name, color: color, icon: icon, limitUSD: limitUSD, setId: setId) }
    }

    func saveBudgetSet(id: String, isNew: Bool, name: String, from: String, to: String, cur: String, source: String?) throws {
        try commit { raw in try ProfileEditor.saveBudgetSet(&raw, id: id, isNew: isNew, name: name, from: from, to: to, cur: cur, sourceSetId: source) }
        if isNew { bsel = id }
    }

    /// Guarda lo que la web guarda sola al abrir Resumen: el primer half‑time y la foto de la nota a mitad de mes.
    func syncInsightsState() {
        let e = engine
        guard e.insightsEnabled, e.scoreEnabled else { return }
        let cm = e.insightsModel()
        let claim = e.firstHalfClaim(cm)
        var snap: (String, Int)?
        if e.halfSnap(cm.mk) == nil, cm.day >= 15 || Engine.flag(e.data["settings"]?["forceHalf"]) {
            let hm = e.insightsModel(month: cm.mk, upTo: 15)
            if hm.hasPrev { snap = (hm.letter, hm.score) }
        }
        if claim == nil && snap == nil { return }
        try? commit { raw in
            if let claim { raw["firstHalf"] = .string(claim) }
            if let snap {
                var s = raw["halfSnaps"] ?? .object([:])
                s[cm.mk] = .object(["letter": .string(snap.0), "score": .number(Double(snap.1))])
                raw["halfSnaps"] = s
            }
        }
    }

    func deleteBudgetSet(id: String) {
        try? commit { raw in ProfileEditor.deleteBudgetSet(&raw, id: id) }
        if bsel == id { bsel = nil }
    }

    func deleteCategory(name: String) throws { try commit { raw in ProfileEditor.deleteCategory(&raw, name: name) } }

    /// Guarda la foto de perfil: la recortada (`photo`), la original reducida (`photoSrc`) y el encuadre (`photoCrop`).
    func setPhoto(photo: String, source: String, crop: PhotoCrop) {
        try? commit { raw in
            var s = raw["settings"] ?? .object([:])
            s["photo"] = .string(photo)
            s["photoSrc"] = .string(source)
            s["photoCrop"] = .object(["x": .number(crop.x), "y": .number(crop.y), "z": .number(crop.z)])
            raw["settings"] = s
        }
    }

    func removePhoto() {
        try? commit { raw in
            var s = raw["settings"] ?? .object([:])
            s["photo"] = nil
            s["photoSrc"] = nil
            s["photoCrop"] = nil
            raw["settings"] = s
        }
    }

    // MARK: monedas

    func currencyPlan(primary: String, secondary: String) -> CurrencyChange.Plan {
        CurrencyChange.plan(profile.raw, primary: primary, secondary: secondary)
    }

    func applyCurrencies(primary: String, secondary: String, mode: CurrencyChange.Mode) {
        try? commit { raw in CurrencyChange.apply(&raw, primary: primary, secondary: secondary, mode: mode) }
    }

    /// `setCustomCur`: devuelve un aviso si no se pudo.
    func setCustomCurrency(_ text: String) -> String? {
        let c = Onboarding.normCustom(text)
        if !text.trimmingCharacters(in: .whitespaces).isEmpty && c.isEmpty { return "Código no válido" }
        let old = Engine.text(engine.data["settings"]?["customCur"])
        if c == old { return nil }
        let items = ["accounts", "cards", "subs", "savings"].flatMap { engine.data[$0]?.arrayValue ?? [] }
        if c.isEmpty, !old.isEmpty, [engine.primaryCurrency, engine.secondaryCurrency].contains(old) || items.contains(where: { Engine.text($0["cur"]) == old }) {
            return "Esa moneda está en uso"
        }
        try? commit { raw in
            if !old.isEmpty, !c.isEmpty {
                for key in ["accounts", "cards", "subs", "savings"] {
                    var list = raw[key]?.arrayValue ?? []
                    for i in list.indices where Engine.text(list[i]["cur"]) == old { list[i]["cur"] = .string(c) }
                    raw[key] = .array(list)
                }
            }
            var s = raw["settings"] ?? .object([:])
            if !old.isEmpty, !c.isEmpty {
                if Engine.text(s["currency"]) == old { s["currency"] = .string(c) }
                if Engine.text(s["currency2"]) == old { s["currency2"] = .string(c) }
            }
            s["customCur"] = .string(c)
            raw["settings"] = s
        }
        return nil
    }

    func setSetting(_ key: String, _ value: JSONValue) {
        let old = profile.raw["settings"]?[key]
        if old == value { return }
        if old == nil && (value == .number(0) || value == .string("")) { return }   // no crear ajustes vacíos
        try? commit { raw in
            var s = raw["settings"] ?? .object([:])
            s[key] = value
            raw["settings"] = s
        }
    }

    // MARK: archivo de perfil

    /// Reemplaza todo por el contenido de un archivo de perfil (el mismo formato que exporta la web).
    func importProfile(_ data: Data) throws {
        let incoming = try Profile(jsonData: data)
        let migrated = try Migration.migrate(incoming)
        stamper = SyncStamper()                       // perfil nuevo: se vuelve a tomar la foto, como en la web
        var raw = migrated.raw
        let now = Date().timeIntervalSince1970 * 1000
        stamper.stamp(&raw, now: now)
        SyncStamper.markLoaded(&raw, now: now)        // lo que cargas a propósito gana sobre borrados viejos de la nube
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        Self.syncTrNames(engine)
        changes += 1
        try store.save(profile)
        stampSaved()
        onEdited?()
    }

    /// Un perfil que llegó de Plata Cloud reemplaza al local (no vuelve a disparar una sincronización).
    func applyRemote(_ raw: JSONValue) {
        var r = raw
        r["demo"] = .bool(false)
        guard let migrated = try? Migration.migrate(Profile(raw: r)) else { return }
        try? install(migrated)
        if showWelcome && profile.hasData { showWelcome = false }
    }

    // MARK: perfiles de demostración

    func loadDemo(_ id: String) throws {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else { throw DemoError.missing }
        let demo = try DemoProfile.load(Data(contentsOf: url), today: today)
        if !profile.isDemo, hasRealData { try? stash.save(profile) }
        try install(demo)
    }

    func exitDemo() throws {
        if let saved = stash.load() {
            try install(try Migration.migrate(saved))
        } else {
            try install(try Migration.migrate(Profile.empty))
        }
        stash.delete()
        onDemoExit?()
    }

    private func install(_ new: Profile) throws {
        stamper = SyncStamper()
        var raw = new.raw
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        Self.syncTrNames(engine)
        changes += 1
        try store.save(profile)
        stampSaved()
    }

    func resetProfile() throws {
        try importProfile(Profile.empty.jsonData())
    }

    /// Escribe el perfil en un archivo temporal para compartirlo (nombre `plata-AAAA-MM-DD_HH-mm.json`).
    func exportFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ProfileStore.exportFileName())
        try profile.jsonData().write(to: url, options: .atomic)
        return url
    }
}

/// Montos con la moneda principal (y la propia, si la hay), como `fmt` / `fmt2` de la web.
struct Fmt {
    let currency: String
    let custom: String

    func whole(_ n: Double) -> String { Money.whole(n, currency, custom: custom) }
    func exact(_ n: Double) -> String { Money.exact(n, currency, custom: custom) }
    func whole(_ n: Double, _ cur: String) -> String { Money.whole(n, cur, custom: custom) }
    func exact(_ n: Double, _ cur: String) -> String { Money.exact(n, cur, custom: custom) }
    func signed(_ n: Double, _ cur: String) -> String { Money.signed(n, cur, custom: custom) }
    func symbol(_ cur: String) -> String { Money.symbol(cur, custom: custom) }
}


enum DemoError: LocalizedError {
    case missing
    var errorDescription: String? { "No se encontró el perfil de demostración." }
}

/// Los perfiles de demostración de la web.
struct DemoPerson: Identifiable {
    let id: String
    let name: String
    let city: String
    let line: String
    let color: String
    let symbol: String

    static let all: [DemoPerson] = [
        DemoPerson(id: "shawn", name: "Shawn", city: "San Francisco, CA", line: "Sueldo por hora y vida social activa", color: "#22B573", symbol: "wineglass.fill"),
        DemoPerson(id: "brenda", name: "Brenda", city: "Lima, PE", line: "De EE. UU. a la universidad", color: "#2EC4B6", symbol: "graduationcap.fill"),
        DemoPerson(id: "alessandro", name: "Alessandro", city: "Lima, PE", line: "Primer empleo y vive con su familia", color: "#FF9F0A", symbol: "house.fill"),
        DemoPerson(id: "andrea", name: "Andrea", city: "Lake Placid, NY", line: "Dueña de un hotel con mucho capital", color: "#8E6BD8", symbol: "building.2.fill"),
        DemoPerson(id: "kevin", name: "Kevin", city: "Lima, PE", line: "Ayuda en el taller de su papá y ahorra para una PS5", color: "#5B8DEF", symbol: "gamecontroller.fill"),
    ]
}


/// Las hojas que se abren encima de todo.
enum ActiveSheet: Identifiable, Hashable {
    case transfer
    /// `kind`: "income" o "expense"; `id`: nil para uno nuevo.
    case expected(kind: String, id: String?)
    case job(id: String?)
    case planned(id: String?)
    case saving(id: String?)
    case contrib
    case account(id: String?)
    case debt(id: String?)
    case sub(id: String?)
    case category(name: String?)
    case event(key: String)
    case budgetSets
    case review
    /// Confirmar un pendiente. `pick`: se abrió a mano desde una tarjeta (un solo elemento, con «Cancelar»).
    case confirm(kind: String, id: String, pick: Bool)

    var id: String {
        switch self {
        case .transfer: return "transfer"
        case .expected(let kind, let id): return "expected-\(kind)-\(id ?? "new")"
        case .job(let id): return "job-\(id ?? "new")"
        case .planned(let id): return "planned-\(id ?? "new")"
        case .saving(let id): return "saving-\(id ?? "new")"
        case .contrib: return "contrib"
        case .account(let id): return "account-\(id ?? "new")"
        case .debt(let id): return "debt-\(id ?? "new")"
        case .sub(let id): return "sub-\(id ?? "new")"
        case .category(let n): return "category-\(n ?? "new")"
        case .event(let k): return "event-\(k)"
        case .budgetSets: return "budgetSets"
        case .review: return "review"
        case .confirm(let k, let i, let p): return "confirm-\(k)-\(i)-\(p)"
        }
    }
}

enum AppTab: Hashable, CaseIterable {
    case resumen, presupuesto, proyeccion, ahorro, cuentas
}

// MARK: - Revisión

@MainActor
private var reviewMemo: (key: String, cards: [ReviewCard])?

extension AppModel {
    /// Las tarjetas de Revisión de ahora (se recalculan solo cuando cambian los datos o las descartadas).
    var reviewCards: [ReviewCard] {
        let off = (engine.data["settings"]?["rv_off"]?.arrayValue ?? []).compactMap { $0.stringValue }
        let key = "\(changes)|\(engine.allTransactions.count)|\(off.count)|\(today.days)|\(isDemo)"
        if let m = reviewMemo, m.key == key { return m.cards }
        let cards = engine.reviewScan(skip: off) { Brands.sub(named: $0).map { ReviewBrand(id: $0.id, key0: $0.keys.first ?? "") } }
        reviewMemo = (key, cards)
        return cards
    }

    var reviewOffCount: Int { (engine.data["settings"]?["rv_off"]?.arrayValue ?? []).count }

    private func newShortId() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased() }

    /// Acepta una tarjeta. Devuelve el aviso a mostrar («Transferencia registrada»…).
    func reviewAccept(_ r: ReviewCard) -> String? {
        var msg: String?
        let e = engine
        do {
            try commit { raw in
                let out = try ProfileEditor.reviewAccept(&raw, card: r, engine: e, now: Date().timeIntervalSince1970 * 1000, newId: { newShortId() })
                reviewUndoState = out.undo
                msg = out.message
            }
        } catch { reviewUndoState = nil; return nil }
        return msg
    }

    func reviewDismiss(_ r: ReviewCard) {
        reviewUndoState = nil
        try? commit { raw in ProfileEditor.reviewDismiss(&raw, key: r.k) }
    }

    func reviewResetDismissed() { try? commit { raw in ProfileEditor.reviewReset(&raw) } }

    func reviewAcceptAllLikely() {
        let all = reviewCards
        try? commit { raw in reviewUndoState = ProfileEditor.reviewAcceptAll(&raw, cards: all, newId: { newShortId() }) }
    }

    func reviewDoUndo() {
        guard let u = reviewUndoState else { return }
        reviewUndoState = nil
        try? commit { raw in ProfileEditor.reviewUndo(&raw, u) }
    }

    /// Si ahora hay menos sugerencias que cuando se cerró el aviso, el aviso vuelve a quedar listo para las nuevas.
    func reviewSyncBanner() {
        let n = reviewCards.count
        if n < Int(Engine.number(engine.data["settings"]?["rv_bn"])) { try? commit { raw in ProfileEditor.reviewBanner(&raw, count: n) } }
    }

    /// Cierra el aviso del Resumen hasta que haya más sugerencias que ahora.
    func reviewCloseBanner() { let n = reviewCards.count; try? commit { raw in ProfileEditor.reviewBanner(&raw, count: n) } }
}
