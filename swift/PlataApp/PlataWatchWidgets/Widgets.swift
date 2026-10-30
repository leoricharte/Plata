import SwiftUI
import WidgetKit

private let accent = Color(red: 0.133, green: 0.710, blue: 0.451)

struct SnapEntry: TimelineEntry {
    let date: Date
    let snap: WatchSnapshot?
}

struct SnapProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapEntry { SnapEntry(date: Date(), snap: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SnapEntry) -> Void) { completion(SnapEntry(date: Date(), snap: WatchShare.load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapEntry>) -> Void) {
        completion(Timeline(entries: [SnapEntry(date: Date(), snap: WatchShare.load())], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

/// Montos: con la muñeca baja se ocultan.
private struct Amt: View {
    @Environment(\.isLuminanceReduced) private var dim
    var text: String
    var body: some View { Text(dim ? "———" : text) }
}

// MARK: presupuesto del día

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var e: SnapEntry

    var body: some View {
        if let s = e.snap, s.allowance > 0 {
            let left = s.allowance - s.spentToday
            let r = min(1, s.spentToday / s.allowance)
            switch family {
            case .accessoryCircular:
                Gauge(value: r) { Image(systemName: "creditcard") } currentValueLabel: {
                    Amt(text: s.fmt(max(0, left))).font(.system(size: 12, weight: .bold)).minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircular).tint(r >= 1 ? .red : accent)
            case .accessoryInline:
                Amt(text: (left < 0 ? "Pasado " : "Hoy quedan ") + s.fmt(abs(left)))
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Presupuesto de hoy").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    Amt(text: s.fmt(abs(left))).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(left < 0 ? .red : .primary)
                    Gauge(value: r) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(r >= 1 ? .red : accent)
                }
            }
        } else {
            Text("Presupuesto").font(.system(size: 12))
        }
    }
}

// MARK: nota de Insights

struct InsightsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var e: SnapEntry

    var body: some View {
        if let s = e.snap, !s.letter.isEmpty {
            switch family {
            case .accessoryCircular:
                ZStack { AccessoryWidgetBackground(); GradeMark(letter: s.letter, tier: s.tier, size: 34) }
            case .accessoryInline:
                Text("\(s.letter) • \(s.adjective)")
            default:
                HStack(spacing: 8) {
                    GradeMark(letter: s.letter, tier: s.tier, size: 38)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nota del mes").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                        Text(s.adjective).font(.system(size: 17, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        } else {
            Text("Insights").font(.system(size: 12))
        }
    }
}

// MARK: próximo cobro o ingreso

struct NextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var e: SnapEntry

    var body: some View {
        if let s = e.snap, s.nextIn >= 0, !s.nextName.isEmpty {
            let when = s.nextIn == 0 ? "hoy" : s.nextIn == 1 ? "mañana" : "en \(s.nextIn) d"
            switch family {
            case .accessoryCircular:
                ZStack { AccessoryWidgetBackground(); VStack(spacing: 0) { Text(s.nextIn == 0 ? "hoy" : "\(s.nextIn)").font(.system(size: 20, weight: .bold, design: .rounded)); if s.nextIn > 0 { Text("días").font(.system(size: 9)) } } }
            case .accessoryInline:
                Amt(text: "\(s.nextName) \(when)")
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.nextAmt > 0 ? "Próximo ingreso" : "Próximo pago").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    Text(s.nextName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    HStack { Amt(text: s.fmt(s.nextAmt, signed: true)); Text("· " + when).foregroundStyle(.secondary) }.font(.system(size: 12))
                }
            }
        } else {
            Text("Sin cobros próximos").font(.system(size: 12))
        }
    }
}

extension WatchSnapshot {
    func fmt(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n, sym: sym, dec: dec, signed: signed) }
}

// MARK: declaración

private let families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plata.budget", provider: SnapProvider()) { BudgetWidgetView(e: $0).containerBackground(.fill.tertiary, for: .widget) }
            .configurationDisplayName(Tr.t("Presupuesto de hoy")).description(Tr.t("Lo que te queda para gastar hoy.")).supportedFamilies(families)
    }
}
struct InsightsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plata.insights", provider: SnapProvider()) { InsightsWidgetView(e: $0).containerBackground(.fill.tertiary, for: .widget) }
            .configurationDisplayName(Tr.t("Nota de Insights")).description(Tr.t("La nota del mes.")).supportedFamilies(families)
    }
}
struct NextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plata.next", provider: SnapProvider()) { NextWidgetView(e: $0).containerBackground(.fill.tertiary, for: .widget) }
            .configurationDisplayName(Tr.t("Próximo cobro")).description(Tr.t("Tu próximo ingreso o pago.")).supportedFamilies(families)
    }
}

@main
struct PlataWidgets: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        InsightsWidget()
        NextWidget()
    }
}
