import SwiftUI
import WidgetKit

// Los bentos que la persona arma en la app y guarda en su galería; el widget «Bento» elige uno de aquí. Se guardan en el App Group.

enum BentoPiece: String, CaseIterable, Codable, Identifiable {
    case kpi, cats, budget, daily, top, upcoming, debt, goals, rate, score, weekday, flow
    var id: String { rawValue }

    var title: String {
        switch self {
        case .kpi: return "Resumen del mes"
        case .cats: return "Gasto por categoría"
        case .budget: return "Presupuesto"
        case .daily: return "Gasto acumulado del mes"
        case .top: return "Mayores gastos"
        case .upcoming: return "Próximos movimientos"
        case .debt: return "Tarjetas y deuda"
        case .goals: return "Metas de ahorro"
        case .rate: return "Tasa de ahorro"
        case .score: return "Nota del mes"
        case .weekday: return "Gasto por día"
        case .flow: return "Ingresos vs gastos"
        }
    }
    var desc: String {
        switch self {
        case .kpi: return "Balance, ingresos, gastos y ahorro neto."
        case .cats: return "En qué se va tu plata este mes."
        case .budget: return "Cuánto llevas contra tus límites."
        case .daily: return "Cómo avanza tu gasto día a día."
        case .top: return "Lo que más dinero se llevó este mes."
        case .upcoming: return "Lo que viene en los próximos días."
        case .debt: return "Cuánto debes y cuánto crédito usas."
        case .goals: return "Qué tanto te falta para cada meta."
        case .rate: return "Qué parte de tus ingresos te queda."
        case .score: return "Tu nota de Insights."
        case .weekday: return "En qué días de la semana gastas más."
        case .flow: return "Comparación de los últimos meses."
        }
    }
    var symbol: String {
        switch self {
        case .kpi: return "rectangle.grid.2x2"
        case .cats: return "chart.pie"
        case .budget: return "gauge.with.dots.needle.33percent"
        case .daily: return "chart.xyaxis.line"
        case .top: return "list.number"
        case .upcoming: return "calendar"
        case .debt: return "creditcard"
        case .goals: return "target"
        case .rate: return "percent"
        case .score: return "star"
        case .weekday: return "chart.bar"
        case .flow: return "arrow.up.arrow.down"
        }
    }
}

enum BentoSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var label: String { self == .small ? "Pequeño" : self == .medium ? "Mediano" : "Grande" }
    var maxPieces: Int { self == .small ? 1 : self == .medium ? 2 : 4 }
    var family: WidgetFamily { self == .small ? .systemSmall : self == .medium ? .systemMedium : .systemLarge }
    var height: CGFloat { self == .large ? 354 : 158 }
    var width: CGFloat { self == .small ? 158 : 338 }
}

struct SavedBento: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var size: BentoSize
    var pieces: [BentoPiece]
}

enum BentoStore {
    static let key = "bentos"
    static var defaults: UserDefaults? { UserDefaults(suiteName: WatchShare.group) }
    static func load() -> [SavedBento] {
        guard let d = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedBento].self, from: d)) ?? []
    }
    static func save(_ list: [SavedBento]) {
        if let d = try? JSONEncoder().encode(list) { defaults?.set(d, forKey: key) }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Una pieza dibujada según su tipo.
struct PieceView: View {
    var piece: BentoPiece
    var snap: PhoneSnapshot?
    var body: some View {
        switch piece {
        case .kpi: KpiView(s: snap)
        case .cats: CatsView(s: snap)
        case .budget: BudgetView(s: snap)
        case .daily: DailyView(s: snap)
        case .top: TopView(s: snap)
        case .upcoming: UpcomingView(s: snap)
        case .debt: DebtView(s: snap)
        case .goals: GoalsView(s: snap)
        case .rate: RateView(s: snap)
        case .score: ScoreView(s: snap)
        case .weekday: WeekdayView(s: snap)
        case .flow: FlowView(s: snap)
        }
    }
}

/// El bento ya armado: una pieza completa, dos lado a lado (mediano) o una cuadrícula de dos columnas (grande).
struct BentoCanvas: View {
    var pieces: [BentoPiece]
    var snap: PhoneSnapshot?
    var family: WidgetFamily

    private var cap: Int { family == .systemSmall ? 1 : family == .systemMedium ? 2 : 4 }

    var body: some View {
        let list = Array(pieces.prefix(cap))
        Group {
            if list.isEmpty {
                Text("Elige piezas para tu bento").font(.system(size: 12)).foregroundStyle(.secondary)
            } else if list.count == 1 || family == .systemSmall {
                PieceView(piece: list[0], snap: snap)
            } else if family == .systemMedium {
                HStack(spacing: 14) {
                    ForEach(list) { p in PieceView(piece: p, snap: snap).environment(\.bentoCompact, true).frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            } else {
                let rows = stride(from: 0, to: list.count, by: 2).map { Array(list[$0..<min($0 + 2, list.count)]) }
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 14) {
                            ForEach(row) { p in
                                PieceView(piece: p, snap: snap).environment(\.bentoCompact, row.count == 2).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .environment(\.bentoFamily, family)
    }
}
