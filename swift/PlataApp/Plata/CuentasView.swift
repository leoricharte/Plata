import SwiftUI
import PlataCore

/// La pestaña Cuentas de la web (`renderDeuda`): débito, crédito e intereses.
struct CuentasView: View {
    @Environment(AppModel.self) private var model
    @State private var soon = false
    @State private var showInterest = false
    @State private var showExtra = false

    private static let colors = ["#B98AE6", "#6D8BEA", "#EDB03E", "#F08FB0", "#5CC8C0"]
    private static let icons: [String: String] = [
        "bank": "building.columns", "card": "creditcard", "wallet": "wallet.bifold", "cash": "banknote", "coins": "dollarsign.circle",
        "bag": "bag", "car": "car", "home": "house", "cap": "graduationcap", "plane": "airplane", "heart": "heart", "star": "star",
        "bolt": "bolt", "phone": "iphone", "globe": "globe", "gift": "gift",
    ]
    private static let types = ["checking": "Corriente", "savings": "Ahorros", "cash": "Efectivo"]

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let c = e.calc()
        let cards = e.visibleCards
        let calcByID = Dictionary(c.cards.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let balance = e.totalUSD(e.visibleAccounts)
        let debt = cards.reduce(0.0) { $0 + (calcByID[Engine.identifier($1["id"])]?.ub ?? 0) }
        let limited = cards.filter { Engine.text($0["kind"]) == "card" && Engine.number($0["limit"]) > 0 }
        let creditLimit = limited.reduce(0.0) { $0 + e.usd(Engine.number($1["limit"]), Engine.text($1["cur"])) }
        let creditAvail = limited.reduce(0.0) { $0 + max(0, e.usd(Engine.number($1["limit"]) - Engine.number($1["balance"]), Engine.text($1["cur"]))) }
        let net = balance - debt
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: "Débito, crédito e intereses", title: "Cuentas")

                card {
                    HStack(alignment: .top, spacing: 20) {
                        stat("Disponible (débito)", f.whole(balance))
                        stat("Deuda (crédito)", f.whole(debt), debt > 0 ? Brand.warnText : nil)
                    }
                    RowDivider().padding(.top, 14)
                    HStack(alignment: .top, spacing: 20) {
                        stat("Crédito disponible", f.whole(creditAvail), Brand.gainText)
                        stat("Límite total", f.whole(creditLimit))
                    }
                    .padding(.top, 14)
                    (Text(creditLimit > 0 ? "Usas \(Int(((creditLimit - creditAvail) / creditLimit * 100).rounded()))% de tu crédito · " : "") + Text("Neto: ") +
                     Text((net < 0 ? "−" : "") + f.whole(abs(net))).bold().foregroundColor(net < 0 ? Brand.lossText : .primary))
                        .font(.inter(15)).foregroundStyle(.secondary).padding(.top, 8)
                }
                Text("Los movimientos entran a la cuenta que elijas al añadirlos.")
                    .font(.inter(13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 16)

                sectionHead("Cuentas de débito", pf: "acct")
                debitList(e, f)

                if !cards.isEmpty { debtCard(e, f, c, cards, calcByID) }

                sectionHead("Tarjetas y préstamos", pf: "card")
                creditList(e, f, cards, calcByID)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddMenuButton() } }
        .sheet(isPresented: $showExtra) { ExtraPaySheet() }
        .alert("Llega en la siguiente versión", isPresented: $soon) { Button("Entendido", role: .cancel) {} }
    }

    // MARK: piezas

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.bottom, 14)
    }

    private func stat(_ label: String, _ value: String, _ color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(20, .bold)).tracking(-0.4).foregroundStyle(color ?? Color.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Título de sección con el botón de ordenar a la derecha (`sechead` + `sortbtn`).
    private func sectionHead(_ title: String, pf: String) -> some View {
        let s = model.engine.data["settings"]
        let mode = Engine.text(s?["\(pf)_sort"]).isEmpty ? "name" : Engine.text(s?["\(pf)_sort"])
        let desc = Engine.text(s?["\(pf)_dir"]) == "desc"
        let hide = Engine.flag(s?["\(pf)_hide"])
        let on = mode != "name" || desc || hide
        return HStack {
            Text(title).font(.inter(22, .bold, relativeTo: .title2)).tracking(-0.4)
            Spacer(minLength: 8)
            Menu {
                Picker("Ordenar por", selection: Binding(get: { mode }, set: { model.setSetting("\(pf)_sort", .string($0)) })) {
                    Text("Nombre").tag("name")
                    Text("Monto").tag("amount")
                    if pf == "card" { Text("Fecha de pago").tag("due") }
                }
                Picker("Orden", selection: Binding(get: { desc }, set: { model.setSetting("\(pf)_dir", .string($0 ? "desc" : "asc")) })) {
                    Text("Ascendente").tag(false)
                    Text("Descendente").tag(true)
                }
                Toggle("Ocultar sin uso", isOn: Binding(get: { hide }, set: { model.setSetting("\(pf)_hide", .bool($0)) }))
            } label: {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 14, weight: .semibold)).foregroundStyle(on ? Color.white : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(on ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(Color(.tertiarySystemFill)), in: Circle())
            }
            .accessibilityLabel("Ordenar")
        }
        .padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 12)
    }

    private func addRow(_ title: String, _ action: (() -> Void)? = nil) -> some View {
        Button { if let action { action() } else { soon = true } } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 22))
                Text(title).font(.inter(17))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Brand.green)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// «● 1008» como la web (`l4tag`): punto de 6 pt y los dígitos en el color del texto, no en gris.
    @ViewBuilder private func last4View(_ o: JSONValue) -> some View {
        let l = Engine.text(o["last4"])
        if !l.isEmpty {
            HStack(spacing: 6) {
                Circle().fill(Color.primary).frame(width: 6, height: 6).padding(.top, 2)
                Text(verbatim: l).font(.inter(15))
            }
            .padding(.leading, 8)
        }
    }

    private func sorted(_ list: [JSONValue], kind: String, _ e: Engine, _ calc: [String: CardCalc]) -> [JSONValue] {
        let pf = kind == "card" ? "card" : "acct"
        let s = e.data["settings"]
        let mode = Engine.text(s?["\(pf)_sort"]).isEmpty ? "name" : Engine.text(s?["\(pf)_sort"])
        let dir: Double = Engine.text(s?["\(pf)_dir"]) == "desc" ? -1 : 1
        let hide = Engine.flag(s?["\(pf)_hide"])
        let dayNow = model.today.day, dim = e.calc().dim
        func name(_ a: JSONValue, _ b: JSONValue) -> Int {
            switch Engine.text(a["name"]).localizedCaseInsensitiveCompare(Engine.text(b["name"])) {
            case .orderedAscending: return -1
            case .orderedDescending: return 1
            default: return 0
            }
        }
        func dueIn(_ k: JSONValue) -> Int {
            let d = Int(Engine.number(k["due_day"]))
            return (Engine.number(k["payment"]) > 0 || Engine.number(k["balance"]) > 0) && d > 0 ? ((d - dayNow) % dim + dim) % dim : 999
        }
        let visible = list.filter { !Engine.flag($0["hid"]) }.filter { o in
            !hide || (kind == "card" ? Engine.number(o["balance"]) > 0 : Engine.number(o["balance"]) != 0)
        }
        return visible.enumerated().sorted { A, B in
            let x = A.element, y = B.element
            var r = 0.0
            if mode == "amount" {
                let ax = kind == "card" ? (calc[Engine.identifier(x["id"])]?.ub ?? 0) : e.usd(Engine.number(x["balance"]), Engine.text(x["cur"]))
                let ay = kind == "card" ? (calc[Engine.identifier(y["id"])]?.ub ?? 0) : e.usd(Engine.number(y["balance"]), Engine.text(y["cur"]))
                r = ax != ay ? (ax < ay ? -1 : 1) : Double(name(x, y))
            } else if mode == "due" && kind == "card" {
                let d = dueIn(x) - dueIn(y)
                r = d != 0 ? Double(d) : Double(name(x, y))
            } else {
                r = Double(name(x, y))
            }
            if r == 0 { return A.offset < B.offset }
            return dir * r < 0
        }.map { $0.element }
    }

    private func debitSub(_ a: JSONValue, _ f: Fmt) -> String {
        let cur = Engine.text(a["cur"]), apy = Engine.number(a["apy"])
        var sub = (Self.types[Engine.text(a["type"])] ?? "") + " · " + cur
        if apy > 0 { sub += " · \(apy.formatted())% anual · ≈ \(f.exact(Engine.number(a["balance"]) * apy / 1200, cur))/mes" }
        return sub
    }

    private func tile(_ o: JSONValue, index: Int, debt: Bool, color: String?) -> some View {
        return AccountTile(o: o, color: color ?? (Engine.text(o["color"]).isEmpty ? Self.colors[index % Self.colors.count] : Engine.text(o["color"])), debt: debt)
    }

    // MARK: listas

    private func debitList(_ e: Engine, _ f: Fmt) -> some View {
        let list = sorted(e.allAccounts, kind: "acc", e, [:])
        return ListCard {
            ForEach(Array(list.enumerated()), id: \.offset) { i, a in
                if i > 0 { RowDivider() }
                let cur = Engine.text(a["cur"])
                let sub = debitSub(a, f)
                NavigationLink(value: AcctRef(id: Engine.identifier(a["id"]))) {
                    HStack(spacing: 12) {
                        tile(a, index: i, debt: false, color: nil)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 0) {
                                Text(Engine.text(a["name"])).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                                last4View(a)
                            }
                            Text(sub).font(.inter(13)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(f.whole(Engine.number(a["balance"]), cur)).font(.inter(16, .medium)).monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 64).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeRow(accountSwipe(a, debt: false))
            }
            if !list.isEmpty { hiddenNote(e.allAccounts, kind: "acc", e) }
            addRow("Añadir cuenta de débito") { model.activeSheet = .account(id: nil) }
        }
        .padding(.bottom, 14)
    }

    /// «N ocultas por no estar en uso» (`hiddenNote` de la web); sin ocultas, el separador de siempre.
    @ViewBuilder private func hiddenNote(_ all: [JSONValue], kind: String, _ e: Engine) -> some View {
        let pf = kind == "card" ? "card" : "acct"
        let n = Engine.flag(e.data["settings"]?["\(pf)_hide"])
            ? all.filter { !Engine.flag($0["hid"]) }.filter { kind == "card" ? !(Engine.number($0["balance"]) > 0) : Engine.number($0["balance"]) == 0 }.count : 0
        if n > 0 {
            Text("\(n) \(n == 1 ? "oculta" : "ocultas") por no estar en uso").font(.inter(13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 2)
        } else { RowDivider() }
    }

    private func creditList(_ e: Engine, _ f: Fmt, _ cards: [JSONValue], _ calc: [String: CardCalc]) -> some View {
        let list = sorted(cards, kind: "card", e, calc)
        return ListCard {
            if list.isEmpty { Text("Aún no hay tarjetas ni préstamos").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18) }
            ForEach(Array(list.enumerated()), id: \.offset) { i, k in
                if i > 0 { RowDivider() }
                creditRow(e, f, k, i, calc[Engine.identifier(k["id"])])
            }
            hiddenNote(cards, kind: "card", e)
            addRow("Añadir tarjeta o préstamo") { model.activeSheet = .debt(id: nil) }
        }
        .padding(.bottom, 14)
    }

    private func creditRow(_ e: Engine, _ f: Fmt, _ k: JSONValue, _ i: Int, _ cc: CardCalc?) -> some View {
        let cur = Engine.text(k["cur"])
        let isCard = Engine.text(k["kind"]) == "card"
        let limit = Engine.number(k["limit"]), bal = Engine.number(k["balance"]), apr = Engine.number(k["apr"])
        let util = cc?.util ?? 0
        let color = cc?.color ?? Self.colors[i % Self.colors.count]
        var parts: [String] = []
        if apr > 0 {
            parts.append("\(apr.formatted())% anual")
            if bal > 0 { parts.append("≈ \(f.exact(bal * apr / 1200, cur))/mes") }
        }
        if Engine.number(k["due_day"]) > 0 { parts.append("pago día \(Int(Engine.number(k["due_day"])))") }
        let lines: [ScreenInsights.Line] = e.insightsEnabled
            ? ScreenInsights.debt(k, util: util, primary: e.primaryCurrency, k: Currencies.table[e.primaryCurrency]?.k ?? 1, whole: { f.whole($0) }) : []
        return NavigationLink(value: AcctRef(id: Engine.identifier(k["id"]))) {
            HStack(spacing: 12) {
                tile(k, index: i, debt: true, color: color)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text(Engine.text(k["name"])).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                        last4View(k)
                    }
                    if isCard && limit > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Brand.track)
                                Capsule().fill(Color(hex: color)).frame(width: geo.size.width * min(1, max(0, util / 100)))
                            }
                        }
                        .frame(height: 4).padding(.vertical, 6)
                    }
                    Text(Engine.text(k["kind"]) == "loan" ? "Préstamo" : "\(Int(util.rounded()))% usado · disponible \(f.whole(max(0, limit - bal), cur))")
                        .font(.inter(13)).foregroundStyle(.secondary).padding(.top, isCard && limit > 0 ? 0 : 2)
                    if !parts.isEmpty { Text(parts.joined(separator: " · ")).font(.inter(13)).foregroundStyle(.secondary) }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, l in InsightLineView(line: l) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(f.whole(bal, cur)).font(.inter(16, .medium)).monospacedDigit()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10).frame(minHeight: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeRow(accountSwipe(k, debt: true))
    }

    /// Deslizar una cuenta o tarjeta: añadir movimiento, editar y ocultar o mostrar (`PX_ACTS` · `acct` de la web).
    private func accountSwipe(_ o: JSONValue, debt: Bool) -> [SwipeAction] {
        let id = Engine.identifier(o["id"])
        let hid = Engine.flag(o["hid"])
        return [
            SwipeAction(label: "Añadir", symbol: "plus", color: Brand.accent) { model.showAddTransaction = true },
            SwipeAction(label: "Editar", symbol: "pencil", color: Color(hex: "#4F94F7")) { model.activeSheet = debt ? .debt(id: id) : .account(id: id) },
            SwipeAction(label: hid ? "Mostrar" : "Ocultar", symbol: hid ? "eye" : "eye.slash", color: Color(hex: "#8E8E93")) { model.setAccountHidden(id: id, hidden: !hid) },
        ]
    }

    // MARK: anillo de deuda

    private func debtCard(_ e: Engine, _ f: Fmt, _ c: CalcResult, _ allCards: [JSONValue], _ calc: [String: CardCalc]) -> some View {
        let rkRaw = Engine.text(e.data["settings"]?["ring_kind"])
        let rk = rkRaw == "card" || rkRaw == "loan" ? rkRaw : "all"
        let cards = allCards.filter { rk == "all" || Engine.text($0["kind"]) == rk }
        let ccs = cards.compactMap { calc[Engine.identifier($0["id"])] }
        let total = ccs.reduce(0.0) { $0 + $1.ub }
        let interest = ccs.reduce(0.0) { $0 + $1.interest }
        let items = ccs.filter { $0.ub > 0 }.map { RingChart<AnyView>.Item(value: $0.ub, color: Color(hex: $0.color)) }
        let base = e.payoff(extra: 0, kind: rk == "all" ? nil : rk)
        let title: String
        if total <= 0 { title = "Sin deuda" }
        else if base.months > 0 && base.ok {
            let d = LocalDate(year: model.today.year, month0: model.today.month0 + base.months, day: 1)
            title = "Libre de deuda en \(Spanish.monthsShort[d.month0].capitalized) \(d.year)"
        } else { title = "Tu plan actual no liquida la deuda" }
        let heading = rk == "card" ? "DEUDA EN TARJETAS" : (rk == "loan" ? "DEUDA EN PRÉSTAMOS" : "DEUDA TOTAL")
        return card {
          ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text("Sin deuda registrada").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                RingChart(items: items, radius: 126, lineWidth: 30, gap: 6, box: 300,
                          arcTop: .init(text: Tr.t("\(heading) · \(cards.count) \(cards.count == 1 ? "CUENTA" : "CUENTAS")"), radius: 88),
                          arcBottom: .init(text: Tr.t("INTERESES ESTIMADOS AL MES"), radius: 104)) {
                    AnyView(
                        VStack(spacing: 0) {
                            Text(f.whole(total)).font(.inter(46, .bold)).tracking(-1.6).lineLimit(1).minimumScaleFactor(0.5)
                            Text(f.exact(interest)).font(.inter(22, .semibold)).foregroundStyle(Brand.warnText)
                        }
                        .padding(.horizontal, 56)
                    )
                }
                .frame(maxWidth: 300).frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.inter(17, .semibold))
                Text("Con tus pagos actuales. Mira cuánto cambia pagando un poco más.").font(.inter(15)).foregroundStyle(.secondary).padding(.top, 2).padding(.bottom, 6)
                linkRow(showInterest ? "Ocultar detalle de intereses" : "Ver detalle de intereses", symbol: "info.circle") { showInterest.toggle() }
                if showInterest {
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.offset) { _, k in
                            HStack {
                                Text(Engine.text(k["name"])).font(.inter(15)) + Text(" · \(Engine.number(k["apr"]).formatted())% anual").font(.inter(15)).foregroundColor(.secondary)
                                Spacer(minLength: 8)
                                Text("\(f.exact(calc[Engine.identifier(k["id"])]?.interest ?? 0))/mes").font(.inter(15, .bold))
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4).padding(.bottom, 8)
                }
                linkRow("Simular pago extra", symbol: "slider.horizontal.3") { showExtra = true }
            }
            .padding(.top, 10)
            }
            ringFilter(rk)
              .padding(.top, -4).padding(.trailing, -4)
          }
        }
    }

    /// El filtro del anillo de deuda (`sortmenu:ring`): todo, solo tarjetas o solo préstamos.
    private func ringFilter(_ rk: String) -> some View {
        Menu {
            Picker("Mostrar", selection: Binding(get: { rk }, set: { model.setSetting("ring_kind", .string($0)) })) {
                Text("Tarjetas y préstamos").tag("all")
                Text("Solo tarjetas").tag("card")
                Text("Solo préstamos").tag("loan")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(rk != "all" ? Color.white : Color.secondary)
                .frame(width: 30, height: 30)
                .background(rk != "all" ? AnyShapeStyle(Brand.accent) : AnyShapeStyle(Color(.tertiarySystemFill)), in: Circle())
        }
        .accessibilityLabel("Filtrar")
    }

    private func linkRow(_ title: String, symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 20)).frame(width: 26)
                Text(title).font(.inter(17))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Brand.green)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
