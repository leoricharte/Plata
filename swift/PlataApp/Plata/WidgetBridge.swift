import Foundation
import PlataCore
import WidgetKit

/// Calcula lo que muestran los widgets del iPhone y lo deja en el App Group.
@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()
    private weak var model: AppModel?
    private var task: Task<Void, Never>?

    func start(_ model: AppModel) { self.model = model; push() }

    func push() {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let self, let model = self.model else { return }
            if let d = try? JSONEncoder().encode(Self.snapshot(model)) {
                PhoneShare.save(d)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    static func snapshot(_ model: AppModel) -> PhoneSnapshot {
        let e = model.engine
        let c = e.calc()
        let today = model.today
        let cur = model.fmt.currency
        let limits = e.budgetLimits(e.activeSet())
        let bt = e.categoryNames.reduce(0.0) { $0 + (limits[$1] ?? 0) }
        let im = e.insightsModel()
        let mk = String(today.iso.prefix(7))

        let monthOut = e.allTransactions.filter {
            Engine.text($0["date"]).hasPrefix(mk) && Engine.number($0["amount"]) < 0 && !e.isCreditPayment($0) && Engine.text($0["category"]) != "Transferencia"
        }
        var daily = [Double](repeating: 0, count: max(1, today.day))
        var weekday = [Double](repeating: 0, count: 7)
        for t in monthOut {
            guard let d = LocalDate(iso: Engine.text(t["date"])) else { continue }
            let v = -e.transactionUSD(t)
            if d.day >= 1 && d.day <= daily.count { daily[d.day - 1] += v }
            weekday[d.weekday] += v
        }
        for i in 1..<daily.count { daily[i] += daily[i - 1] }

        var slices = c.cats.sorted { $0.v > $1.v }.prefix(5).map { PSlice(name: Tr.t($0.name), v: $0.v, hex: $0.color) }
        let rest = c.cats.sorted { $0.v > $1.v }.dropFirst(5).reduce(0.0) { $0 + $1.v }
        if rest > 0 { slices.append(PSlice(name: Tr.t("Otros"), v: rest, hex: "#C9CBD1")) }

        var budget: [PRow] = []
        for k in e.categoryNames {
            let lim = limits[k] ?? 0
            if lim > 0 { let sp = c.catTot[k] ?? 0; budget.append(PRow(name: Tr.t(k), amt: sp, lim: lim, sub: "", frac: min(1.5, sp / lim))) }
        }
        budget.sort { $0.frac > $1.frac }

        let top = monthOut.sorted { e.transactionUSD($0) < e.transactionUSD($1) }.prefix(4).map { t -> PRow in
            let n = Engine.text(t["note"])
            let d = LocalDate(iso: Engine.text(t["date"]))
            return PRow(name: n.isEmpty ? Tr.t(Engine.text(t["category"])) : n, amt: e.transactionUSD(t), lim: 0, sub: d.map { "\($0.day) \(Spanish.monthsShort[$0.month0])" } ?? "", frac: -1)
        }

        var upcoming: [PRow] = []
        for ev in e.genEvents() where ev.type != "sim" && ev.date.days >= today.days {
            let n = ev.date.days - today.days
            upcoming.append(PRow(name: ev.name, amt: ev.amt, lim: 0, sub: n == 0 ? "hoy" : n == 1 ? "mañana" : "en \(n) d", frac: -1))
            if upcoming.count == 5 { break }
        }

        var debt: [PRow] = []
        var limitSum = 0.0, owedSum = 0.0
        for k in e.allCards where Engine.text(k["kind"]) == "card" {
            let lim = Engine.number(k["limit"]), bal = Engine.number(k["balance"])
            if lim > 0 { limitSum += e.usd(lim, Engine.text(k["cur"])); owedSum += e.usd(bal, Engine.text(k["cur"])) }
            debt.append(PRow(name: Engine.text(k["name"]), amt: bal, lim: lim, sub: "", frac: lim > 0 ? min(1.5, bal / lim) : -1))
        }
        debt.sort { $0.amt > $1.amt }

        var goals: [PRow] = []
        for g in e.data["savings"]?.arrayValue ?? [] {
            let goal = Engine.number(g["goal"]), bal = Engine.number(g["balance"])
            if goal > 0 { goals.append(PRow(name: Engine.text(g["name"]), amt: bal, lim: goal, sub: "", frac: min(1, bal / goal))) }
        }

        let flow = c.months.suffix(4).map { PBar(label: $0.label, income: $0.income, expense: $0.expense) }
        let first = Engine.text(e.data["settings"]?["nick"]).isEmpty ? Engine.text(e.data["settings"]?["first"]) : Engine.text(e.data["settings"]?["nick"])

        return PhoneSnapshot(
            stamp: Date().timeIntervalSince1970 * 1000, sym: model.fmt.symbol(cur), dec: Money.decimals(cur), name: first,
            balance: c.balance, income: c.income, expense: c.expense,
            rate: c.income > 0 ? (c.income - c.expense) / c.income : -9,
            letter: im.letter, adjective: Tr.t(InsightsText.adjective[im.letter] ?? ""), score: im.score,
            day: today.day, dim: c.dim, budgetTotal: bt, budgetSpent: c.expV, debtTotal: c.debt,
            creditUsed: limitSum > 0 ? min(1, owedSum / limitSum) : -1,
            cats: Array(slices), budget: Array(budget.prefix(5)), top: Array(top), upcoming: upcoming, debt: Array(debt.prefix(3)),
            goals: Array(goals.prefix(3)), daily: daily, weekday: weekday, flow: Array(flow), lang: Tr.lang, tier: im.plus == .diamond ? "diamond" : (im.plus == .plus ? "plus" : "none"))
    }
}
