import Charts
import SwiftUI
import WidgetKit

private struct FamilyKey: EnvironmentKey { static let defaultValue: WidgetFamily = .systemMedium }
private struct CompactKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Dentro de un bento, cada pieza chica se dibuja en su versión compacta.
    var bentoFamily: WidgetFamily { get { self[FamilyKey.self] } set { self[FamilyKey.self] = newValue } }
    var bentoCompact: Bool { get { self[CompactKey.self] } set { self[CompactKey.self] = newValue } }
}

/// Los colores de las piezas: normales, o en blanco cuando van sobre una tarjeta de color (como las `.bw.sol` de la web).
struct BentoPal {
    var accent = Color(red: 0.133, green: 0.710, blue: 0.451)
    var gain = Color(red: 0.102, green: 0.616, blue: 0.388)
    var loss = Color(red: 0.898, green: 0.196, blue: 0.176)
    var warn = Color.orange
    var track = Color.secondary.opacity(0.2)
    static let solid = BentoPal(accent: .white, gain: .white, loss: Color(red: 1, green: 0.84, blue: 0.80), warn: Color(red: 1, green: 0.93, blue: 0.70), track: Color.white.opacity(0.26))
}
private struct PalKey: EnvironmentKey { static let defaultValue = BentoPal() }
extension EnvironmentValues { var bentoPal: BentoPal { get { self[PalKey.self] } set { self[PalKey.self] = newValue } } }

/// Los degradados de las tarjetas del Bento de la web (`.bw.s0` a `.s4` y `.bw.dk`).
struct BentoTone {
    let a: Color, b: Color
    static let green = BentoTone(a: Color(hex6: 0x2BC585), b: Color(hex6: 0x0B6E45))
    static let teal = BentoTone(a: Color(hex6: 0x34CFC0), b: Color(hex6: 0x0F6F80))
    static let purple = BentoTone(a: Color(hex6: 0xA98BF0), b: Color(hex6: 0x533BB0))
    static let orange = BentoTone(a: Color(hex6: 0xFFB84D), b: Color(hex6: 0xD8601A))
    static let pink = BentoTone(a: Color(hex6: 0xFF8FB1), b: Color(hex6: 0xB83A6B))
    static let dark = BentoTone(a: Color(hex6: 0x1B3A2B), b: Color(hex6: 0x0E1E16))
}
extension Color { init(hex6 v: UInt32) { self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) } }

extension BentoPiece {
    var tone: BentoTone {
        switch self {
        case .kpi: return .dark
        case .cats: return .purple
        case .budget: return .teal
        case .daily: return .green
        case .top: return .orange
        case .upcoming: return .pink
        case .debt: return .orange
        case .goals: return .teal
        case .rate: return .green
        case .score: return .dark
        case .weekday: return .purple
        case .flow: return .teal
        }
    }
}

extension View {
    /// La pieza sobre su tarjeta de color: degradado con un brillo arriba a la derecha y letra blanca.
    func bentoTile(_ p: BentoPiece, radius: CGFloat? = nil) -> some View {
        let t = p.tone
        return self
            .padding(14)
            .environment(\.colorScheme, .dark)
            .environment(\.bentoPal, .solid)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    LinearGradient(colors: [t.a, t.b], startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [.white.opacity(p.tone.a == BentoTone.dark.a ? 0.10 : 0.20), .clear], center: .topTrailing, startRadius: 0, endRadius: 170)
                    if p.tone.a == BentoTone.dark.a {
                        RadialGradient(colors: [Color(hex6: 0x3DD68C).opacity(0.22), .clear], center: .topTrailing, startRadius: 0, endRadius: 150)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius ?? 0, style: .continuous))
    }
}
private let gain = Color(red: 0.102, green: 0.616, blue: 0.388)
private let loss = Color(red: 0.898, green: 0.196, blue: 0.176)

extension PhoneSnapshot {
    func money(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n, sym: sym, dec: dec, signed: signed) }
    func whole(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n.rounded(), sym: sym, dec: 0, signed: signed) }
}

// MARK: piezas comunes

private struct Empty: View {
    @Environment(\.bentoPal) private var pal
    var title: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(pal.accent)
            Text("Abre Plata para cargar tus datos").font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}

private struct Head: View {
    @Environment(\.bentoPal) private var pal
    var title: String
    var body: some View { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1) }
}

private struct BarRow: View {
    @Environment(\.bentoPal) private var pal
    var name: String; var value: String; var frac: Double; var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(name).lineLimit(1); Spacer(minLength: 4); Text(value).monospacedDigit() }.font(.system(size: 12, weight: .medium))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.track)
                    Capsule().fill(tint).frame(width: max(4, g.size.width * min(1, max(0, frac))))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct Line: View {
    @Environment(\.bentoPal) private var pal
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
    @Environment(\.bentoPal) private var pal
    @Environment(\.bentoFamily) private var family
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
                    Text(s.whole(net, signed: true)).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(net >= 0 ? pal.gain : pal.loss)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                let items: [(String, String, Color)] = [("Balance actual", s.whole(s.balance), .primary), ("Ingresos del mes", s.whole(s.income), pal.gain),
                                                       ("Gastos del mes", s.whole(s.expense), .primary), ("Ahorro neto", s.whole(net, signed: true), net >= 0 ? pal.gain : pal.loss)]
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
    @Environment(\.bentoPal) private var pal
    @Environment(\.bentoFamily) private var family
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
    @Environment(\.bentoPal) private var pal
    @Environment(\.bentoFamily) private var family
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
                        Circle().trim(from: 0, to: max(0.01, r)).stroke(r >= 1 ? pal.loss : pal.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 0) { Text(s.whole(abs(left))).font(.system(size: 15, weight: .bold, design: .rounded)).minimumScaleFactor(0.6); Text(left < 0 ? "pasado" : "quedan").font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                    Head(title: "Presupuesto")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Head(title: "Presupuesto del mes"); Spacer(); Text("\(s.whole(s.budgetSpent)) de \(s.whole(s.budgetTotal))").font(.system(size: 11)).foregroundStyle(.secondary) }
                    ForEach(s.budget.prefix(4)) { b in BarRow(name: b.name, value: s.whole(b.amt), frac: b.frac, tint: b.frac >= 1 ? pal.loss : b.frac >= 0.8 ? pal.warn : pal.accent) }
                }
            }
        } else { Empty(title: "Presupuesto") }
    }
}

struct DailyView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.daily.count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                HStack { Head(title: "Gasto acumulado del mes"); Spacer(); Text(s.whole(s.daily.last ?? 0)).font(.system(size: 13, weight: .bold, design: .rounded)) }
                Chart {
                    ForEach(Array(s.daily.enumerated()), id: \.offset) { i, v in
                        AreaMark(x: .value("día", i + 1), y: .value("gasto", v)).foregroundStyle(pal.accent.opacity(0.18))
                        LineMark(x: .value("día", i + 1), y: .value("gasto", v)).foregroundStyle(pal.accent).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
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
    @Environment(\.bentoPal) private var pal
    @Environment(\.bentoFamily) private var family
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
    @Environment(\.bentoPal) private var pal
    @Environment(\.bentoFamily) private var family
    @Environment(\.bentoCompact) private var compact
    private var small: Bool { family == .systemSmall || compact }
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Head(title: "Próximos movimientos")
                ForEach(s.upcoming.prefix(small ? 3 : 5)) { u in Line(left: u.name, right: s.whole(u.amt, signed: true), sub: u.sub, tint: u.amt > 0 ? pal.gain : .primary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Próximos movimientos") }
    }
}

struct DebtView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.debt.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Head(title: "Tarjetas y deuda"); Spacer(); Text(s.whole(s.debtTotal)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(s.debtTotal > 0 ? pal.loss : .primary) }
                if s.creditUsed >= 0 { BarRow(name: "Crédito usado", value: "\(Int((s.creditUsed * 100).rounded()))%", frac: s.creditUsed, tint: s.creditUsed > 0.5 ? pal.warn : pal.accent) }
                ForEach(s.debt.prefix(2)) { d in Line(left: d.name, right: s.whole(d.amt)) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Tarjetas y deuda") }
    }
}

struct GoalsView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.goals.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Head(title: "Metas de ahorro")
                ForEach(s.goals) { g in BarRow(name: g.name, value: "\(Int((g.frac * 100).rounded()))%", frac: g.frac, tint: pal.accent) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else { Empty(title: "Metas de ahorro") }
    }
}

struct RateView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.rate > -9 {
            VStack(spacing: 2) {
                Head(title: "Tasa de ahorro")
                Text("\(Int((s.rate * 100).rounded()))%").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(s.rate >= 0 ? pal.gain : pal.loss).minimumScaleFactor(0.6)
                Text("de tus ingresos").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        } else { Empty(title: "Tasa de ahorro") }
    }
}

struct ScoreView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.letter.isEmpty {
            VStack(spacing: 0) {
                Head(title: "Nota del mes")
                Text(s.letter).font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(pal.accent)
                Text(s.adjective).font(.system(size: 13, weight: .semibold))
            }
        } else { Empty(title: "Nota del mes") }
    }
}

struct WeekdayView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, s.weekday.contains(where: { $0 > 0 }) {
            let names = ["D", "L", "M", "X", "J", "V", "S"]
            let mx = s.weekday.max() ?? 0
            VStack(alignment: .leading, spacing: 4) {
                Head(title: "Gasto por día de la semana")
                Chart(Array(s.weekday.enumerated()), id: \.offset) { i, v in
                    BarMark(x: .value("día", names[i]), y: .value("gasto", v)).foregroundStyle(v == mx ? pal.accent : pal.accent.opacity(0.4)).cornerRadius(4)
                }
                .chartYAxis(.hidden)
            }
        } else { Empty(title: "Gasto por día") }
    }
}

struct FlowView: View {
    @Environment(\.bentoPal) private var pal
    var s: PhoneSnapshot?
    var body: some View {
        if let s, !s.flow.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Head(title: "Ingresos vs gastos")
                Chart {
                    ForEach(s.flow) { m in
                        BarMark(x: .value("mes", m.label), y: .value("monto", m.income)).foregroundStyle(pal.accent).position(by: .value("tipo", "Ingresos")).cornerRadius(3)
                        BarMark(x: .value("mes", m.label), y: .value("monto", m.expense)).foregroundStyle(Color.orange).position(by: .value("tipo", "Gastos")).cornerRadius(3)
                    }
                }
                .chartYAxis(.hidden).chartLegend(.hidden)
            }
        } else { Empty(title: "Ingresos vs gastos") }
    }
}

