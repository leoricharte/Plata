import SwiftUI
import UserNotifications
import PlataCore

/// Avisos locales (sin servidor): recordatorios si llevas días sin anotar y avisos de pagos, gastos e ingresos previstos.
/// Todo se programa en el iPhone con lo que ya sabe la app, y se reprograma cada vez que cambian los datos.
@MainActor @Observable
final class Reminders {
    static let shared = Reminders()
    private weak var model: AppModel?
    private var task: Task<Void, Never>?

    private(set) var inactivity: Bool
    private(set) var upcoming: Bool
    private(set) var showAmounts: Bool
    private(set) var denied = false

    private enum K { static let inact = "plata.notif.inactivity", up = "plata.notif.upcoming", amt = "plata.notif.amounts", since = "plata.notif.since" }
    private static let prefix = "plata."
    /// Texto en el idioma de la app (los avisos los arma el sistema, no pasan por `Tr`).
    private static func L(_ es: String, _ en: String) -> String { Tr.isEnglish ? en : es }

    private static var tiers: [(days: Int, title: String, body: String)] {[
        (2, L("Tu plata no se anota sola", "Your money won't log itself"),
            L("Dos días de silencio. Son 30 segundos, no una tesis.", "Two days of silence. It takes 30 seconds, not a thesis.")),
        (5, L("Tu mes sigue corriendo", "Your month keeps moving"),
            L("5 días sin anotar. Lo que no registras hoy, mañana ya no lo recuerdas.", "5 days with no entries. What you don't log today, you won't remember tomorrow.")),
        (9, L("Plata te extraña (en serio)", "Plata misses you (seriously)"),
            L("9 días sin pasar por aquí. Tu saldo también quiere saber de ti.", "9 days gone. Your balance wants to hear from you too.")),
        (16, L("Sin datos no hay nota", "No data, no grade"),
             L("16 días a ciegas. Así no hay evaluación que valga.", "16 days flying blind. No grade can survive that.")),
        (23, L("Casi un mes de misterio", "Almost a month of mystery"),
             L("Ponte al día en un minuto antes del cierre. Tú sabrás.", "Catch up in a minute before month-end. Your call.")),
    ]}

    private init() {
        let d = UserDefaults.standard
        inactivity = d.bool(forKey: K.inact)
        upcoming = d.bool(forKey: K.up)
        showAmounts = d.bool(forKey: K.amt)
    }

    func attach(_ model: AppModel) { self.model = model; refreshStatus() }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            Task { @MainActor in self.denied = s.authorizationStatus == .denied }
        }
    }

    // MARK: ajustes

    /// Enciende o apaga un tipo de aviso. Al encender el primero, pide el permiso.
    func set(inactivity v: Bool? = nil, upcoming u: Bool? = nil, amounts a: Bool? = nil) async {
        let d = UserDefaults.standard
        if v == true || u == true {
            let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            refreshStatus()
            if !ok { return }
        }
        if let v { inactivity = v; d.set(v, forKey: K.inact) }
        if let u { upcoming = u; d.set(u, forKey: K.up) }
        if let a { showAmounts = a; d.set(a, forKey: K.amt) }
        schedule()
    }

    // MARK: programación

    /// Se llama cuando cambian los datos o la app pasa a segundo plano (con una pequeña espera para juntar cambios).
    func schedule() {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await self?.scheduleNow()
        }
    }

    private func scheduleNow() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) })
        guard let model, inactivity || upcoming else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let cal = Calendar.current
        let now = Date()

        func add(_ id: String, _ title: String, _ body: String, at date: Date) {
            guard date > now else { return }
            let c = UNMutableNotificationContent()
            c.title = title; c.body = body; c.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            center.add(UNNotificationRequest(identifier: Self.prefix + id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        func at(_ day: Date, hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day }

        let e = model.engine

        if inactivity {
            // el último movimiento (o, si no hay ninguno, el día en que se encendió)
            var last: Date?
            for t in e.allTransactions {
                guard let d = LocalDate(iso: Engine.text(t["date"]))?.date(), d <= now else { continue }
                if last == nil || d > last! { last = d }
            }
            let d = UserDefaults.standard
            if d.object(forKey: K.since) == nil { d.set(now.timeIntervalSince1970, forKey: K.since) }
            let since = Date(timeIntervalSince1970: d.double(forKey: K.since))
            let anchor = cal.startOfDay(for: max(last ?? since, since))
            var n = 0
            for (i, tier) in Self.tiers.enumerated() {
                guard let day = cal.date(byAdding: .day, value: tier.days, to: anchor) else { continue }
                let when = at(day, hour: 19)
                guard when > now, n < 3 else { continue }
                n += 1
                add("inact\(i)", tier.title, tier.body, at: when)
            }
        }

        if upcoming {
            let f = model.fmt
            var count = 0
            for ev in e.genEvents() where ev.type != "sim" {
                guard count < 40 else { break }
                let day = ev.date.date()
                guard day > now.addingTimeInterval(-86_400), ev.date.days - model.today.days <= 21 else { continue }
                let amount = showAmounts ? f.whole(abs(ev.amt), f.currency) : ""
                let name = ev.name.isEmpty ? "" : ev.name
                let tag = [name, amount].filter { !$0.isEmpty }.joined(separator: " · ")
                // título y texto para «mañana» (9:00 del día anterior) y para «hoy» (8:00)
                let L = Self.L
                let eve: (String, String), today: (String, String)
                let pre = tag.isEmpty ? "" : tag + ". "
                switch ev.type {
                case "card":
                    eve = (L("Mañana toca pagar la tarjeta", "Card payment due tomorrow"), pre + L("Que los intereses no se coman tu mes.", "Don't let interest eat your month."))
                    today = (L("Hoy se paga la tarjeta", "Card payment due today"), pre + L("Hoy no hay excusas. Págala y respira.", "No excuses today. Pay it and breathe."))
                case "sub":
                    let amt = amount.isEmpty ? "" : amount + ". "
                    let hint = L("¿Todavía la usas o solo la mantienes viva? Piénsalo.", "Do you still use it, or just keep it on life support? Think about it.")
                    eve = (name.isEmpty ? L("Mañana se cobra una suscripción", "A subscription charges you tomorrow") : L("Mañana se cobra \(name)", "\(name) charges you tomorrow"), amt + hint)
                    today = (name.isEmpty ? L("Hoy se cobra una suscripción", "A subscription charges you today") : L("Hoy se cobra \(name)", "\(name) charges you today"), amt + hint)
                default:
                    if ev.amt > 0 {
                        let hint = L("Cuando llegue, confírmala. Disfrútala un minuto antes de gastarla.", "Confirm it when it lands. Enjoy it for a minute before spending it.")
                        eve = (L("Mañana te cae plata", "Money lands tomorrow"), pre + hint)
                        today = (L("Hoy te cae plata", "Money lands today"), pre + hint)
                    } else {
                        eve = (L("Mañana vence un pago", "A payment is due tomorrow"), pre + L("Que no te agarre de sorpresa.", "Don't get caught off guard."))
                        today = (L("Hoy vence un pago", "A payment is due today"), pre + L("Que no se te pase hoy.", "Don't let it slip today."))
                    }
                }
                guard let before = cal.date(byAdding: .day, value: -1, to: day) else { continue }
                let id = "ev\(ev.date.iso)-\(abs(ev.name.hashValue) % 100000)"
                // el día anterior a las 9:00; si ya pasó, el mismo día a las 8:00
                if at(before, hour: 9) > now { add(id + "a", eve.0, eve.1, at: at(before, hour: 9)); count += 1 }
                else if at(day, hour: 8) > now { add(id + "b", today.0, today.1, at: at(day, hour: 8)); count += 1 }
            }
        }
    }
}

/// Ajustes → Avisos.
struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private var r: Reminders { .shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Avisos", onClose: { dismiss() })
                Text("Plata te avisa desde tu iPhone, sin servidor: todo se calcula aquí con tus datos.")
                    .font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 14)
                SCard {
                    row("bell.badge", "Si llevo días sin anotar", Binding(get: { r.inactivity }, set: { v in Task { await r.set(inactivity: v) } }))
                    RowDivider()
                    row("calendar.badge.clock", "Pagos y gastos previstos", Binding(get: { r.upcoming }, set: { v in Task { await r.set(upcoming: v) } }))
                }
                Text("Los recordatorios llegan a los 2, 5 y 9 días sin movimientos. Los previstos llegan el día anterior a las 9:00: pagos de tarjeta, suscripciones, gastos e ingresos que ya tienes programados.")
                    .font(.inter(13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 8)
                SCard {
                    row("eye", "Mostrar montos en los avisos", Binding(get: { r.showAmounts }, set: { v in Task { await r.set(amounts: v) } }))
                }
                .padding(.top, 20)
                Text("Si lo dejas apagado, los avisos dicen qué vence pero no cuánto, para que nadie lo lea en tu pantalla bloqueada.")
                    .font(.inter(13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 8)
                if r.denied {
                    Button { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } } label: {
                        Text("Activar permiso en Configuración").font(.inter(16, .semibold)).foregroundStyle(Brand.green).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .padding(.top, 14)
                    Text("Las notificaciones de Plata están bloqueadas en tu iPhone.").font(.inter(13)).foregroundStyle(Brand.lossText)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 30)
        }
        .presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
        .onAppear { r.refreshStatus() }
    }

    private func row(_ symbol: String, _ title: String, _ on: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(Brand.accent)
            Toggle(title, isOn: on).font(.inter(17)).tint(Brand.accent)
        }
        .padding(.vertical, 8)
    }
}
