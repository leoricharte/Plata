import Foundation
import PlataCore
import WatchConnectivity

/// Puente con el Apple Watch: el iPhone calcula un resumen y se lo manda al reloj; el reloj manda de vuelta los movimientos que anota.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private weak var model: AppModel?
    private let doneKey = "plata.watch.done"
    private var pushTask: Task<Void, Never>?

    func start(_ model: AppModel) {
        self.model = model
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    /// Manda el resumen (con una pequeña espera para juntar cambios seguidos).
    func push() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.pushNow()
        }
    }

    private func pushNow() {
        guard let model, WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(Self.snapshot(model)) else { return }
        try? s.updateApplicationContext([WatchKey.snapshot: data])
    }

    // MARK: resumen

    static func snapshot(_ model: AppModel) -> WatchSnapshot {
        let e = model.engine
        let c = e.calc()
        let limits = e.budgetLimits(e.activeSet())
        let today = model.today
        let bt = e.categoryNames.reduce(0.0) { $0 + (limits[$1] ?? 0) }
        let dl = max(1, c.dim - today.day + 1)

        var spentToday = 0.0
        for t in e.allTransactions where Engine.text(t["date"]) == today.iso && Engine.number(t["amount"]) < 0 && !e.isCreditPayment(t) {
            spentToday -= e.transactionUSD(t)
        }
        let before = max(0, c.expV - spentToday)
        let allowance = bt > 0 ? max(0, (bt - before) / Double(dl)) : 0

        var cats: [WatchCat] = []
        for k in e.categoryNames {
            let lim = limits[k] ?? 0
            if lim > 0 { cats.append(WatchCat(name: Tr.t(k), spent: c.catTot[k] ?? 0, limit: lim)) }
        }
        cats.sort { ($0.spent / $0.limit) > ($1.spent / $1.limit) }

        var byDay: [String: [WatchEvent]] = [:]
        let events = e.genEvents()
        for ev in events where ev.type != "sim" {
            byDay[ev.date.iso, default: []].append(WatchEvent(name: ev.name, amt: ev.amt, type: ev.type))
        }
        let series = e.dailySeries()
        let limited = e.allCards.filter { Engine.text($0["kind"]) == "card" && Engine.number($0["limit"]) > 0 }
        let creditLimit = limited.reduce(0.0) { $0 + e.usd(Engine.number($1["limit"]), Engine.text($1["cur"])) }
        let avail0 = limited.reduce(0.0) { $0 + max(0, e.usd(Engine.number($1["limit"]) - Engine.number($1["balance"]), Engine.text($1["cur"]))) }
        var owed = max(0, creditLimit - avail0)
        var days: [WatchDay] = []
        for p in series.prefix(28) {
            let list = byDay[p.date.iso] ?? []
            for x in list where x.type == "card" { owed = max(0, owed + x.amt) }   // un pago de tarjeta (negativo en caja) baja lo que debes y sube lo disponible
            days.append(WatchDay(iso: p.date.iso, cash: p.v, credit: creditLimit - owed, events: list))
        }

        var next: (String, Double, Int)?
        for ev in events where ev.type != "sim" && ev.date.days >= today.days {
            next = (ev.name, ev.amt, ev.date.days - today.days); break
        }

        var accounts = e.allAccounts.map { WatchAccount(id: Engine.text($0["id"]), name: Engine.text($0["name"])) }
        accounts += e.allCards.map { WatchAccount(id: Engine.text($0["id"]), name: Engine.text($0["name"])) }

        let im = e.insightsModel()
        let cur = model.fmt.currency
        return WatchSnapshot(
            stamp: Date().timeIntervalSince1970 * 1000, sym: model.fmt.symbol(cur), dec: Money.decimals(cur),
            spentToday: spentToday, allowance: allowance, daysLeft: dl, cats: Array(cats.prefix(4)), days: days,
            accounts: accounts, categories: e.categoryNames.filter { $0 != "Ingreso" }, letter: im.letter,
            adjective: Tr.t(InsightsText.adjective[im.letter] ?? ""),
            nextName: next?.0 ?? "", nextAmt: next?.1 ?? 0, nextIn: next?.2 ?? -1, hasCredit: creditLimit > 0)
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.pushNow() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.pushNow() } }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchKey.entry] as? Data, let entry = try? JSONDecoder().decode(WatchEntry.self, from: data) else { return }
        Task { @MainActor in self.receive(entry) }
    }

    private func receive(_ entry: WatchEntry) {
        var done = UserDefaults.standard.stringArray(forKey: doneKey) ?? []
        guard !done.contains(entry.id), let model, let d = LocalDate(iso: entry.date) else { return }
        do {
            try model.addTransaction(date: d, amount: entry.amount, category: entry.category, note: entry.note, account: entry.account, src: "watch")
            done.append(entry.id)
            UserDefaults.standard.set(Array(done.suffix(100)), forKey: doneKey)
            pushNow()
        } catch { model.errorMessage = error.localizedDescription }
    }
}
