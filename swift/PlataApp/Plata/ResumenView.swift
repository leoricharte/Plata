import SwiftUI
import PlataCore

struct ResumenView: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false

    var body: some View {
        let e = model.engine
        let c = e.calc()
        let f = model.fmt
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header(e)
                    KPIGrid(items: kpis(e, c, f))
                    nextIncomeCard(e, f)
                    budgetCard(c, f)
                    gradeCard(e)
                    Card(title: "Ingresos y gastos") {
                        MonthsChart(months: c.months)
                    }
                    Card(title: "Por categoría") {
                        if c.cats.isEmpty {
                            Text("Sin gastos este mes").foregroundStyle(.secondary)
                        } else {
                            CategoryDonut(cats: c.cats, total: f.whole(c.expV))
                        }
                    }
                    accountsCard(e, f)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Añadir movimiento")
                }
            }
            .sheet(isPresented: $adding) { TransactionSheet(mode: .new) }
        }
    }

    // MARK: partes

    private func header(_ e: Engine) -> some View {
        let nick = Engine.text(e.data["settings"]?["nick"]).trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 2) {
            Text(model.today.date(), format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(nick.isEmpty ? "Hola" : "Hola, \(nick)").font(.largeTitle.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func kpis(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> [KPIGrid.Item] {
        let accounts = e.visibleAccounts, cards = e.visibleCards
        let balance = e.totalUSD(accounts)
        let debt = e.totalUSD(cards)
        return [
            .init(id: "balance", title: "Balance actual", value: f.whole(balance), detail: plural(accounts.count, "cuenta", "cuentas")),
            .init(id: "income", title: "Ingresos del mes", value: f.whole(c.income), detail: plural(c.incomeCount, "ingreso", "ingresos")),
            .init(id: "saved", title: "Ahorro total", value: f.whole(c.saved), detail: plural(e.data["savings"]?.arrayValue?.count ?? 0, "meta", "metas")),
            .init(id: "debt", title: "Deuda total", value: f.whole(debt), detail: plural(cards.count, "cuenta", "cuentas")),
        ]
    }

    private func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }

    @ViewBuilder
    private func nextIncomeCard(_ e: Engine, _ f: Fmt) -> some View {
        let pending = e.pendingItems().contains { $0.kind == "in" }
        if let next = e.nextIncome(),
           let item = e.allIncomeItems.first(where: { Engine.identifier($0["id"]) == next.id }),
           let day = LocalDate(iso: next.date) {
            let days = day.days - model.today.days
            let cur = e.accountCurrency(item["acc"])
            Card(title: pending ? "Por confirmar" : "Próximo ingreso") {
                HStack(spacing: 12) {
                    Tile(symbol: "arrow.down.circle.fill", color: Brand.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Engine.text(item["name"])).font(.headline)
                        Text(whenText(day: day, days: days, pending: pending)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(f.signed(next.amount, cur)).font(.headline).foregroundStyle(Brand.gain)
                }
            }
        }
    }

    private func whenText(day: LocalDate, days: Int, pending: Bool) -> String {
        if pending { return days < 0 ? "esperado hace \(-days) \(days == -1 ? "día" : "días")" : "esperado hoy" }
        let label = day.date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return days > 0 ? "\(label) · en \(days) \(days == 1 ? "día" : "días")" : label
    }

    private func budgetCard(_ c: CalcResult, _ f: Fmt) -> some View {
        let left = c.budgetTotal - c.expV
        return Card(title: "Presupuesto del mes") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(f.whole(c.expV)).font(.title.weight(.bold))
                Text("de \(f.whole(c.budgetTotal))").foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(c.expV, 0), max(c.budgetTotal, 0.01)), total: max(c.budgetTotal, 0.01))
                .tint(left < 0 ? Brand.loss : Brand.green)
            Text(c.budgetTotal > 0 ? (left >= 0 ? "Te quedan \(f.whole(left))" : "Te pasaste por \(f.whole(-left))") : "Aún no defines límites")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func gradeCard(_ e: Engine) -> some View {
        if e.scoreEnabled && !e.allTransactions.isEmpty {
            let m = e.insightsModel()
            if m.hasPrev && e.insightsLocked(m) == nil {
                Card(title: "Tu nota del mes") {
                    HStack(spacing: 14) {
                        GradeBadge(letter: m.letter)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(m.score) de 100").font(.headline)
                            Text(streakText(m)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                Card(title: "Tu nota del mes") {
                    Text("Registra un mes completo para recibir tu evaluación.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func streakText(_ m: InsightsModel) -> String {
        switch m.plus {
        case .diamond: return "Diamante · \(m.streak) meses seguidos"
        case .plus: return "\(m.letter)\(m.letter == "D" || m.letter == "F" ? "−" : "+") · \(m.streak) meses seguidos"
        case .none: return m.hasPrev ? "Va como \(m.letter) este mes" : ""
        }
    }

    private func accountsCard(_ e: Engine, _ f: Fmt) -> some View {
        let accounts = e.visibleAccounts, cards = e.visibleCards
        return VStack(spacing: 16) {
            Card(title: "Cuentas") {
                if accounts.isEmpty {
                    Text("Aún no tienes cuentas").foregroundStyle(.secondary)
                }
                ForEach(Array(accounts.enumerated()), id: \.offset) { _, a in
                    accountRow(a, f, symbol: Engine.text(a["type"]) == "savings" ? "banknote.fill" : "building.columns.fill", color: Color(hex: Engine.text(a["color"]).isEmpty ? "#6D8BEA" : Engine.text(a["color"])))
                }
            }
            if !cards.isEmpty {
                Card(title: "Crédito y préstamos") {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, k in
                        accountRow(k, f, symbol: Engine.text(k["kind"]) == "loan" ? "banknote" : "creditcard.fill", color: Color(hex: Engine.text(k["color"]).isEmpty ? "#B98AE6" : Engine.text(k["color"])))
                    }
                }
            }
        }
    }

    private func accountRow(_ a: JSONValue, _ f: Fmt, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Tile(symbol: symbol, color: color, size: 34)
            Text(Engine.text(a["name"])).font(.body)
            Spacer(minLength: 8)
            Text(f.whole(Engine.number(a["balance"]), Engine.text(a["cur"]))).font(.body.weight(.semibold))
        }
    }
}
