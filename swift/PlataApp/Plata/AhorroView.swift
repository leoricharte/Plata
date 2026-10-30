import SwiftUI
import PlataCore

/// La pestaña Ahorro (`renderAhorro` de la web): anillo con lo ahorrado y las metas con su avance.
struct AhorroView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let c = e.calc()
        let savings = e.data["savings"]?.arrayValue ?? []
        let colorByID = Dictionary(c.savings.map { ($0.id, $0.color) }, uniquingKeysWith: { a, _ in a })
        let items = c.savings.filter { $0.ub > 0 }.map { RingChart<AnyView>.Item(value: $0.ub, color: Color(hex: $0.color)) }
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: "Tus metas de ahorro", title: "Ahorro")

                VStack(spacing: 0) {
                    RingChart(items: items) {
                        AnyView(
                            VStack(spacing: 0) {
                                Text("Ahorrado").font(.inter(13)).foregroundStyle(.secondary)
                                Text(f.whole(c.saved)).font(.inter(32, .bold)).tracking(-1).lineLimit(1).minimumScaleFactor(0.5)
                            }
                        )
                    }
                    .frame(maxWidth: 240)
                    (Text("Aportas unos ") + Text(f.whole(c.savedMonthly)).bold().foregroundColor(.primary) + Text(" al mes"))
                        .font(.inter(15)).foregroundStyle(.secondary).padding(.top, 6)
                    Button { model.activeSheet = .contrib } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Aportar a una meta")
                        }
                        .font(.inter(17)).foregroundStyle(Brand.green)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain).padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.bottom, 14)

                SectionHead("Metas")
                ListCard {
                    if savings.isEmpty {
                        Text("Aún no tienes metas").font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
                    }
                    ForEach(Array(savings.enumerated()), id: \.offset) { i, s in
                        if i > 0 { RowDivider() }
                        row(s, f, color: colorByID[Engine.identifier(s["id"])] ?? "#22B573")
                    }
                    if !savings.isEmpty { RowDivider() }
                    Button { model.activeSheet = .saving(id: nil) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle").font(.system(size: 22))
                            Text("Añadir meta de ahorro").font(.inter(17))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Brand.green)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .syncRefresh()
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddMenuButton() } }
    }

    private func row(_ s: JSONValue, _ f: Fmt, color: String) -> some View {
        let cur = Engine.text(s["cur"])
        let goal = Engine.number(s["goal"]), bal = Engine.number(s["balance"]), monthly = Engine.number(s["monthly"])
        let pct = goal > 0 ? min(100, bal / goal * 100) : 0
        let rem = max(0, goal - bal)
        let mo = monthly > 0 && rem > 0 ? Int((rem / monthly).rounded(.up)) : 0
        let eta: String = {
            if goal <= 0 { return "Sin meta" }
            if rem <= 0 { return "¡Meta cumplida!" }
            if mo == 0 { return "Sin aporte mensual" }
            let d = Calendar.current.date(byAdding: .month, value: mo, to: model.today.date()) ?? Date()
            let c = Calendar.current.dateComponents([.year, .month], from: d)
            return "Meta en \(Spanish.plural(mo, "mes", "meses")) · \(Spanish.monthsShort[(c.month ?? 1) - 1]) \(c.year ?? 2000)"
        }()
        let line: ScreenInsights.Line? = model.engine.insightsEnabled ? ScreenInsights.saving(s, today: model.today, whole: { f.whole($0, $1) }) : nil
        return NavigationLink(value: AcctRef(id: Engine.identifier(s["id"]))) {
            VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Tile(symbol: iconSymbol(Engine.text(s["icon"])) ?? "leaf.fill", color: Color(hex: color))
                VStack(alignment: .leading, spacing: 6) {
                    Text(Engine.text(s["name"])).font(.inter(16, .semibold)).tracking(-0.3).lineLimit(1)
                    if goal > 0 {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule().fill(Color(hex: color)).frame(width: g.size.width * pct / 100)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                    }
                    Text((goal > 0 ? "\(Int(pct.rounded()))% de \(f.whole(goal, cur)) · " : "") + eta)
                        .font(.inter(13)).foregroundStyle(.secondary).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(f.whole(bal, cur)).font(.inter(16, .medium)).monospacedDigit().lineLimit(1).fixedSize()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            if let line { InsightLineView(line: line).padding(.leading, 58).padding(.top, 2).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.vertical, 10).frame(minHeight: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeRow([
            SwipeAction(label: "Aportar", symbol: "plus", color: Brand.accent) { model.contribPreset = Engine.identifier(s["id"]); model.activeSheet = .contrib },
            SwipeAction(label: "Editar", symbol: "pencil", color: Color(hex: "#4F94F7")) { model.activeSheet = .saving(id: Engine.identifier(s["id"])) },
        ])
    }
}
