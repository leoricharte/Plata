import SwiftUI
import PlataCore

/// La pestaña Presupuesto de la web (`renderPresupuesto`).
struct PresupuestoView: View {
    @Environment(AppModel.self) private var model
    @State private var soon = false

    private static let subColors = ["#B98AE6", "#6D8BEA", "#EDB03E", "#F08FB0", "#5CC8C0"]

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let c = e.calc()
        let set = model.viewSet
        let act = e.activeSet()
        let limits = e.budgetLimits(set)
        let bt = e.categoryNames.reduce(0.0) { $0 + (limits[$1] ?? 0) }
        let left = bt - c.expV
        let dl = c.dim - model.today.day + 1
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: bt > 0 ? ("Quedan \(dl) \(dl == 1 ? "día" : "días") del mes") : "Planifica tu mes", title: "Presupuesto")

                setCard(set, active: set == act)
                ringCard(e, c, f, bt, left, dl, preview: set != act)

                SectionHead("Límites por categoría").padding(.top, 14)
                ListCard {
                    ForEach(Array(e.categoryNames.enumerated()), id: \.offset) { i, k in
                        if i > 0 { RowDivider() }
                        categoryRow(e, c, f, k, limit: limits[k] ?? 0)
                    }
                    RowDivider()
                    addRow("Añadir categoría") { model.activeSheet = .category(name: nil) }
                }

                SectionHead("Servicios y suscripciones").padding(.top, 14)
                subsCard(e, c, f)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .syncRefresh()
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddMenuButton() } }
        .alert("Llega en la siguiente versión", isPresented: $soon) { Button("Entendido", role: .cancel) {} }
    }

    // MARK: piezas

    private func setCard(_ set: JSONValue?, active: Bool) -> some View {
        let name = set.map { Engine.text($0["name"]) } ?? "Presupuesto base"
        var sub = "Se usa cuando no hay otro set activo"
        if let set, let a = LocalDate(iso: Engine.text(set["from"])), let b = LocalDate(iso: Engine.text(set["to"])) {
            sub = "Del \(a.day) \(Spanish.monthsShort[a.month0]) al \(b.day) \(Spanish.monthsShort[b.month0])"
        }
        return Button { model.activeSheet = .budgetSets } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Set de presupuesto").font(.inter(12)).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(name).font(.inter(17, .semibold)).lineLimit(1)
                        if active {
                            Text("Activo").font(.inter(13, .semibold)).foregroundStyle(Brand.gainTextStrong)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Brand.gainBg, in: Capsule())
                                .padding(.leading, 4)
                        }
                    }
                    Text(sub).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.bottom, 14)
        }
        .buttonStyle(.plain)
    }

    private func ringCard(_ e: Engine, _ c: CalcResult, _ f: Fmt, _ bt: Double, _ left: Double, _ dl: Int, preview: Bool = false) -> some View {
        let items = c.cats.map { RingChart<AnyView>.Item(value: $0.v, color: Color(hex: $0.color)) }
        // con presupuesto activo: los aros del Apple Watch (hasta 4 categorías, las de más gasto)
        let limits = e.budgetLimits(model.viewSet)
        let rings: [WatchCat] = e.categoryNames.compactMap { k in
            guard let lim = limits[k], lim > 0 else { return nil }
            return WatchCat(name: Tr.t(k), spent: c.catTot[k] ?? 0, limit: lim, color: e.categoryColor(k))
        }.sorted { $0.spent > $1.spent }.prefix(4).map { $0 }
        let symbols = Dictionary(e.categoryNames.map { (Tr.t($0), e.catSymbol($0)) }, uniquingKeysWith: { a, _ in a })
        return VStack(spacing: 0) {
            if !preview && bt > 0 && !rings.isEmpty {
                BudgetRings(cats: rings, symbols: symbols) {
                    VStack(spacing: 0) {
                        Text(left >= 0 ? "Quedan" : "Te pasaste").font(.inter(12)).foregroundStyle(.secondary)
                        Text(f.whole(abs(left))).font(.inter(24, .bold)).tracking(-0.7)
                            .foregroundStyle(left >= 0 ? Color.primary : Brand.lossText).lineLimit(1).minimumScaleFactor(0.5)
                        Text("de \(f.whole(bt))").font(.inter(11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: 280)
            } else {
            RingChart(items: items) {
                AnyView(
                    VStack(spacing: 0) {
                        if preview {
                            Text("Límite del set").font(.inter(13)).foregroundStyle(.secondary)
                            Text(f.whole(bt)).font(.inter(30, .bold)).tracking(-0.9).lineLimit(1).minimumScaleFactor(0.5)
                        } else if bt > 0 {
                            Text(left >= 0 ? "Quedan" : "Te pasaste").font(.inter(13)).foregroundStyle(.secondary)
                            Text(f.whole(abs(left))).font(.inter(30, .bold)).tracking(-0.9)
                                .foregroundStyle(left >= 0 ? Color.primary : Brand.lossText).lineLimit(1).minimumScaleFactor(0.5)
                            Text("de \(f.whole(bt))").font(.inter(12)).foregroundStyle(.secondary)
                        } else {
                            Text("Gastado").font(.inter(13)).foregroundStyle(.secondary)
                            Text(f.whole(c.expV)).font(.inter(30, .bold)).tracking(-0.9).lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }
                    .padding(.horizontal, 52)
                )
            }
            .frame(maxWidth: 240)
            }
            if bt > 0 && left > 0 {
                (Text("Puedes gastar unos ") + Text(f.whole(left / Double(max(dl, 1)))).bold().foregroundColor(.primary) + Text(" al día"))
                    .font(.inter(15)).foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.bottom, 14)
    }

    private func categoryRow(_ e: Engine, _ c: CalcResult, _ f: Fmt, _ k: String, limit lim: Double) -> some View {
        let sp = c.catTot[k] ?? 0
        let pct = lim > 0 ? sp / lim : 0
        let over = lim > 0 && sp > lim
        let base = Color(hex: e.categoryColor(k))
        let bar: Color = over ? Color(hex: "#FF3B30") : (pct > 0.85 ? Color(hex: "#FF9F0A") : base)
        let insight = budgetInsight(k, sp, lim, c, f)
        return Button { model.activeSheet = .category(name: k) } label: {
            HStack(spacing: 12) {
                CategoryTile(engine: model.engine, name: k, color: base)
                VStack(alignment: .leading, spacing: 0) {
                    Text(k).font(.inter(16, .semibold)).tracking(-0.3)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.track)
                            Capsule().fill(bar).frame(width: geo.size.width * min(1, max(0, pct)))
                        }
                    }
                    .frame(height: 4).padding(.vertical, 6)
                    Text(lim > 0 ? "\(f.whole(sp)) de \(f.whole(lim))" : "\(f.whole(sp)) · sin límite").font(.inter(13)).foregroundStyle(.secondary)
                    if let insight { Text(insight.0).font(.inter(12, .medium)).foregroundStyle(insight.1).padding(.top, 4) }
                }
                Spacer(minLength: 8)
                if lim > 0 {
                    Text(f.whole(lim - sp)).font(.inter(16, .medium)).monospacedDigit().foregroundStyle(over ? Brand.lossText : Color.primary)
                } else {
                    Text("Definir").font(.inter(15)).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeRow([SwipeAction(label: "Editar", symbol: "pencil", color: Color(hex: "#4F94F7")) { model.activeSheet = .category(name: k) }]
            + (k == "Otros" ? [] : [SwipeAction(label: "Eliminar", symbol: "trash", color: Color(hex: "#EB5757"), confirm: "¿Eliminar la categoría «\(k)»?") { try? model.deleteCategory(name: k) }]))
    }

    /// Los avisos bajo cada límite (`budgetInsight` de la web).
    private func budgetInsight(_ k: String, _ sp: Double, _ lim: Double, _ c: CalcResult, _ f: Fmt) -> (String, Color)? {
        guard model.engine.insightsEnabled, lim > 0 else { return nil }
        let d = Double(model.today.day), dim = Double(c.dim), pct = sp / lim
        if sp - lim >= 0.5 { return ("Superaste el límite por \(f.whole(sp - lim)).", Brand.lossText) }
        if k == "Alquiler" || sp > lim { return nil }
        if pct >= 0.8 && d < dim { return ("Vas rápido: llevas el \(Int((pct * 100).rounded()))% y va el día \(Int(d)) de \(Int(dim)).", Color(hex: "#B96A00")) }
        let proj = d > 0 ? sp / d * dim : 0
        if pct >= 0.4 && d >= 5 && proj > lim * 1.1 { return ("A este ritmo cerrarías pasándote por unos \(f.whole(proj - lim)).", Color(hex: "#B96A00")) }
        return nil
    }

    private func subsCard(_ e: Engine, _ c: CalcResult, _ f: Fmt) -> some View {
        let subs = e.subscriptionList.sorted { Engine.number($0["day"]) < Engine.number($1["day"]) }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(f.exact(c.subsTotal)).font(.inter(28, .bold)).tracking(-1)
                Text("al mes").font(.inter(15, .medium)).foregroundStyle(.secondary)
            }
            .padding(.top, 2).padding(.bottom, 4)
            Text("\(f.exact(c.subsTotal * 12)) al año").font(.inter(15)).foregroundStyle(.secondary).padding(.bottom, 4)
            ForEach(Array(subs.enumerated()), id: \.offset) { i, s in
                RowDivider()
                NavigationLink(value: Route.sub(Engine.identifier(s["id"]))) {
                    HStack(spacing: 12) {
                        SubTile(name: Engine.text(s["name"]), fallback: Color(hex: Self.subColors[i % Self.subColors.count]))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Engine.text(s["name"])).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                            Text("Día \(Int(Engine.number(s["day"]))) de cada mes").font(.inter(13)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(f.exact(Engine.number(s["amount"]), Engine.text(s["cur"]))).font(.inter(16, .medium)).monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .frame(minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            RowDivider()
            addRow("Añadir servicio o suscripción") { model.activeSheet = .sub(id: nil) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
}

/// Los aros concéntricos del Apple Watch, más grandes: hasta 4 categorías (las de más gasto), cada una con su icono en la punta y su nombre curvado.
/// El centro queda libre para el «Quedan …». Se dibuja en 280 pt y se escala al ancho disponible.
struct BudgetRings<Center: View>: View {
    let cats: [WatchCat]
    let symbols: [String: String]
    @ViewBuilder var center: () -> Center

    private let canvas: CGFloat = 280, width: CGFloat = 19, gap: CGFloat = 3

    var body: some View {
        let outer = canvas / 2
        let hole = (outer - CGFloat(cats.count) * (width + gap) + gap) * 2
        GeometryReader { geo in
            let k = min(1, geo.size.width / canvas)
            ZStack {
                ForEach(Array(cats.enumerated()), id: \.offset) { i, c in
                    let radius = outer - width / 2 - CGFloat(i) * (width + gap)
                    CategoryRing(cat: c, symbol: symbols[c.name] ?? "circle.fill", width: width, radius: radius, fontSize: 10.5)
                        .frame(width: radius * 2, height: radius * 2)
                }
                center().frame(width: max(60, hole - 14))
            }
            .frame(width: canvas, height: canvas)
            .scaleEffect(k)
            .frame(width: geo.size.width, height: canvas * k)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
