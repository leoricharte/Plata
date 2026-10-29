import SwiftUI
import WidgetKit
import AppIntents

// MARK: datos

struct PEntry: TimelineEntry { let date: Date; let snap: PhoneSnapshot? }

struct PProvider: TimelineProvider {
    func placeholder(in context: Context) -> PEntry { PEntry(date: Date(), snap: nil) }
    func getSnapshot(in context: Context, completion: @escaping (PEntry) -> Void) { completion(PEntry(date: Date(), snap: PhoneShare.load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PEntry>) -> Void) {
        completion(Timeline(entries: [PEntry(date: Date(), snap: PhoneShare.load())], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

// MARK: declaración

private func make<V: View>(_ kind: String, _ title: String, _ desc: String, _ families: [WidgetFamily], @ViewBuilder _ view: @escaping (PhoneSnapshot?) -> V) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PProvider()) { e in
        view(e.snap).containerBackground(.black, for: .widget)
    }
    .configurationDisplayName(title).description(desc).supportedFamilies(families).contentMarginsDisabled()
}

private let sm: [WidgetFamily] = [.systemSmall]
private let sml: [WidgetFamily] = [.systemSmall, .systemMedium]
private let med: [WidgetFamily] = [.systemMedium]

struct KpiWidget: Widget { var body: some WidgetConfiguration { make("plata.kpi", "Resumen del mes", "Balance, ingresos, gastos y ahorro neto.", sml) { KpiView(s: $0).bentoTile(.kpi) } } }
struct CatsWidget: Widget { var body: some WidgetConfiguration { make("plata.cats", "Gasto por categoría", "En qué se va tu plata este mes.", sml) { CatsView(s: $0).bentoTile(.cats) } } }
struct BudgetWidget: Widget { var body: some WidgetConfiguration { make("plata.budget", "Presupuesto", "Cuánto llevas contra tus límites.", sml) { BudgetView(s: $0).bentoTile(.budget) } } }
struct DailyWidget: Widget { var body: some WidgetConfiguration { make("plata.daily", "Gasto acumulado del mes", "Cómo avanza tu gasto día a día.", med) { DailyView(s: $0).bentoTile(.daily) } } }
struct TopWidget: Widget { var body: some WidgetConfiguration { make("plata.top", "Mayores gastos", "Lo que más dinero se llevó este mes.", sml) { TopView(s: $0).bentoTile(.top) } } }
struct UpcomingWidget: Widget { var body: some WidgetConfiguration { make("plata.upcoming", "Próximos movimientos", "Lo que viene en los próximos días.", sml) { UpcomingView(s: $0).bentoTile(.upcoming) } } }
struct DebtWidget: Widget { var body: some WidgetConfiguration { make("plata.debt", "Tarjetas y deuda", "Cuánto debes y cuánto crédito usas.", sml) { DebtView(s: $0).bentoTile(.debt) } } }
struct GoalsWidget: Widget { var body: some WidgetConfiguration { make("plata.goals", "Metas de ahorro", "Qué tanto te falta para cada meta.", sml) { GoalsView(s: $0).bentoTile(.goals) } } }
struct RateWidget: Widget { var body: some WidgetConfiguration { make("plata.rate", "Tasa de ahorro", "Qué parte de tus ingresos te queda.", sm) { RateView(s: $0).bentoTile(.rate) } } }
struct ScoreWidget: Widget { var body: some WidgetConfiguration { make("plata.score", "Nota del mes", "Tu nota de Insights.", sm) { ScoreView(s: $0).bentoTile(.score) } } }
struct WeekdayWidget: Widget { var body: some WidgetConfiguration { make("plata.weekday", "Gasto por día", "En qué días de la semana gastas más.", med) { WeekdayView(s: $0).bentoTile(.weekday) } } }
struct FlowWidget: Widget { var body: some WidgetConfiguration { make("plata.flow", "Ingresos vs gastos", "Comparación de los últimos meses.", med) { FlowView(s: $0).bentoTile(.flow) } } }

// MARK: Bento (el que se arma en la app)

struct BentoEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bento"
    static var defaultQuery = BentoQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct BentoQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BentoEntity] {
        BentoStore.load().filter { identifiers.contains($0.id) }.map { BentoEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [BentoEntity] { BentoStore.load().map { BentoEntity(id: $0.id, name: $0.name) } }
    func defaultResult() async -> BentoEntity? { BentoStore.load().first.map { BentoEntity(id: $0.id, name: $0.name) } }
}

struct BentoIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Elegir bento"
    static var description = IntentDescription("Elige uno de los bentos que guardaste en tu galería.")
    @Parameter(title: "Bento") var bento: BentoEntity?
}

struct BentoEntry: TimelineEntry { let date: Date; let bento: SavedBento?; let snap: PhoneSnapshot? }

struct BentoProvider: AppIntentTimelineProvider {
    private func entry(_ c: BentoIntent) -> BentoEntry {
        let all = BentoStore.load()
        let pick = all.first { $0.id == c.bento?.id } ?? all.first
        return BentoEntry(date: Date(), bento: pick, snap: PhoneShare.load())
    }
    func placeholder(in context: Context) -> BentoEntry { BentoEntry(date: Date(), bento: nil, snap: nil) }
    func snapshot(for configuration: BentoIntent, in context: Context) async -> BentoEntry { entry(configuration) }
    func timeline(for configuration: BentoIntent, in context: Context) async -> Timeline<BentoEntry> {
        Timeline(entries: [entry(configuration)], policy: .after(Date().addingTimeInterval(30 * 60)))
    }
}

struct BentoView: View {
    @Environment(\.widgetFamily) private var family
    var e: BentoEntry
    var body: some View {
        if let b = e.bento {
            BentoCanvas(pieces: b.pieces, snap: e.snap, family: family)
        } else {
            VStack(spacing: 4) {
                Text(verbatim: Tr.t("Tu bento")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(red: 0.133, green: 0.710, blue: 0.451))
                Text(verbatim: Tr.t("Crea uno en Plata → Ajustes → Widgets")).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
}

struct BentoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "plata.bento", intent: BentoIntent.self, provider: BentoProvider()) { e in
            BentoView(e: e).containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Bento").description("Un bento de tu galería: tú eliges las piezas.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}

@main
struct PlataPhoneWidgets: WidgetBundle {
    var body: some Widget {
        BentoWidget()
        KpiWidget()
        BudgetWidget()
        CatsWidget()
        DailyWidget()
        UpcomingWidget()
        TopWidget()
        DebtWidget()
        GoalsWidget()
        RateWidget()
        ScoreWidget()
        WeekdayWidget()
        FlowWidget()
    }
}
