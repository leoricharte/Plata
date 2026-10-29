import Charts
import SwiftUI
import WidgetKit

private struct CompactKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Dentro de un bento, cada pieza chica se dibuja en su versión compacta.
    var bentoCompact: Bool { get { self[CompactKey.self] } set { self[CompactKey.self] = newValue } }
}

private let accent = Color(red: 0.133, green: 0.710, blue: 0.451)
private let gain = Color(red: 0.102, green: 0.616, blue: 0.388)
private let loss = Color(red: 0.898, green: 0.196, blue: 0.176)

extension PhoneSnapshot {
    func money(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n, sym: sym, dec: dec, signed: signed) }
    func whole(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n.rounded(), sym: sym, dec: 0, signed: signed) }
}

// MARK: piezas comunes

private struct Empty: View {
    var title: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
            Text("Abre Plata para cargar tus datos").font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}

private struct Head: View {
    var title: String
    var body: some View { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1) }
}

private struct BarRow: View {
    var name: String; var value: String; var frac: Double; var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(name).lineLimit(1); Spacer(minLength: 4); Text(value).monospacedDigit() }.font(.system(size: 12, weight: .medium))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(tint).frame(width: max(4, g.size.width * min(1, max(0, frac))))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct Line: View {
    var left: String; var right: String; var sub: String = ""; var tint: Color = .primary
    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(left).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if !sub.isEmpty { Text(sub).font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 4)
            Text(right).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint).monospacedDigit()
        }
    }
}

// MARK: vistas

struct KpiView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s {
            let net = s.income - s.expense
            if small {
                VStack(alignment: .leading, spacing: 2) {
                    Head(title: "Balance actual")
                    Text(s.whole(s.balance)).font(.system(size: 26, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Spacer(minLength: 2)
                    Head(title: "Ahorro neto del mes")
                    Text(s.whole(net, signed: true)).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(net >= 0 ? gain : loss)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                let items: [(String, String, Color)] = [("Balance actual", s.whole(s.balance), .primary), ("Ingresos del mes", s.whole(s.income), gain),
                                                       ("Gastos del mes", s.whole(s.expense), .primary), ("Ahorro neto", s.whole(net, signed: true), net >= 0 ? gain : loss)]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, x in
                        VStack(alignment: .leading, spacing: 1) {
                            Head(title: x.0)
                            Text(x.1).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(x.2).minimumScaleFactor(0.6).lineLimit(1)
                        }
                    }
                }
            }
        } else { Empty(title: "Resumen del mes") }
    }
}

struct CatsView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.cats.isEmpty {
            let donut = Chart(s.cats) { c in
                SectorMark(angle: .value("v", c.v), innerRadius: .ratio(0.62), angularInset: 1.5).foregroundStyle(Color(wHex: c.hex))
            }
            if small {
                donut.overlay { VStack(spacing: 0) { Text(s.whole(s.expense)).font(.system(size: 14, weight: .bold, design: .rounded)); Text("gastado").font(.system(size: 9)).foregroundStyle(.secondary) } }
            } else {
                HStack(spacing: 14) {
                    donut.frame(maxWidth: 120)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(s.cats.prefix(5)) { c in
                            HStack(spacing: 6) {
                                Circle().fill(Color(wHex: c.hex)).frame(width: 8, height: 8)
                                Text(c.name).font(.system(size: 12)).lineLimit(1)
                                Spacer(minLength: 2)
                                Text(s.whole(c.v)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                            }
                        }
                    }
                }
            }
        } else { Empty(title: "Gasto por categoría") }
    }
}

struct BudgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.budgetTotal > 0 {
            let left = s.budgetTotal - s.budgetSpent
            let r = min(1, s.budgetSpent / s.budgetTotal)
            if small {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 9)
                        Circle().trim(from: 0, to: max(0.01, r)).stroke(r >= 1 ? loss : accent, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 0) { Text(s.whole(abs(left))).font(.system(size: 15, weight: .bold, design: .rounded)).minimumScaleFactor(0.6); Text(left < 0 ? "pasado" : "quedan").font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                    Head(title: "Presupuesto")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Head(title: "Presupuesto del mes"); Spacer(); Text("\(s.whole(s.budgetSpent)) de \(s.whole(s.budgetTotal))").font(.system(size: 11)).foregroundStyle(.secondary) }
                    ForEach(s.budget.prefix(4)) { b in BarRow(name: b.name, value: s.whole(b.amt), frac: b.frac, tint: b.frac >= 1 ? loss : b.frac >= 0.8 ? .orange : accent) }
                }
            }
        } else { Empty(title: "Presupuesto") }
    }
}

struct DailyView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.daily.count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                HStack { Head(title: "Gasto acumulado del mes"); Spacer(); Text(s.whole(s.daily.last ?? 0)).font(.system(size: 13, weight: .bold, design: .rounded)) }
                Chart {
                    ForEach(Array(s.daily.enumerated()), id: \.offset) { i, v in
                        AreaMark(x: .value("día", i + 1), y: .value("gasto", v)).foregroundStyle(accent.opacity(0.18))
                        LineMark(x: .value("día", i + 1), y: .value("gasto", v)).foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    if s.budgetTotal > 0 { RuleMark(y: .value("límite", s.budgetTotal)).foregroundStyle(.secondary.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3])) }
                }
                .chartXScale(domain: 1...max(s.dim, 2))
                .chartXAxis(.hidden).chartYAxis(.hidden)
            }
        } else { Empty(title: "Gasto acumulado") }
    }
}

struct TopView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.top.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Head(title: "Mayores gastos")
                ForEach(s.top.prefix(small ? 3 : 4)) { t in Line(left: t.name, right: s.whole(t.amt), sub: t.sub) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Mayores gastos") }
    }
}

struct UpcomingView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Head(title: "Próximos movimientos")
                ForEach(s.upcoming.prefix(small ? 3 : 5)) { u in Line(left: u.name, right: s.whole(u.amt, signed: true), sub: u.sub, tint: u.amt > 0 ? gain : .primary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Próximos movimientos") }
    }
}

struct DebtView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.debt.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Head(title: "Tarjetas y deuda"); Spacer(); Text(s.whole(s.debtTotal)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(s.debtTotal > 0 ? loss : .primary) }
                if s.creditUsed >= 0 { BarRow(name: "Crédito usado", value: "\(Int((s.creditUsed * 100).rounded()))%", frac: s.creditUsed, tint: s.creditUsed > 0.5 ? .orange : accent) }
                ForEach(s.debt.prefix(2)) { d in Line(left: d.name, right: s.whole(d.amt)) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Tarjetas y deuda") }
    }
}

struct GoalsView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.goals.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Head(title: "Metas de ahorro")
                ForEach(s.goals) { g in BarRow(name: g.name, value: "\(Int((g.frac * 100).rounded()))%", frac: g.frac, tint: accent) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Metas de ahorro") }
    }
}

struct RateView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.rate > -9 {
            VStack(spacing: 2) {
                Head(title: "Tasa de ahorro")
                Text("\(Int((s.rate * 100).rounded()))%").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(s.rate >= 0 ? gain : loss).minimumScaleFactor(0.6)
                Text("de tus ingresos").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        } else { Empty(title: "Tasa de ahorro") }
    }
}

struct ScoreView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.letter.isEmpty {
            VStack(spacing: 0) {
                Head(title: "Nota del mes")
                Text(s.letter).font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(accent)
                Text(s.adjective).font(.system(size: 13, weight: .semibold))
            }
        } else { Empty(title: "Nota del mes") }
    }
}

struct WeekdayView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.weekday.contains(where: { $0 > 0 }) {
            let names = ["D", "L", "M", "X", "J", "V", "S"]
            let mx = s.weekday.max() ?? 0
            VStack(alignment: .leading, spacing: 4) {
                Head(title: "Gasto por día de la semana")
                Chart(Array(s.weekday.enumerated()), id: \.offset) { i, v in
                    BarMark(x: .value("día", names[i]), y: .value("gasto", v)).foregroundStyle(v == mx ? accent : accent.opacity(0.4)).cornerRadius(4)
                }
                .chartYAxis(.hidden)
            }
        } else { Empty(title: "Gasto por día") }
    }
}

struct FlowView: View {
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.flow.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Head(title: "Ingresos vs gastos")
                Chart {
                    ForEach(s.flow) { m in
                        BarMark(x: .value("mes", m.label), y: .value("monto", m.income)).foregroundStyle(accent).position(by: .value("tipo", "Ingresos")).cornerRadius(3)
                        BarMark(x: .value("mes", m.label), y: .value("monto", m.expense)).foregroundStyle(Color.orange).position(by: .value("tipo", "Gastos")).cornerRadius(3)
                    }
                }
                .chartYAxis(.hidden).chartLegend(.hidden)
            }
        } else { Empty(title: "Ingresos vs gastos") }
    }
}

