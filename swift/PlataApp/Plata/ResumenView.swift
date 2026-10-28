import SwiftUI
import PlataCore

/// Pantallas a las que se llega desde el Resumen.
enum Route: Hashable {
    case movimientos
    case month
    case tx(String)
    case ajustes
    case soon(String)
    case profile
    case profileEdit
    case credits
    case insights(mk: String, half: Bool)
    case sub(String)
}

struct ResumenView: View {
    @Environment(AppModel.self) private var model
    @State private var pickingDemo = false

    var body: some View {
        let e = model.engine
        let c = e.calc()
        let f = model.fmt
        @Bindable var nav = model
        NavigationStack(path: $nav.path) {
            ScrollView {
                VStack(spacing: 14) {
                    titleBlock(e)
                    CloudStrip()
                    idleBanner(e)
                    if !hasData(e) { startCard }
                    KPIGrid(items: kpis(e, c, f))
                    nextIncomeCard(e, f)
                    nextExpenseCard(e, f)
                    payCard(e)
                    subscriptionsCard(e, f)
                    monthSection(e, c, f)
                    if hasData(e) { InsightsBanner(bottom: false) }
                    budgetCard(c, f)
                    expensesCard(c, f)
                    categoriesCard(c, f)
                    SectionHead("Cuentas", gap: 0)
                    accountsList(e, c, f)
                    SectionHead("Más", gap: 0)
                    moreList(e, c, f)
                    if hasData(e) { InsightsBanner(bottom: true) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { rootToolbar }
            .task(id: model.changes) { model.syncInsightsState() }
            .routeDestinations()
            .sheet(isPresented: $pickingDemo) { DemoPickerSheet() }
        }
    }

    // MARK: encabezado

    @ToolbarContentBuilder
    private var rootToolbar: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarLeading) { brand }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { brand }
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: Route.ajustes) { Image(systemName: "gearshape") }
                .accessibilityLabel("Ajustes")
        }
        ToolbarItem(placement: .topBarTrailing) { AddMenuButton() }
    }

    private var brand: some View {
        HStack(spacing: 8) {
            Image("PlataLogo").resizable().scaledToFit().frame(width: 96).accessibilityLabel("Plata")
            BetaPill()
        }
        .fixedSize()
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
            startRow("plus.circle.fill", "Añadir un movimiento") { model.showAddTransaction = true }
            startRow("folder.badge.plus", "Importar datos de banco") { model.showImport = true }
            startRow("folder.fill", "Cargar mi archivo de perfil") { model.path.append(.ajustes) }
            startRow("info.circle.fill", "Ver con datos de ejemplo") { pickingDemo = true }
        }
    }

    private func startRow(_ symbol: String, _ title: String, _ action: @escaping () -> Void) -> some View {
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
                  action: { model.path.append(.month) }),
            .init(id: "saved", title: "Ahorro total", value: f.whole(c.saved), detail: Spanish.plural(goals, "meta", "metas"), link: "Ver ahorro",
                  action: { model.tab = .ahorro }),
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
                    Text("+" + f.whole(next.amount, cur)).font(.inter(16, .semibold)).monospacedDigit().foregroundStyle(Brand.gainText)
                }
                .padding(.top, 2)
                if pending { confirmButton("Confirmar ingreso") { model.activeSheet = .confirm(kind: "in", id: next.id, pick: true) } }
            }
            .contentShape(Rectangle())
            .onTapGesture { if pending { model.activeSheet = .confirm(kind: "in", id: next.id, pick: true) } }
        }
    }

    /// El botón negro de las tarjetas «por confirmar» (`.primary` de 48 pt de la web).
    private func confirmButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.inter(16, .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color(hex: "#111111"), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private func whenText(day: LocalDate, days: Int, pending: Bool) -> String {
        if pending { return days < 0 ? "esperado hace \(-days) \(days == -1 ? "día" : "días")" : "esperado hoy" }
        let label = Spanish.dateShort(day)
        return days > 0 ? "\(label) · en \(days) \(days == 1 ? "día" : "días")" : label
    }

    @ViewBuilder
    private func idleBanner(_ e: Engine) -> some View {
        if let gap = e.daysSinceLastTransaction(), gap >= 2 {
            Button { model.showAddTransaction = true } label: {
                HStack(spacing: 10) {
                    Text("Llevas \(Spanish.plural(gap, "día", "días")) sin registrar movimientos")
                        .font(.inter(14)).foregroundStyle(Brand.gainTextStrong).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text("Añadir").font(.inter(14, .semibold)).foregroundStyle(Brand.gainText)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Brand.gainBg, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func nextExpenseCard(_ e: Engine, _ f: Fmt) -> some View {
        if let x = e.nextExpense(), let day = LocalDate(iso: Engine.text(x["date"])) {
            let due = e.pendingItems().contains { $0.kind == "out" }
            let days = day.days - model.today.days
            let cur = e.accountCurrency(x["acc"])
            let raw = Engine.text(x["cat"])
            let cat = e.categoryNames.contains(raw) ? raw : "Otros"
            Card(title: due ? "Gasto por confirmar" : "Próximo gasto") {
                HStack(spacing: 12) {
                    Tile(symbol: e.catSymbol(cat), color: Color(hex: e.categoryColor(cat)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Engine.text(x["name"])).font(.inter(17, .semibold)).tracking(-0.3).lineLimit(1)
                        Text(expenseWhen(day: day, days: days, due: due)).font(.inter(14)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("−" + f.whole(Engine.number(x["amount"]), cur)).font(.inter(16, .semibold)).monospacedDigit()
                }
                .padding(.top, 2)
                if due { confirmButton("Confirmar gasto") { model.activeSheet = .confirm(kind: "out", id: Engine.identifier(x["id"]), pick: true) } }
            }
            .contentShape(Rectangle())
            .onTapGesture { if due { model.activeSheet = .confirm(kind: "out", id: Engine.identifier(x["id"]), pick: true) } }
        }
    }

    private func expenseWhen(day: LocalDate, days: Int, due: Bool) -> String {
        if due { return days < 0 ? "previsto hace \(-days) \(days == -1 ? "día" : "días")" : "previsto hoy" }
        let label = Spanish.dateShort(day)
        return days > 0 ? "\(label) · en \(days) \(days == 1 ? "día" : "días")" : label
    }

    @ViewBuilder
    private func payCard(_ e: Engine) -> some View {
        if let item = e.pendingItems().first(where: { $0.kind == "pay" }),
           let card = e.allCards.first(where: { Engine.identifier($0["id"]) == item.id }),
           let day = LocalDate(iso: item.date) {
            let late = model.today.days - day.days
            let hex = Engine.text(card["color"])
            Card(title: "Pago por confirmar") {
                HStack(spacing: 12) {
                    AccountTile(o: card, color: hex.isEmpty ? "#B98AE6" : hex, debt: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Engine.text(card["name"])).font(.inter(17, .semibold)).tracking(-0.3).lineLimit(1)
                        Text("día de pago " + (late <= 0 ? "hoy" : late == 1 ? "ayer" : "hace \(late) días")).font(.inter(14)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
                confirmButton("Confirmar pago") { model.activeSheet = .confirm(kind: "pay", id: item.id, pick: true) }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.activeSheet = .confirm(kind: "pay", id: item.id, pick: true) }
        }
    }

    @ViewBuilder
    private func subscriptionsCard(_ e: Engine, _ f: Fmt) -> some View {
        let events = e.upcomingSubscriptions()
        if !events.isEmpty {
            let subs = e.data["subs"]?.arrayValue ?? []
            let colors = ["#B98AE6", "#6D8BEA", "#EDB03E", "#F08FB0", "#5CC8C0"]
            Card(title: "Próximos servicios y suscripciones") {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { i, ev in
                        let idx = subs.firstIndex(where: { Engine.identifier($0["id"]) == (ev.srcId ?? "") })
                        let sub = idx.map { subs[$0] }
                        let dd = ev.date.days - model.today.days
                        let accId = sub?["acc"]
                        let accName: String = accId.map { e.accountName($0) } ?? ""
                        let row = HStack(spacing: 12) {
                            SubTile(name: ev.name, fallback: Color(hex: colors[(idx ?? 0) % colors.count]))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.name).font(.inter(17, .semibold)).tracking(-0.3).lineLimit(1)
                                Text((dd <= 0 ? "hoy" : "\(Spanish.dateShort(ev.date)) · en \(Spanish.plural(dd, "día", "días"))") + (accName.isEmpty ? "" : " · " + accName))
                                    .font(.inter(14)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("−" + f.whole(abs(ev.a0), ev.cur ?? f.currency)).font(.inter(16, .semibold)).monospacedDigit()
                        }
                        .padding(.top, i == 0 ? 2 : 10)
                        .padding(.bottom, i == events.count - 1 ? 0 : 10)
                        if let sid = ev.srcId, sub != nil {
                            NavigationLink(value: Route.sub(sid)) { row.contentShape(Rectangle()) }.buttonStyle(.plain)
                        } else { row }
                    }
                }
            }
        }
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
        MonthHeader(month0: model.today.month0, year: model.today.year, hemi: Engine.text(e.data["settings"]?["hemi"]))
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
                    NavigationLink(value: Route.tx(Engine.identifier(tx["id"]))) { TransactionRow(tx: tx, engine: e, fmt: f) }
                        .buttonStyle(.plain)
                }
            }
            RowDivider()
            NavigationLink(value: Route.month) { MoreRow(title: ("Ver todo \(month)")) }
                .buttonStyle(.plain)
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
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
        return Card(title: ("Presupuesto de \(month)")) {
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
        return Card(title: ("Gastos de \(month)")) {
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
            Button { model.tab = .presupuesto } label: {
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

    private static let subColors = ["#B98AE6", "#6D8BEA", "#EDB03E", "#F08FB0", "#5CC8C0"]

    /// La suscripción a la que pertenece un gasto (`txSub`): por el id guardado o porque el nombre coincide.
    private func subscription() -> (String, Int)? {
        let subs = engine.data["subs"]?.arrayValue ?? []
        let linked = Engine.identifier(tx["sub"])
        if !linked.isEmpty, let i = subs.firstIndex(where: { Engine.identifier($0["id"]) == linked }) {
            return (Engine.text(subs[i]["name"]), i)
        }
        let note = Brands.norm(Engine.text(tx["note"])).trimmingCharacters(in: .whitespaces)
        if note.isEmpty { return nil }
        if let i = subs.firstIndex(where: { Brands.norm(Engine.text($0["name"])).trimmingCharacters(in: .whitespaces) == note }) {
            return (Engine.text(subs[i]["name"]), i)
        }
        return nil
    }

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
        let subPick = amount < 0 && !isPay ? subscription() : nil
        var sub = isTransfer ? (amount < 0 ? "Salida" : "Entrada") : (subPick != nil ? "Suscripción" : shown)
        if let date { sub += " · \(date.day) \(Spanish.monthsShort[date.month0])" }
        if many { sub += " · " + engine.accountName(tx["acc"]) }
        return HStack(spacing: 12) {
            if let (name, i) = subPick {
                SubTile(name: name, fallback: Color(hex: Self.subColors[i % Self.subColors.count]))
            } else {
                Tile(symbol: engine.catSymbol(shown), color: color)
            }
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
        ContentUnavailableView {
            Label(title, systemImage: "hammer.fill")
        } description: {
            Text("Esta pantalla llega en la siguiente versión de la app nativa.")
        }
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

/// Las pantallas a las que lleva cada `Route` (también las usan las pestañas que empujan un movimiento).
struct RouteDestination: View {
    let route: Route
    var body: some View {
        switch route {
        case .movimientos: MovimientosView()
        case .month: MonthView()
        case .tx(let id): TransactionDetailView(id: id)
        case .ajustes: AjustesView()
        case .profile: ProfileView()
        case .profileEdit: ProfileSettingsView()
        case .credits: CreditsView()
        case .insights(let mk, let half): InsightsView(mk: mk, half: half)
        case .sub(let id): SubDetailView(id: id)
        case .soon(let title): ComingSoonView(title: title)
        }
    }
}

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { RouteDestination(route: $0).toolbarVisibility(.hidden, for: .tabBar) }
    }
}
