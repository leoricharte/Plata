import SwiftUI
import PlataCore

/// Gráfica de la proyección (`projSVG` de la web): eje a la derecha, zona en rojo, línea verde y un punto en la semana elegida.
struct ProjectionChart: View {
    let series: [SeriesPoint]
    let sel: Double
    let symbol: String

    static func valueAt(_ s: [SeriesPoint], _ w: Double) -> Double {
        let i = min(s.count - 2, max(0, Int(w.rounded(.down))))
        let f = min(1, max(0, w - Double(i)))
        return s[i].v + (s[i + 1].v - s[i].v) * f
    }

    private func axis(_ v: Double) -> String {
        let a = abs(v), sg = v < 0 ? "−" : ""
        if a >= 1000 {
            let k = a / 1000
            let t = k == k.rounded() ? String(Int(k)) : String(format: "%g", k)
            return sg + symbol + t + "k"
        }
        return sg + symbol + String(Int(a))
    }

    var body: some View {
        Canvas { ctx, size in
            guard series.count > 1 else { return }
            ctx.scaleBy(x: size.width / 334, y: size.width / 334)
            let W = 334.0, x0 = 4.0, x1 = 288.0, top = 10.0, bot = 190.0, h = bot - top
            let vals = series.map { $0.v }
            let maxV = vals.max() ?? 0, minV = vals.min() ?? 0
            let hi = max(1000, ((maxV + 1) / 500).rounded(.up) * 500)
            let lo = minV < 0 ? (minV / 500).rounded(.down) * 500 : 0
            var step = hi - lo <= 2500 ? 500.0 : 1000.0
            if (hi - lo) / step > 12 {
                let raw = (hi - lo) / 6, mag = pow(10, floor(log10(raw)))
                step = [1.0, 2.0, 5.0, 10.0].map { $0 * mag }.first(where: { $0 >= raw }) ?? raw
            }
            func Y(_ v: Double) -> Double { top + ((hi - max(lo, min(hi, v))) / (hi - lo)) * h }
            func X(_ i: Double) -> Double { x0 + i * ((x1 - x0) / Double(series.count - 1)) }
            let grid = Color(light: "#E5E5EA", dark: "#2C2C2E")
            if lo < 0 {
                ctx.fill(Path(CGRect(x: 0, y: Y(0), width: x1, height: Y(lo) - Y(0))), with: .color(Color(hex: "#FF3B30").opacity(0.1)))
            }
            var v = lo, guardN = 0
            while v <= hi && guardN < 40 {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: Y(v))); line.addLine(to: CGPoint(x: x1, y: Y(v)))
                if v == 0 {
                    ctx.stroke(line, with: .color(Color(hex: "#8E8E93")), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                } else {
                    ctx.stroke(line, with: .color(grid), lineWidth: 1)
                }
                ctx.draw(Text(axis(v)).font(.inter(13)).foregroundColor(.secondary), at: CGPoint(x: W, y: Y(v)), anchor: .trailing)
                v += step; guardN += 1
            }
            if lo < 0 {
                ctx.draw(Text("zona en rojo").font(.inter(12)).foregroundColor(Brand.lossText), at: CGPoint(x: x1 - 6, y: Y(lo) - 6), anchor: .bottomTrailing)
            }
            var poly = Path()
            for (i, s) in series.enumerated() {
                let p = CGPoint(x: X(Double(i)), y: Y(s.v))
                if i == 0 { poly.move(to: p) } else { poly.addLine(to: p) }
            }
            var sline = Path()
            sline.move(to: CGPoint(x: X(sel), y: top)); sline.addLine(to: CGPoint(x: X(sel), y: bot))
            ctx.stroke(sline, with: .color(Color(hex: "#8E8E93")), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.stroke(poly, with: .color(Color(hex: "#1A9D63")), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            let cur = ProjectionChart.valueAt(series, sel)
            let c = CGPoint(x: X(sel), y: Y(cur))
            let dot = Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14))
            ctx.fill(dot, with: .color(Color(light: "#FFFFFF", dark: "#1C1C1E")))
            ctx.stroke(dot, with: .color(cur < 0 ? Color(hex: "#FF3B30") : Color(hex: "#1A9D63")), lineWidth: 3.5)
        }
        .aspectRatio(334.0 / 200.0, contentMode: .fit)
    }
}

/// La pestaña Proyección de la web (`renderProyeccion`).
struct ProyeccionView: View {
    @Environment(AppModel.self) private var model
    @State private var hor = 26
    @State private var week = 8.0
    @State private var includeVariable = true
    @State private var calMonth = 0
    @State private var calSel: String?
    @State private var soon = false

    private static let dot: [String: String] = ["in": "#22B573", "out": "#8E8E93", "sub": "#F08FB0", "card": "#B98AE6", "rec": "#6D8BEA", "sim": "#FF9F0A", "exp": "#FF6B5E"]
    private static let tlDot: [String: String] = ["in": "#22B573", "card": "#B98AE6", "rec": "#A1A1A6", "sub": "#F08FB0", "sim": "#FF9F0A", "exp": "#FF6B5E", "out": "#8E8E93"]

    private var engine: Engine {
        var e = model.engine
        e.variable = includeVariable
        return e
    }

    var body: some View {
        let e = engine
        let f = model.fmt
        let p = e.projection()
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: hor == 13 ? "Próximos 3 meses" : (hor == 26 ? "Próximos 6 meses" : "Próximos 12 meses"), title: "Proyección")
                calendarCard(e, f)
                projectionCard(e, f, p)
                incomeSection(e, f)
                jobsSection(e, f)
                expensesSection(e, f)
                simSection(e, f)
                SectionHead("Próximos eventos")
                timelineCard(p, f)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddMenuButton() } }
        .navigationDestination(for: Route.self) { route in
            if case .tx(let id) = route { TransactionDetailView(id: id).toolbarVisibility(.hidden, for: .tabBar) }
        }
        .alert("Llega en la siguiente versión", isPresented: $soon) { Button("Entendido", role: .cancel) {} }
    }

    // MARK: tarjeta contenedora

    private func card<C: View>(padding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18), @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.bottom, 14)
    }

    // MARK: calendario

    private struct CalEvent { let type: String; let name: String; let amt: Double; let pend: Bool; let key: String?; let skipped: Bool }

    private func calendarCard(_ e: Engine, _ f: Fmt) -> some View {
        let t = model.today
        let tk = t.iso
        let m = LocalDate(year: t.year, month0: t.month0 + calMonth, day: 1)
        let cushion = Engine.number(e.data["settings"]?["cushion"])
        var bal: [String: Double] = [:]
        for x in e.dailySeries() { bal[x.date.iso] = x.v }
        var by: [String: [CalEvent]] = [:]
        for ev in e.genEvents(keepSkipped: true) {
            if ev.pending { by[ev.orig ?? ev.date.iso, default: []].append(CalEvent(type: ev.type, name: ev.name, amt: ev.amt, pend: true, key: nil, skipped: false)) }
            else { by[ev.date.iso, default: []].append(CalEvent(type: ev.type, name: ev.name, amt: ev.amt, pend: false, key: ev.key, skipped: ev.skipped)) }
        }
        for tx in e.allTransactions where Engine.text(tx["date"]) <= tk {
            let n = Engine.text(tx["note"])
            by[Engine.text(tx["date"]), default: []].append(CalEvent(type: Engine.number(tx["amount"]) > 0 ? "in" : "out", name: n.isEmpty ? Engine.text(tx["category"]) : n,
                                                                   amt: e.transactionUSD(tx), pend: false, key: nil, skipped: false))
        }
        let sel = calSel ?? tk
        let dim = LocalDate.daysInMonth(year: m.year, month0: m.month0)
        let lead = (m.weekday + 6) % 7
        let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        let selEvents = by[sel] ?? []
        return card {
            HStack {
                navButton("chevron.left", disabled: calMonth <= -2) { calMonth -= 1 }
                Spacer()
                Text(Spanish.monthsFull[m.month0].capitalized + " " + String(m.year)).font(.inter(18, .semibold))
                Spacer()
                navButton("chevron.right", disabled: calMonth >= 12) { calMonth += 1 }
            }
            .padding(.bottom, 8)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(["L", "M", "X", "J", "V", "S", "D"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.inter(12)).foregroundStyle(.secondary).padding(.bottom, 4)
                }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 46) }
                ForEach(1...dim, id: \.self) { d in
                    let k = LocalDate(year: m.year, month0: m.month0, day: d).iso
                    dayCell(k, d, by[k] ?? [], bal[k], cushion, tk, sel)
                }
            }
            HStack(spacing: 14) {
                ForEach(Array([("Ingreso", "in"), ("Gasto", "out"), ("Servicio o suscripción", "sub"), ("Pago de deuda", "card"), ("Simulado", "sim")].enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: Self.dot[x.1] ?? "#8E8E93")).frame(width: 10, height: 10)
                        Text((x.0))
                    }
                }
            }
            .font(.inter(13)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10).padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 0) {
                RowDivider().padding(.bottom, 12)
                HStack(spacing: 0) {
                    Text(Self.dlabel(sel)).font(.inter(16, .semibold))
                    if let b = bal[sel] { Text(" · saldo \(f.whole(b))").font(.inter(16, .medium)).foregroundStyle(.secondary) }
                }
                if selEvents.isEmpty {
                    Text("Sin movimientos este día").font(.inter(14)).foregroundStyle(.secondary).padding(.vertical, 4)
                }
                ForEach(Array(selEvents.enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: Self.dot[x.type] ?? "#8E8E93")).frame(width: 8, height: 8)
                        Text(x.name).font(.inter(15)).strikethrough(x.skipped).lineLimit(1)
                        if x.pend { StatusBadge(text: "por confirmar", size: 11) }
                        Spacer(minLength: 8)
                        Text((x.amt > 0 ? "+" : "") + f.whole(x.amt)).font(.inter(15, .bold)).foregroundStyle(x.amt > 0 ? Brand.gainText : Color.primary)
                    }
                    .padding(.vertical, 8).opacity(x.skipped ? 0.5 : 1)
                }
            }
            .padding(.top, 8)
        }
    }

    private static func dlabel(_ iso: String) -> String { LocalDate(iso: iso).map { Spanish.dateShort($0) } ?? iso }

    private func navButton(_ symbol: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Brand.accent)
                .frame(width: 36, height: 36)
                .background(Color(.systemGroupedBackground), in: Circle())
                .opacity(disabled ? 0.3 : 1)
        }
        .buttonStyle(.plain).disabled(disabled)
    }

    private func dayCell(_ k: String, _ d: Int, _ list: [CalEvent], _ b: Double?, _ cushion: Double, _ tk: String, _ sel: String) -> some View {
        var types: [String] = []
        for x in list where !x.skipped && !types.contains(x.type) { types.append(x.type) }
        let selected = k == sel
        var tint = Color.clear
        if k > tk, let b { tint = b < 0 ? Color(light: "#FFE9E7", dark: "#3A1B19") : (b < cushion ? Color(light: "#FFF4DC", dark: "#3A2E12") : .clear) }
        return Button { calSel = k } label: {
            VStack(spacing: 4) {
                Text("\(d)").font(.inter(15, .medium))
                    .foregroundStyle(selected ? Color(light: "#FFFFFF", dark: "#000000") : (k == tk ? Brand.accent : Color.primary))
                HStack(spacing: 2) {
                    ForEach(Array(types.prefix(4).enumerated()), id: \.offset) { _, t in
                        Circle().fill(Color(hex: Self.dot[t] ?? "#8E8E93")).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(selected ? Color(light: "#1C1C1E", dark: "#F2F2F7") : tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: proyección

    private func projectionCard(_ e: Engine, _ f: Fmt, _ p: ProjectionResult) -> some View {
        let H = hor
        let ser = Array(p.series.prefix(H + 1))
        let w = min(week, Double(H))
        let cur = ProjectionChart.valueAt(ser, w)
        let i = min(ser.count - 2, max(0, Int(w.rounded(.down)))), fr = min(1, max(0, w - Double(i)))
        let date = ser[i].date.adding(days: Int((fr * 7).rounded(.down)))
        let bal = e.calc().balance
        let delta = cur - bal
        let cushion = Engine.number(e.data["settings"]?["cushion"])
        let minV = ser.map { $0.v }.min() ?? 0
        let red = ser.first(where: { $0.v < 0 })
        let sym = f.symbol(e.primaryCurrency).trimmingCharacters(in: .whitespaces)
        let weekly = Engine.number(e.data["settings"]?["variable_weekly"])
        return card {
            PillSegmented(items: [(13, "3 meses"), (26, "6 meses"), (52, "12 meses")], selection: Binding(get: { hor }, set: { hor = $0; week = min(week, Double($0)) }))
                .padding(.bottom, 14)
            Text("¿Cuánto tendré el \(Spanish.dateShort(date))?").font(.inter(15)).foregroundStyle(.secondary)
            Text(f.whole(cur)).font(.inter(38, .bold)).tracking(-1.3).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text("\(delta >= 0 ? "+" : "")\(f.whole(delta)) frente a hoy").font(.inter(15)).foregroundStyle(.secondary)
            if cur < 0 {
                StatusBadge(text: "En rojo", fg: Brand.lossText, bg: Color(light: "#FFE5E3", dark: "#3A1B19"), size: 13).padding(.top, 4)
            } else if cur < cushion {
                StatusBadge(text: ("Bajo tu colchón de \(f.whole(cushion))"), size: 13).padding(.top, 4)
            }
            ProjectionChart(series: ser, sel: w, symbol: sym).padding(.top, 12)
            HStack {
                ForEach(0..<5, id: \.self) { n in
                    Text(Spanish.dateShort(ser[Int((Double(H) * Double(n) / 4).rounded())].date).split(separator: " ").dropFirst().joined(separator: " "))
                        .font(.inter(12)).foregroundStyle(.secondary)
                    if n < 4 { Spacer(minLength: 0) }
                }
            }
            .padding(.leading, 4).padding(.trailing, 46).padding(.top, 2)
            Text("Semana \(Int(w.rounded())) de \(H)").font(.inter(15)).foregroundStyle(.secondary).padding(.top, 10)
            Slider(value: $week, in: 0...Double(H)).tint(Brand.accent)
            RowDivider()
            HStack(spacing: 12) {
                (Text("Incluir gasto variable ").font(.inter(17)) + Text("(\(f.whole(weekly)) por semana)").font(.inter(15)).foregroundColor(.secondary))
                Spacer(minLength: 8)
                Toggle("Incluir gasto variable estimado", isOn: $includeVariable).labelsHidden().tint(Brand.accent)
            }
            .padding(.vertical, 12)
            RowDivider().padding(.bottom, 12)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mínimo proyectado").font(.inter(15)).foregroundStyle(.secondary)
                    Text(f.whole(minV)).font(.inter(20, .bold)).tracking(-0.4)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Primera semana en rojo").font(.inter(15)).foregroundStyle(.secondary)
                    Text(red.map { String(Spanish.dateShort($0.date).split(separator: " ").dropFirst().joined(separator: " ")) } ?? "ninguna").font(.inter(20, .bold)).tracking(-0.4)
                }
            }
        }
    }

    // MARK: listas

    private func row(tile: AnyView, title: String, badge: String? = nil, sub: String, trailing: AnyView, onTap: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                    if let badge { StatusBadge(text: badge) }
                }
                Text(sub).font(.inter(13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .onTapGesture { if let onTap { onTap() } else { soon = true } }
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

    private func untilText(_ x: JSONValue) -> String {
        guard x["repeat"] != nil, Engine.flag(x["repeat"]), let u = LocalDate(iso: Engine.text(x["until"])) else { return "" }
        return " · hasta \(u.day) \(Spanish.monthsShort[u.month0])"
    }

    private func incomeSection(_ e: Engine, _ f: Fmt) -> some View {
        let pend = Set(e.pendingItems().filter { $0.kind == "in" }.map { $0.id })
        let items = e.allIncomeItems.sorted { Engine.text($0["date"]) < Engine.text($1["date"]) }
        let est = e.allTransactions.filter { Engine.number($0["est"]) > 0 && Engine.number($0["amount"]) > 0 }
        let avg = est.isEmpty ? 0 : est.reduce(0.0) { $0 + e.usd(Engine.number($1["amount"]) - Engine.number($1["est"]), e.accountCurrency($1["acc"])) } / Double(est.count)
        return VStack(spacing: 0) {
            SectionHead("Ingresos previstos")
            ListCard {
                if items.isEmpty { Text("Sin ingresos previstos").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18) }
                ForEach(Array(items.enumerated()), id: \.offset) { i, x in
                    if i > 0 { RowDivider() }
                    let cur = e.accountCurrency(x["acc"])
                    row(tile: AnyView(LetterTile(letter: String(Engine.text(x["name"]).prefix(1)), color: Brand.accent)),
                        title: Engine.text(x["name"]), badge: pend.contains(Engine.identifier(x["id"])) ? "Por confirmar" : nil,
                        sub: Self.dlabel(Engine.text(x["date"])) + " · " + Engine.repeatLabel(x["repeat"]) + untilText(x),
                        trailing: AnyView(Text("+" + f.whole(Engine.number(x["amount"]), cur)).font(.inter(16, .semibold)).monospacedDigit().foregroundStyle(Brand.gainText)),
                        onTap: { let i = Engine.identifier(x["id"]); model.activeSheet = pend.contains(i) ? .confirm(kind: "in", id: i, pick: true) : .expected(kind: "income", id: i) })
                }
                if !est.isEmpty {
                    Text("Variación media vs. lo previsto: \(avg >= 0 ? "+" : "−")\(f.exact(abs(avg))) (\(est.count) \(est.count == 1 ? "ingreso confirmado" : "ingresos confirmados"))")
                        .font(.inter(13)).foregroundStyle(.secondary).padding(.top, 6).padding(.bottom, 2)
                }
                RowDivider()
                addRow("Añadir ingreso previsto") { model.activeSheet = .expected(kind: "income", id: nil) }
            }
            .padding(.bottom, 14)
        }
    }

    private func jobsSection(_ e: Engine, _ f: Fmt) -> some View {
        let jobs = e.jobList
        let jobTx = e.allTransactions.filter { Engine.flag($0["job"]) && Engine.number($0["amount"]) > 0 }
            .sorted { Engine.text($0["date"]) > Engine.text($1["date"]) }.prefix(6)
        return VStack(spacing: 0) {
            SectionHead("Trabajos")
            ListCard {
                if jobs.isEmpty { Text("Sin trabajos").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18) }
                ForEach(Array(jobs.enumerated()), id: \.offset) { i, j in
                    if i > 0 { RowDivider() }
                    let cur = e.accountCurrency(j["acc"])
                    let rate = f.whole(Engine.number(j["rate"]), cur)
                    let line1 = Engine.text(j["mode"]) == "s"
                        ? "\(rate)/mes · sueldo · "
                        : "\(rate)/h · \(Engine.number(j["hours"]).formatted()) h/sem · \(Engine.number(j["tax"]).formatted())% impuestos · "
                    let until = Engine.text(j["until"]).isEmpty ? "" : " → " + Self.dlabel(Engine.text(j["until"]))
                    row(tile: AnyView(LetterTile(letter: String(Engine.text(j["name"]).prefix(1)), color: Engine.flag(j["sim"]) ? Color(hex: "#FF9F0A") : Brand.accent)),
                        title: Engine.text(j["name"]), badge: Engine.flag(j["sim"]) ? "Simulado" : nil,
                        sub: line1 + Engine.jobRepeatLabel(j) + "\n" + Self.dlabel(Engine.text(j["start"])) + until,
                        trailing: AnyView(Text("+" + f.whole(Engine.jobNetPay(j), cur)).font(.inter(16, .semibold)).monospacedDigit().foregroundStyle(Brand.gainText)),
                        onTap: { model.activeSheet = .job(id: Engine.identifier(j["id"])) })
                }
                RowDivider()
                addRow("Añadir un trabajo") { model.activeSheet = .job(id: nil) }
            }
            .padding(.bottom, jobTx.isEmpty ? 0 : 14)
            if !jobTx.isEmpty {
                SectionHead("Últimos ingresos de trabajo")
                ListCard {
                    ForEach(Array(jobTx.enumerated()), id: \.offset) { i, t in
                        if i > 0 { RowDivider() }
                        NavigationLink(value: Route.tx(Engine.identifier(t["id"]))) {
                            HStack(spacing: 12) {
                                LetterTile(letter: String(Engine.text(t["note"]).prefix(1)), color: Brand.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Engine.text(t["note"])).font(.inter(16, .semibold)).tracking(-0.3)
                                    Text(Self.dlabel(Engine.text(t["date"]))).font(.inter(13)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("+" + f.whole(Engine.number(t["amount"]), e.accountCurrency(t["acc"]))).font(.inter(16, .semibold)).foregroundStyle(Brand.gainText)
                                    if Engine.number(t["hrs"]) > 0 { Text("\(Engine.number(t["hrs"]).formatted()) hrs").font(.inter(12)).foregroundStyle(.secondary) }
                                }
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 64).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Cada trabajo genera sus pagos previstos según horas, impuestos y frecuencia. En \"Solo simular\" aparecen únicamente en la gráfica.")
                .font(.inter(13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 14).padding(.bottom, 16)
        }
    }

    private func expensesSection(_ e: Engine, _ f: Fmt) -> some View {
        let pend = Set(e.pendingItems().filter { $0.kind == "out" }.map { $0.id })
        let items = e.expectedExpenseList.sorted { Engine.text($0["date"]) < Engine.text($1["date"]) }
        return VStack(spacing: 0) {
            SectionHead("Gastos previstos")
            ListCard {
                if items.isEmpty { Text("Sin gastos previstos").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18) }
                ForEach(Array(items.enumerated()), id: \.offset) { i, x in
                    if i > 0 { RowDivider() }
                    let cur = e.accountCurrency(x["acc"])
                    let cat = e.categoryNames.contains(Engine.text(x["cat"])) ? Engine.text(x["cat"]) : "Otros"
                    let isCard = e.paymentCard(x) != nil
                    row(tile: AnyView(isCard ? Tile(symbol: "creditcard.fill", color: Color(hex: "#B98AE6")) : CategoryTile(engine: e, name: cat, color: Color(hex: e.categoryColor(cat)))),
                        title: Engine.text(x["name"]), badge: pend.contains(Engine.identifier(x["id"])) ? "Por confirmar" : nil,
                        sub: Self.dlabel(Engine.text(x["date"])) + " · " + Engine.repeatLabel(x["repeat"]) + untilText(x) + " · " + (isCard ? "Pago de crédito" : cat),
                        trailing: AnyView(Text("−" + f.whole(Engine.number(x["amount"]), cur)).font(.inter(16, .semibold)).monospacedDigit()),
                        onTap: { let i = Engine.identifier(x["id"]); model.activeSheet = pend.contains(i) ? .confirm(kind: "out", id: i, pick: true) : .expected(kind: isCard ? "cardpay" : "expense", id: i) })
                }
                RowDivider()
                addRow("Añadir gasto previsto") { model.activeSheet = .expected(kind: "expense", id: nil) }
                if !e.allCards.isEmpty {
                    RowDivider()
                    addRow("Añadir pago de crédito previsto") { model.activeSheet = .expected(kind: "cardpay", id: nil) }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private func simSection(_ e: Engine, _ f: Fmt) -> some View {
        let planned = e.plannedList
        return VStack(spacing: 0) {
            SectionHead("Simular gastos")
            ListCard {
                ForEach(Array(planned.enumerated()), id: \.offset) { i, pl in
                    if i > 0 { RowDivider() }
                    simRow(e, f, pl)
                }
                if !planned.isEmpty { RowDivider() }
                addRow("Simular un gasto") { model.activeSheet = .planned(id: nil) }
            }
            Text("Los activados cambian la gráfica y muestran su impacto entre dos fechas.")
                .font(.inter(13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 14).padding(.bottom, 16)
        }
    }

    private func simRow(_ e: Engine, _ f: Fmt, _ pl: JSONValue) -> some View {
        let on = pl["on"] != .bool(false)
        let im = on ? e.simImpact(pl) : nil
        return HStack(alignment: .top, spacing: 12) {
            Button { model.setPlannedOn(id: pl["id"] ?? .null, on: !on) } label: {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(on ? Color(hex: "#1A9D63") : Color.clear, in: Circle())
                    .overlay(Circle().strokeBorder(on ? Color(hex: "#1A9D63") : Color(hex: "#C7C7CC"), lineWidth: 2))
                    .opacity(on ? 1 : 0.9)
            }
            .buttonStyle(.plain).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(Engine.text(pl["name"])).font(.inter(16, .semibold)).tracking(-0.3)
                Text(Self.dlabel(Engine.text(pl["date"])) + (Engine.text(pl["kind"]) == "pay" && Engine.flag(pl["card"]) ? " · Pago de crédito" : ""))
                    .font(.inter(13)).foregroundStyle(.secondary)
                if let im {
                    Text("Del \(Self.short(im.start)) al \(Self.short(im.end)) · mínimo \(f.whole(im.withMin)) el \(Self.short(im.withDate.iso)) (sin esto: \(f.whole(im.withoutMin)))")
                        .font(.inter(13)).foregroundStyle(.secondary).padding(.top, 2)
                    HStack(spacing: 6) {
                        switch im.status {
                        case "red": StatusBadge(text: "Te deja en rojo", fg: Brand.lossText, bg: Color(light: "#FFE5E3", dark: "#3A1B19"))
                        case "amber": StatusBadge(text: "Bajo tu colchón")
                        default: StatusBadge(text: "Sin problema", fg: Brand.gainTextStrong, bg: Brand.gainBg)
                        }
                    }
                    .padding(.top, 4)
                }
                Button { do { try model.executePlanned(pl) } catch { soon = true } } label: {
                    Text("Ejecutar").font(.inter(13, .semibold)).foregroundStyle(Brand.accent)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(Brand.gainBg, in: Capsule())
                }
                .buttonStyle(.plain).padding(.top, 6)
            }
            Spacer(minLength: 8)
            Text(f.whole(Engine.number(pl["amount"]))).font(.inter(16, .medium)).monospacedDigit()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary).padding(.top, 4)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { model.activeSheet = .planned(id: Engine.identifier(pl["id"])) }
    }

    private static func short(_ iso: String) -> String {
        LocalDate(iso: iso).map { "\($0.day) \(Spanish.monthsShort[$0.month0])" } ?? iso
    }

    private func openEvent(_ ev: TimelineEntry, _ key: String) {
        if ev.type == "sim" {
            let id = ev.srcId
            model.activeSheet = ev.form == "job" ? .job(id: id) : .planned(id: id)
        } else { model.activeSheet = .event(key: key) }
    }

    private func timelineCard(_ p: ProjectionResult, _ f: Fmt) -> some View {
        card {
            if p.timeline.isEmpty {
                Text("No hay eventos programados").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(p.timeline.enumerated()), id: \.offset) { i, ev in
                        let last = i == p.timeline.count - 1
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ev.name).font(.inter(16, .semibold)).tracking(-0.3).strikethrough(ev.skipped)
                                    HStack(spacing: 6) {
                                        Text(ev.date).font(.inter(13)).foregroundStyle(.secondary)
                                        if ev.skipped { StatusBadge(text: "Omitido", fg: .secondary, bg: Color(light: "#E5E5EA", dark: "#2C2C2E"), size: 11) }
                                        else if ev.edited { StatusBadge(text: "Editado", fg: Brand.gainText, bg: Brand.gainBg, size: 11) }
                                    }
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text((ev.amt > 0 ? "+" : "") + f.whole(ev.amt)).font(.inter(16, .semibold)).monospacedDigit().foregroundStyle(ev.amt > 0 ? Brand.gainText : Color.primary)
                                    Text(ev.skipped ? "—" : f.whole(ev.after)).font(.inter(13)).foregroundStyle(.secondary)
                                }
                                if ev.key != nil { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary) }
                                else { Color.clear.frame(width: 12) }
                            }
                            .padding(.leading, 20)
                            .contentShape(Rectangle())
                            .opacity(ev.skipped ? 0.5 : 1)
                            .overlay(alignment: .leading) { TimelineDot(color: Color(hex: Self.tlDot[ev.type] ?? "#8E8E93")) }
                            .onTapGesture { if let k = ev.key { openEvent(ev, k) } }
                            if !last { Color.clear.frame(height: 18) }
                        }
                        // la línea de la izquierda cruza toda la fila (también el hueco de abajo), como el `border-left` de `.tl`
                        .background(alignment: .leading) { Rectangle().fill(Color(light: "#E5E5EA", dark: "#3A3A3C")).frame(width: 2) }
                    }
                }
                .padding(.leading, 6).padding(.top, 14)
            }
        }
    }
}

/// El punto de la línea de tiempo: 12 pt centrado sobre la línea de 2 pt, con un aro del color de la tarjeta (`.tl .dot` de la web).
struct TimelineDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 12, height: 12)
            .padding(3)
            .background(Color(.secondarySystemGroupedBackground), in: Circle())
            .offset(x: -8)   // el centro del punto (6 + 3) queda sobre el centro de la línea (x = 1)
            .accessibilityHidden(true)
    }
}
