import SwiftUI
import PlataCore

/// A qué cuenta, tarjeta o meta lleva una fila de Cuentas o Ahorro.
struct AcctRef: Hashable { let id: String }

/// El detalle de una cuenta, tarjeta/préstamo o meta (`renderCuenta` de la web).
struct AccountDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var adding = false

    private enum Kind { case account, card, saving }

    var body: some View {
        let e = model.engine
        if let o = e.allAccounts.first(where: { Engine.identifier($0["id"]) == id }) {
            content(o, .account, e)
        } else if let o = e.allCards.first(where: { Engine.identifier($0["id"]) == id }) {
            content(o, .card, e)
        } else if let o = (e.data["savings"]?.arrayValue ?? []).first(where: { Engine.identifier($0["id"]) == id }) {
            content(o, .saving, e)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ o: JSONValue, _ kind: Kind, _ e: Engine) -> some View {
        let f = model.fmt
        let cur = Engine.text(o["cur"])
        let hidden = Engine.flag(o["hid"])
        return ScrollView {
            VStack(spacing: 0) {
                hero(o, kind, e, f, cur)
                switch kind {
                case .account: accountInfo(o, e, f, cur)
                case .card: cardInfo(o, e, f, cur)
                case .saving: savingInfo(o, e, f, cur)
                }
                if kind == .saving { savingTail(o, e, f, cur) } else { movements(o, e, f) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if kind != .saving {
                    Button { model.setAccountHidden(id: id, hidden: !hidden) } label: { Image(systemName: hidden ? "eye.slash" : "eye") }
                        .accessibilityLabel(hidden ? "Mostrar en el resumen" : "Ocultar del resumen")
                }
                Button { model.activeSheet = kind == .account ? .account(id: id) : (kind == .card ? .debt(id: id) : .saving(id: id)) } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Editar")
            }
        }
        .sheet(isPresented: $adding) { TransactionSheet(mode: .new, presetAccount: id) }
    }

    // MARK: cabecera

    private func hero(_ o: JSONValue, _ kind: Kind, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let name = Engine.text(o["name"])
        let l4 = Engine.text(o["last4"])
        let l4tag = l4.isEmpty ? "" : " · ● " + l4
        let balance = Engine.number(o["balance"])
        let sub: String
        let label: String
        switch kind {
        case .account:
            sub = Self.accountType(Engine.text(o["type"])) + " · " + cur + l4tag; label = "Saldo"
        case .card:
            sub = (Engine.text(o["kind"]) == "loan" ? "Préstamo" : "Tarjeta de crédito") + " · " + cur + l4tag; label = "Saldo adeudado"
        case .saving:
            sub = "Meta de ahorro · " + cur; label = "Ahorrado"
        }
        return VStack(spacing: 0) {
            heroTile(o, kind, e).padding(.top, 4)
            Text(name).font(.inter(28, .bold, relativeTo: .title)).tracking(-0.8).multilineTextAlignment(.center).padding(.top, 10)
            Text(sub).font(.inter(15)).foregroundStyle(.secondary).padding(.top, 2)
            Text(label).font(.inter(15)).foregroundStyle(.secondary).padding(.top, 14)
            Text(f.exact(balance, cur)).font(.inter(40, .bold, relativeTo: .largeTitle)).tracking(-1.4).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func heroTile(_ o: JSONValue, _ kind: Kind, _ e: Engine) -> some View {
        switch kind {
        case .saving:
            let color = e.calc().savings.first(where: { $0.id == id })?.color ?? "#1A9D63"
            Tile(symbol: iconSymbol(Engine.text(o["icon"])) ?? "leaf.fill", color: Color(hex: color), size: 64)
        default:
            let hex = Engine.text(o["color"])
            AccountTile(o: o, color: hex.isEmpty ? (kind == .card ? "#B98AE6" : "#22B573") : hex, debt: kind == .card, size: 64)
        }
    }

    private static func accountType(_ t: String) -> String {
        switch t {
        case "checking": return "Cuenta corriente"
        case "savings": return "Cuenta de ahorro"
        case "cash": return "Efectivo"
        default: return t.isEmpty ? "Cuenta" : t.capitalized
        }
    }

    // MARK: tarjetas de datos

    private func box<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.bottom, 14)
    }

    private func stat(_ label: String, _ value: String, _ color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(20, .bold)).tracking(-0.4).foregroundStyle(color ?? Color.primary).lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pair(_ a: (String, String, Color?), _ b: (String, String, Color?)?, top: CGFloat = 0) -> some View {
        HStack(alignment: .top, spacing: 20) {
            stat(a.0, a.1, a.2)
            if let b { stat(b.0, b.1, b.2) } else { Spacer(minLength: 0).frame(maxWidth: .infinity) }
        }
        .padding(.top, top)
    }

    /// Lo que entró y salió de la cuenta este mes (`c.monthTx` de la web).
    private func monthFlow(_ e: Engine) -> (inn: Double, out: Double) {
        let c = e.calc()
        let mine = Set(c.monthTxIds)
        let first = Engine.text(e.allAccounts.first?["id"])
        var inn = 0.0, out = 0.0
        for t in e.allTransactions where mine.contains(Engine.identifier(t["id"])) {
            let acc = Engine.text(t["acc"]).isEmpty ? first : Engine.text(t["acc"])
            guard acc == id else { continue }
            let a = Engine.number(t["amount"])
            if a > 0 { inn += a } else { out -= a }
        }
        return (inn, out)
    }

    private func accountInfo(_ a: JSONValue, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let flow = monthFlow(e)
        let apy = Engine.number(a["apy"]), bal = Engine.number(a["balance"])
        return box {
            pair(("Entró este mes", "+" + f.exact(flow.inn, cur), Brand.gainText), ("Salió este mes", f.exact(flow.out, cur), nil))
            pair(("Rendimiento anual", apy > 0 ? Engine.plainNumber(apy) + "%" : "—", nil),
                 ("Ganancia al mes", apy > 0 ? "≈ " + f.exact(bal * apy / 1200, cur) : "—", nil), top: 14)
            interestStats(a, e, f, cur)
        }
    }

    @ViewBuilder
    private func interestStats(_ a: JSONValue, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let s = e.interestStats(accountId: id, accountType: Engine.text(a["type"]), balance: Engine.number(a["balance"]))
        if let s {
            pair(("Intereses del año", s.hasAny ? "+" + f.exact(s.year, cur) : "—", s.hasAny ? Brand.gainText : nil),
                 ("Rendimiento real", s.real.map { "≈ " + Engine.plainNumber($0) + "%" } ?? "—", nil), top: 14)
        }
    }

    @ViewBuilder
    private func cardInfo(_ k: JSONValue, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let loan = Engine.text(k["kind"]) == "loan"
        let limit = Engine.number(k["limit"]), bal = Engine.number(k["balance"]), apr = Engine.number(k["apr"])
        let pay = Engine.number(k["payment"]), due = Int(Engine.number(k["due_day"]))
        let util = limit > 0 ? min(100, Int((bal / limit * 100).rounded())) : 0
        let flow = monthFlow(e)
        let col = Color(hex: Engine.text(k["color"]).isEmpty ? "#B98AE6" : Engine.text(k["color"]))
        if !loan && limit > 0 {
            box {
                bar(Double(util), col)
                Text("\(util)% usado · disponible \(f.exact(max(0, limit - bal), cur)) de \(f.exact(limit, cur))").font(.inter(15)).foregroundStyle(.secondary)
            }
        }
        box {
            pair(("Interés anual", Engine.plainNumber(apr) + "%", nil), ("Interés al mes", "≈ " + f.exact(bal * apr / 1200, cur), Brand.warnText))
            pair(("Pago mensual", pay > 0 ? f.exact(pay, cur) : "—", nil), ("Día de pago", due > 0 ? "Día \(due)" : "—", nil), top: 14)
            pair(("Gastado este mes", f.exact(flow.out, cur), nil), nil, top: 14)
            autoRow(k, due)
        }
    }

    private func autoRow(_ k: JSONValue, _ due: Int) -> some View {
        let ok = due > 0
        let on = Engine.flag(k["auto"]) && ok
        return VStack(spacing: 0) {
            RowDivider().padding(.top, 14)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pago esperado").font(.inter(17))
                    Text(on ? "El día \(due) de cada mes te preguntamos cuánto pagaste."
                            : (ok ? "Te recordamos el día \(due) para que registres tu pago." : "Añade el día de pago de la tarjeta para activarlo."))
                        .font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(get: { on }, set: { _ in model.toggleCardAuto(id: k["id"] ?? .null) }))
                    .labelsHidden().tint(Brand.accent).disabled(!on && !ok)
            }
            .padding(.top, 14)
        }
    }

    private func bar(_ pct: Double, _ color: Color) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(color).frame(width: g.size.width * pct / 100)
            }
        }
        .frame(height: 8).padding(.bottom, 8)
    }

    // MARK: metas

    @ViewBuilder
    private func savingInfo(_ sv: JSONValue, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let g = Engine.savingGoal(sv)
        let monthly = Engine.number(sv["monthly"])
        let color = Color(hex: e.calc().savings.first(where: { $0.id == id })?.color ?? "#1A9D63")
        box {
            if g.goal > 0 {
                bar(g.pct, color)
                Text("\(Int(g.pct.rounded()))% de \(f.exact(g.goal, cur))").font(.inter(15)).foregroundStyle(.secondary)
            } else {
                Text("Esta meta no tiene monto objetivo.").font(.inter(15)).foregroundStyle(.secondary)
            }
        }
        box {
            pair(("Falta", g.goal > 0 ? f.exact(g.rem, cur) : "—", nil), ("Aporte mensual", monthly > 0 ? f.exact(monthly, cur) : "—", nil))
            pair(("Se llena en", g.done ? "¡Cumplida!" : (g.mo > 0 ? Spanish.plural(g.mo, "mes", "meses") : "—"), nil),
                 ("Fecha estimada", g.done || g.mo == 0 ? "—" : monthYear(g.mo), g.done ? nil : Brand.gainText), top: 14)
        }
        SectionHead("Cuándo se llena")
        box { SavingChart(balance: Engine.number(sv["balance"]), goal: g.goal, monthly: monthly, months: g.mo, done: g.done, color: color, cur: cur, fmt: f, endLabel: g.mo > 0 && g.mo <= 120 ? monthYear(g.mo) : "más de 10 años") }
    }

    private func monthYear(_ months: Int) -> String {
        let d = LocalDate(year: model.today.year, month0: model.today.month0 + months, day: 1)
        return "\(Spanish.monthsShort[d.month0].capitalized) \(d.year)"
    }

    @ViewBuilder
    private func savingTail(_ sv: JSONValue, _ e: Engine, _ f: Fmt, _ cur: String) -> some View {
        let log = (sv["log"]?.arrayValue ?? []).sorted { Engine.text($0["date"]) > Engine.text($1["date"]) }.prefix(8)
        let color = Color(hex: e.calc().savings.first(where: { $0.id == id })?.color ?? "#1A9D63")
        SectionHead("Últimos movimientos")
        ListCard {
            if log.isEmpty {
                Text("Aún no hay aportes").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            ForEach(Array(log.enumerated()), id: \.offset) { i, l in
                if i > 0 { RowDivider() }
                let from = e.allAccounts.first(where: { $0["id"] == l["from"] && l["from"] != nil })
                HStack(spacing: 12) {
                    Text("+").font(.inter(22, .bold)).foregroundStyle(.white).frame(width: 46, height: 46)
                        .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aporte").font(.inter(16, .semibold))
                        Text(shortDate(Engine.text(l["date"])) + (from.map { " · " + Engine.text($0["name"]) } ?? "")).font(.inter(13)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("+" + f.exact(Engine.number(l["amount"]), cur)).font(.inter(16)).monospacedDigit().foregroundStyle(Brand.gainText)
                }
                .padding(.vertical, 10)
                .frame(minHeight: 64)
            }
            RowDivider()
            Button { model.activeSheet = .contrib } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3").frame(width: 26)
                    Text("Aportar a esta meta").font(.inter(17))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Brand.accent).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 14)
    }

    private func shortDate(_ iso: String) -> String { LocalDate(iso: iso).map { Spanish.dateShort($0) } ?? iso }

    // MARK: movimientos

    @ViewBuilder
    private func movements(_ o: JSONValue, _ e: Engine, _ f: Fmt) -> some View {
        let first = Engine.text(e.allAccounts.first?["id"])
        let byId: [String: JSONValue] = Dictionary(e.allTransactions.map { (Engine.identifier($0["id"]), $0) }, uniquingKeysWith: { a, _ in a })
        let rows: [JSONValue] = Array(e.calc().txIds.compactMap { byId[$0] }.filter { t in
            (Engine.text(t["acc"]).isEmpty ? first : Engine.text(t["acc"])) == id
        }.prefix(60))
        SectionHead("Movimientos")
        ListCard {
            if rows.isEmpty {
                Text("Sin movimientos todavía").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { i, tx in
                if i > 0 { RowDivider() }
                NavigationLink(value: Route.tx(Engine.identifier(tx["id"]))) { TransactionRow(tx: tx, engine: e, fmt: f) }
                    .buttonStyle(.plain)
            }
            RowDivider()
            Button { adding = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).frame(width: 26)
                    Text("Añadir movimiento").font(.inter(17))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Brand.accent).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 14)
    }
}

/// «Cuándo se llena» (`svChart`): el saldo creciendo con el aporte mensual hasta la meta.
private struct SavingChart: View {
    let balance: Double
    let goal: Double
    let monthly: Double
    let months: Int
    let done: Bool
    let color: Color
    let cur: String
    let fmt: Fmt
    let endLabel: String

    var body: some View {
        if !(goal > 0) {
            note("Define un monto objetivo para ver la proyección.")
        } else if done {
            note("¡Vamos! Ya llegaste a \(fmt.exact(goal, cur)).")
        } else if !(monthly > 0) {
            note("Añade un aporte mensual para ver cuándo se llena.")
        } else {
            Canvas { ctx, size in
                let k = size.width / 330
                ctx.scaleBy(x: k, y: k)
                let L: CGFloat = 8, R: CGFloat = 8, T: CGFloat = 22, B: CGFloat = 34, W: CGFloat = 330, H: CGFloat = 190
                let n = max(1, min(months, 120))
                let x0 = L, x1 = W - R, y0 = H - B, y1 = T
                func X(_ m: Int) -> CGFloat { x0 + (x1 - x0) * CGFloat(m) / CGFloat(n) }
                func Y(_ v: Double) -> CGFloat { y0 - (y0 - y1) * CGFloat(min(v, goal) / goal) }
                var pts: [CGPoint] = []
                for m in 0...min(months, 120) { pts.append(CGPoint(x: X(m), y: Y(balance + monthly * Double(m)))) }
                let gray = Color(hex: "#6C6C70")
                var goalLine = Path(); goalLine.move(to: CGPoint(x: x0, y: y1)); goalLine.addLine(to: CGPoint(x: x1, y: y1))
                ctx.stroke(goalLine, with: .color(Color(hex: "#8E8E93")), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ctx.draw(Text("Meta \(fmt.whole(goal, cur))").font(.system(size: 12)).foregroundColor(gray), at: CGPoint(x: x0, y: y1 - 4), anchor: .bottomLeading)
                var base = Path(); base.move(to: CGPoint(x: x0, y: y0)); base.addLine(to: CGPoint(x: x1, y: y0))
                ctx.stroke(base, with: .color(Color(.separator)), lineWidth: 1)
                var line = Path(); line.move(to: pts[0]); for p in pts.dropFirst() { line.addLine(to: p) }
                var area = line
                area.addLine(to: CGPoint(x: x1, y: y0)); area.addLine(to: CGPoint(x: x0, y: y0)); area.closeSubpath()
                let top = pts.map { $0.y }.min() ?? y1
                ctx.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.30), color.opacity(0)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: y0)))
                ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                let a = pts[0], z = pts[pts.count - 1]
                ctx.fill(Path(ellipseIn: CGRect(x: a.x - 5, y: a.y - 5, width: 10, height: 10)), with: .color(.white))
                ctx.stroke(Path(ellipseIn: CGRect(x: a.x - 5, y: a.y - 5, width: 10, height: 10)), with: .color(color), lineWidth: 3)
                ctx.fill(Path(ellipseIn: CGRect(x: z.x - 7, y: z.y - 7, width: 14, height: 14)), with: .color(color))
                ctx.stroke(Path(ellipseIn: CGRect(x: z.x - 7, y: z.y - 7, width: 14, height: 14)), with: .color(.white), lineWidth: 3)
                ctx.draw(Text("Hoy").font(.system(size: 12)).foregroundColor(gray), at: CGPoint(x: x0, y: H - 6), anchor: .bottomLeading)
                ctx.draw(Text(endLabel).font(.system(size: 12, weight: .semibold)), at: CGPoint(x: x1, y: H - 6), anchor: .bottomTrailing)
            }
            .aspectRatio(330.0 / 190.0, contentMode: .fit)
            .accessibilityLabel("Proyección de la meta")
        }
    }

    private func note(_ t: String) -> some View {
        Text(t).font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18).multilineTextAlignment(.center)
    }
}
