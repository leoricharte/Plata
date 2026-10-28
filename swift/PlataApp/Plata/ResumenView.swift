import SwiftUI
import PlataCore

/// Pantallas a las que se llega desde el Resumen.
enum Route: Hashable {
    case movimientos
    case ajustes
    case soon(String)
}

struct ResumenView: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var path: [Route] = []
    @State private var pickingDemo = false

    var body: some View {
        let e = model.engine
        let c = e.calc()
        let f = model.fmt
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    titleBlock(e)
                    if !hasData(e) { startCard }
                    if model.isDemo { demoCard }
                    KPIGrid(items: kpis(e, c, f))
                    nextIncomeCard(e, f)
                    monthSection(e, c, f)
                    budgetCard(c, f)
                    expensesCard(c, f)
                    categoriesCard(c, f)
                    gradeCard(e)
                    SectionHead("Cuentas")
                    accountsList(e, c, f)
                    SectionHead("Más")
                    moreList(e, c, f)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .movimientos: MovimientosView()
                case .ajustes: AjustesView()
                case .soon(let title): ComingSoonView(title: title)
                }
            }
            .sheet(isPresented: $adding) { TransactionSheet(mode: .new) }
            .sheet(isPresented: $pickingDemo) { DemoPickerSheet() }
        }
    }

    // MARK: encabezado

    private var topBar: some View {
        HStack(spacing: 8) {
            Image("PlataLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112)
                .accessibilityLabel("Plata")
            BetaPill()
            Spacer(minLength: 8)
            Button { adding = true } label: { GlassIcon(symbol: "plus") }
                .buttonStyle(.plain)
                .accessibilityLabel("Añadir movimiento")
            NavigationLink(value: Route.ajustes) { GlassIcon(symbol: "gearshape") }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajustes")
        }
        .padding(.horizontal, 4)
    }

    private func titleBlock(_ e: Engine) -> some View {
        let nick = Engine.text(e.data["settings"]?["nick"]).trimmingCharacters(in: .whitespaces)
        let hour = Calendar.current.component(.hour, from: Date())
        return VStack(alignment: .leading, spacing: 2) {
            Text(Spanish.dateLong(model.today)).font(.inter(15)).foregroundStyle(.secondary)
            Text(Spanish.greeting(nick: nick, hour: hour))
                .font(.inter(34, .bold, relativeTo: .largeTitle))
                .tracking(-1.2)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("Todo guardado").font(.inter(15)).foregroundStyle(.secondary).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private func hasData(_ e: Engine) -> Bool {
        var n = 0
        for key in ["transactions", "cards", "savings", "subs", "expected_income", "expected_expense", "planned"] {
            n += e.data[key]?.arrayValue?.count ?? 0
        }
        return n > 0 || !(e.data["budget"]?.objectValue ?? [:]).isEmpty
    }

    // MARK: tarjetas de aviso

    private var startCard: some View {
        Card {
            Text("Empieza aquí").font(.inter(20, .semibold, relativeTo: .title3))
            Text("Tu app... no tiene (casi) nada. Pero no te me abrumes, empieza en la pestaña Cuentas: ajusta tu saldo y añade tus tarjetas, añade movimientos o carga tu archivo de perfil.")
                .font(.inter(15)).foregroundStyle(.secondary)
                .padding(.bottom, 4)
            startRow("plus.circle.fill", "Añadir un movimiento") { adding = true }
            startRow("folder.fill", "Cargar mi archivo de perfil") { path.append(.ajustes) }
            startRow("info.circle.fill", "Ver con datos de ejemplo") { pickingDemo = true }
        }
    }

    private func startRow(_ symbol: String, _ title: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Brand.green).frame(width: 26)
                Text(title).font(.inter(17)).foregroundStyle(Brand.green)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var demoCard: some View {
        Card {
            HStack(spacing: 8) {
                Circle().fill(Brand.accent).frame(width: 10, height: 10)
                Text("Perfil de demostración").font(.inter(16, .semibold))
            }
            Text("Estás viendo datos de ejemplo. Tus datos reales siguen guardados aparte y vuelven cuando salgas del demo.")
                .font(.inter(14)).foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Button { try? model.exitDemo() } label: {
                Text("Salir del demo")
                    .font(.inter(15, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Brand.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: números

    private func kpis(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> [KPIGrid.Item] {
        let accounts = e.visibleAccounts, cards = e.visibleCards
        let balance = e.totalUSD(accounts)
        let visibleCardIds = Set(cards.map { Engine.identifier($0["id"]) })
        var debt = 0.0
        for k in c.cards where visibleCardIds.contains(k.id) { debt += k.ub }
        let goals = e.data["savings"]?.arrayValue?.count ?? 0
        return [
            .init(id: "balance", title: "Balance actual", value: f.whole(balance), detail: Spanish.plural(accounts.count, "cuenta", "cuentas"),
                  action: { model.tab = .cuentas }),
            .init(id: "income", title: "Ingresos del mes", value: f.whole(c.income), detail: Spanish.plural(c.incomeCount, "ingreso", "ingresos"),
                  action: { path.append(.movimientos) }),
            .init(id: "saved", title: "Ahorro total", value: f.whole(c.saved), detail: Spanish.plural(goals, "meta", "metas"), link: "Ver ahorro",
                  action: { path.append(.soon("Ahorro")) }),
            .init(id: "debt", title: "Deuda total", value: f.whole(debt), detail: Spanish.plural(cards.count, "cuenta", "cuentas"), link: "Ver deuda",
                  action: { model.tab = .cuentas }),
        ]
    }

    @ViewBuilder
    private func nextIncomeCard(_ e: Engine, _ f: Fmt) -> some View {
        let pending = e.pendingItems().contains { $0.kind == "in" }
        if let next = e.nextIncome(),
           let item = e.allIncomeItems.first(where: { Engine.identifier($0["id"]) == next.id }),
           let day = LocalDate(iso: next.date) {
            let days = day.days - model.today.days
            let cur = e.accountCurrency(item["acc"])
            let name = Engine.text(item["name"])
            Card(title: pending ? "Por confirmar" : "Próximo ingreso") {
                HStack(spacing: 12) {
                    LetterTile(letter: String(name.prefix(1)), color: Brand.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.inter(17, .semibold)).tracking(-0.3).lineLimit(1)
                        Text(whenText(day: day, days: days, pending: pending)).font(.inter(14)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(f.signed(next.amount, cur)).font(.inter(16, .semibold)).monospacedDigit().foregroundStyle(Brand.gain)
                }
                .padding(.top, 2)
            }
        }
    }

    private func whenText(day: LocalDate, days: Int, pending: Bool) -> String {
        if pending { return days < 0 ? "esperado hace \(-days) \(days == -1 ? "día" : "días")" : "esperado hoy" }
        let label = Spanish.dateShort(day)
        return days > 0 ? "\(label) · en \(days) \(days == 1 ? "día" : "días")" : label
    }

    // MARK: movimientos del mes

    @ViewBuilder
    private func monthSection(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> some View {
        let month = Spanish.monthsFull[model.today.month0]
        let sums = e.monthSums(c.mk)
        let net = sums.inc - sums.exp
        let byId: [String: JSONValue] = Dictionary(e.allTransactions.map { (Engine.identifier($0["id"]), $0) }, uniquingKeysWith: { a, _ in a })
        let hidden = Set(e.allAccounts.filter { Engine.flag($0["hid"]) }.map { Engine.identifier($0["id"]) })
        let firstAccount = Engine.identifier(e.allAccounts.first?["id"])
        let rows: [JSONValue] = c.monthTxIds.compactMap { byId[$0] }.filter { tx in
            let acc = Engine.identifier(tx["acc"])
            return !hidden.contains(acc.isEmpty ? firstAccount : acc)
        }
        SectionHead(LocalizedStringKey(month.capitalized))
        ListCard {
            if rows.isEmpty {
                Text("Aún sin movimientos en \(month)").font(.inter(15)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                HStack(spacing: 6) {
                    stat("Ingresos", f.whole(sums.inc), Brand.gain)
                    stat("Gastos", f.whole(sums.exp), .primary)
                    stat("Neto", (net < 0 ? "−" : "") + f.whole(abs(net)), net < 0 ? Brand.loss : Brand.gain)
                }
                .padding(.top, 14).padding(.bottom, 12)
                ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { _, tx in
                    RowDivider()
                    TransactionRow(tx: tx, engine: e, fmt: f)
                }
            }
            RowDivider()
            NavigationLink(value: Route.movimientos) { MoreRow(title: LocalizedStringKey("Ver todo \(month)")) }
                .buttonStyle(.plain)
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(17, .semibold)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: presupuesto y gráficos

    private func budgetCard(_ c: CalcResult, _ f: Fmt) -> some View {
        let left = c.budgetTotal - c.expV
        let pct = c.budgetTotal > 0 ? min(1, max(0, c.expV / c.budgetTotal)) : 0
        let month = Spanish.monthsFull[model.today.month0]
        return Card(title: LocalizedStringKey("Presupuesto de \(month)")) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(f.whole(c.expV)).font(.inter(26, .bold, relativeTo: .title)).tracking(-0.9)
                Text("de \(f.whole(c.budgetTotal))").font(.inter(15, .medium)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.track)
                    Capsule().fill(left < 0 ? Color(hex: "#FF3B30") : Brand.green).frame(width: max(8, geo.size.width * pct))
                }
            }
            .frame(height: 8)
            .padding(.vertical, 4)
            Text(c.budgetTotal > 0 ? (left >= 0 ? "Te quedan \(f.whole(left))" : "Te pasaste por \(f.whole(-left))") : "Aún no defines límites")
                .font(.inter(15)).foregroundStyle(.secondary)
            Button { model.tab = .presupuesto } label: { GreenLink(title: "Ver presupuesto") }
                .buttonStyle(.plain)
        }
    }

    private func expensesCard(_ c: CalcResult, _ f: Fmt) -> some View {
        let month = Spanish.monthsFull[model.today.month0]
        return Card(title: LocalizedStringKey("Gastos de \(month)")) {
            Text(f.whole(c.expense)).font(.inter(30, .bold, relativeTo: .title)).tracking(-1)
            ChartLegend().padding(.top, 2).padding(.bottom, 6)
            MonthsChart(months: c.months, symbol: f.symbol(f.currency).trimmingCharacters(in: .whitespaces))
        }
    }

    private func categoriesCard(_ c: CalcResult, _ f: Fmt) -> some View {
        Card(title: "Por categoría") {
            if c.cats.isEmpty {
                Text("Sin gastos este mes").font(.inter(15)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                CategoryDonut(cats: c.cats, total: f.whole(c.expV), format: { f.whole($0) })
                    .padding(.top, 4)
            }
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
                            Text("\(m.score) de 100").font(.inter(17, .semibold))
                            Text(streakText(m)).font(.inter(15)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
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

    // MARK: listas

    private func accountsList(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> some View {
        ListCard {
            Button { model.tab = .cuentas } label: {
                MoreRow(title: "Débito", detail: "\(Spanish.plural(e.allAccounts.count, "cuenta", "cuentas")) · \(f.whole(c.balance))")
            }
            .buttonStyle(.plain)
            RowDivider()
            Button { model.tab = .cuentas } label: {
                MoreRow(title: "Crédito y préstamos", detail: "\(Spanish.plural(e.allCards.count, "cuenta", "cuentas")) · \(f.whole(c.debt))")
            }
            .buttonStyle(.plain)
        }
    }

    private func moreList(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> some View {
        ListCard {
            NavigationLink(value: Route.movimientos) {
                MoreRow(title: "Movimientos", detail: Spanish.plural(e.allTransactions.count, "registro", "registros"))
            }
            .buttonStyle(.plain)
            RowDivider()
            NavigationLink(value: Route.soon("Servicios y suscripciones")) {
                MoreRow(title: "Servicios y suscripciones", detail: "\(f.exact(c.subsTotal))/mes")
            }
            .buttonStyle(.plain)
        }
    }
}

/// Una fila de movimiento con el estilo de la web: cuadrito de categoría, nota, categoría · fecha · cuenta, monto y flecha.
struct TransactionRow: View {
    let tx: JSONValue
    let engine: Engine
    let fmt: Fmt

    var body: some View {
        let category = Engine.text(tx["category"])
        let amount = Engine.number(tx["amount"])
        let cur = engine.accountCurrency(tx["acc"])
        let isTransfer = category == "Transferencia"
        let isPay = category == "Pago de crédito"
        let isIncome = amount > 0 && !isTransfer && !isPay
        let known = engine.categoryNames.contains(category)
        let shown = isIncome ? "Ingreso" : (known || isPay || isTransfer ? category : "Otros")
        let color: Color = isPay ? Color(hex: "#B98AE6") : (isTransfer ? .gray : Color(hex: engine.categoryColor(shown)))
        let note = Engine.text(tx["note"])
        let date = LocalDate(iso: Engine.text(tx["date"]))
        let many = engine.allAccounts.count + engine.allCards.count > 1
        var sub = isTransfer ? (amount < 0 ? "Salida" : "Entrada") : shown
        if let date { sub += " · " + Spanish.dateShort(date) }
        if many { sub += " · " + engine.accountName(tx["acc"]) }
        return HStack(spacing: 12) {
            Tile(symbol: categorySymbol(shown), color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.isEmpty ? shown : note).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                Text(sub).font(.inter(13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(fmt.signed(amount, cur))
                .font(.inter(16, .medium)).monospacedDigit()
                .foregroundStyle(isIncome ? Brand.gain : Color.primary)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

/// Para las pantallas que aún no están hechas en la versión nativa.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer.fill", description: Text("Esta pantalla llega en la siguiente versión de la app nativa."))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Elegir uno de los perfiles de demostración de la web.
struct DemoPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DemoPerson.all) { p in
                        Button {
                            do { try model.loadDemo(p.id) } catch { model.errorMessage = error.localizedDescription }
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Tile(symbol: p.symbol, color: Color(hex: p.color))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.inter(17, .semibold))
                                    Text(p.city).font(.inter(13)).foregroundStyle(.secondary)
                                    Text(p.line).font(.inter(14)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Elige uno para ver Plata con datos de ejemplo. Tus datos reales siguen guardados aparte.")
                }
            }
            .navigationTitle("Perfiles de demostración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }
}
