import Foundation
import Observation
import PlataCore

/// El estado de la app: el perfil (migrado y sellado), el motor de cálculo y los cambios que hacen las pantallas.
/// Todo lo que cambia el perfil pasa por `commit`: aplica el cambio, sella las ediciones para la nube y guarda en disco.
@MainActor
@Observable
final class AppModel {
    private(set) var profile: Profile
    private(set) var today: LocalDate
    private(set) var engine: Engine
    /// Cambios hechos en esta sesión (para refrescar vistas derivadas, como el archivo de exportación).
    private(set) var changes = 0
    var errorMessage: String?
    /// La pestaña abierta (para que los enlaces del Resumen puedan cambiarla).
    var tab: AppTab = .resumen
    /// Pantallas abiertas encima del Resumen (Movimientos, Ajustes…).
    var path: [Route] = []
    var showAddTransaction = false
    /// Hoja abierta desde el botón «+» o desde las listas (transferir, ingreso o gasto previsto).
    var activeSheet: ActiveSheet?
    /// Última vez que se guardó en el dispositivo (la web lo muestra bajo «Guardado»).
    private(set) var lastSaved: Date? = {
        let t = UserDefaults.standard.double(forKey: "plata.lastSaved")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }()

    @ObservationIgnored private let store: ProfileStore
    @ObservationIgnored private let stash: ProfileStore   // tus datos reales mientras ves un perfil de demostración
    @ObservationIgnored private var stamper = SyncStamper()

    init() {
        let dir = URL.applicationSupportDirectory.appending(path: "Plata", directoryHint: .isDirectory)
        let store = ProfileStore(directory: dir)
        let loaded = store.load() ?? Profile.empty
        var p = (try? Migration.migrate(loaded)) ?? ((try? Migration.migrate(Profile.empty)) ?? Profile.empty)
        let stamper = SyncStamper()
        var raw = p.raw
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)   // primera pasada: solo toma la foto
        p = Profile(raw: raw)
        let t = LocalDate.today()
        self.store = store
        self.stash = ProfileStore(directory: dir.appending(path: "stash", directoryHint: .isDirectory))
        self.stamper = stamper
        self.profile = p
        self.today = t
        self.engine = Engine(profile: p, today: t)
    }

    var isDemo: Bool { profile.isDemo }

    /// Hay algo que valga la pena guardar antes de abrir un demo (igual que `demoHasReal` de la web).
    var hasRealData: Bool {
        let e = engine
        return !e.allTransactions.isEmpty || !e.allCards.isEmpty || e.allAccounts.count > 1
            || e.allAccounts.contains { Engine.number($0["balance"]) != 0 }
            || !(e.data["savings"]?.arrayValue ?? []).isEmpty
    }

    var fmt: Fmt { Fmt(currency: engine.primaryCurrency, custom: engine.customCurrency) }

    func refreshToday() {
        let t = LocalDate.today()
        guard t != today else { return }
        today = t
        engine = Engine(profile: profile, today: t)
    }

    // MARK: cambios

    private func commit(_ change: (inout JSONValue) throws -> Void) throws {
        var raw = profile.raw
        try change(&raw)
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        changes += 1
        do { try store.save(profile); stampSaved() } catch { errorMessage = "No se pudo guardar en el dispositivo: \(error.localizedDescription)" }
    }

    func addTransaction(date: LocalDate, amount: Double, category: String, note: String, account: String) throws {
        try commit { raw in
            _ = try ProfileEditor.addTransaction(&raw, date: date.iso, amount: amount, category: category, note: note, account: account,
                                             now: Date().timeIntervalSince1970 * 1000)
        }
    }

    func updateTransaction(id: JSONValue, amount: Double, isOut: Bool, category: String, account: String, date: LocalDate, note: String) throws {
        try commit { raw in
            try ProfileEditor.updateTransaction(&raw, id: id, amount: amount, isOut: isOut, category: category, account: account, date: date.iso, note: note)
        }
    }

    func deleteTransaction(id: JSONValue) throws {
        try commit { raw in try ProfileEditor.deleteTransaction(&raw, id: id) }
    }

    private func stampSaved() {
        let d = Date()
        lastSaved = d
        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "plata.lastSaved")
    }

    /// Oculta o vuelve a mostrar una cuenta o tarjeta (`hid`).
    func setAccountHidden(id: String, hidden: Bool) {
        try? commit { raw in
            for key in ["accounts", "cards"] {
                guard var list = raw[key]?.arrayValue else { continue }
                for i in list.indices where Engine.identifier(list[i]["id"]) == id {
                    list[i]["hid"] = hidden ? .bool(true) : nil
                }
                raw[key] = .array(list)
            }
        }
    }

    func addTransfer(from: String, to: String, amount: Double, received: Double, commission: Double, note: String, date: LocalDate) throws {
        let pair = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        try commit { raw in
            try ProfileEditor.addTransfer(&raw, from: from, to: to, amount: amount, received: received, commission: commission, note: note,
                                          date: date.iso, now: Date().timeIntervalSince1970 * 1000, pair: pair)
        }
    }

    func saveExpected(collection: String, item: JSONValue) throws {
        try commit { raw in try ProfileEditor.saveExpected(&raw, collection: collection, item: item) }
    }

    func deleteExpected(collection: String, id: JSONValue) throws {
        try commit { raw in ProfileEditor.deleteExpected(&raw, collection: collection, id: id) }
    }

    func saveJob(_ item: JSONValue) throws {
        let nid = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        try commit { raw in try ProfileEditor.saveJob(&raw, item: item, newId: nid) }
    }

    func deleteJob(id: JSONValue) throws {
        try commit { raw in ProfileEditor.deleteJob(&raw, id: id) }
    }

    func setSetting(_ key: String, _ value: JSONValue) {
        let old = profile.raw["settings"]?[key]
        if old == value { return }
        if old == nil && (value == .number(0) || value == .string("")) { return }   // no crear ajustes vacíos
        try? commit { raw in
            var s = raw["settings"] ?? .object([:])
            s[key] = value
            raw["settings"] = s
        }
    }

    // MARK: archivo de perfil

    /// Reemplaza todo por el contenido de un archivo de perfil (el mismo formato que exporta la web).
    func importProfile(_ data: Data) throws {
        let incoming = try Profile(jsonData: data)
        let migrated = try Migration.migrate(incoming)
        stamper = SyncStamper()                       // perfil nuevo: se vuelve a tomar la foto, como en la web
        var raw = migrated.raw
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        changes += 1
        try store.save(profile)
        stampSaved()
    }

    // MARK: perfiles de demostración

    func loadDemo(_ id: String) throws {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else { throw DemoError.missing }
        let demo = try DemoProfile.load(Data(contentsOf: url), today: today)
        if !profile.isDemo, hasRealData { try? stash.save(profile) }
        try install(demo)
    }

    func exitDemo() throws {
        if let saved = stash.load() {
            try install(try Migration.migrate(saved))
        } else {
            try install(try Migration.migrate(Profile.empty))
        }
        stash.delete()
    }

    private func install(_ new: Profile) throws {
        stamper = SyncStamper()
        var raw = new.raw
        stamper.stamp(&raw, now: Date().timeIntervalSince1970 * 1000)
        profile = Profile(raw: raw)
        engine = Engine(profile: profile, today: today)
        changes += 1
        try store.save(profile)
        stampSaved()
    }

    func resetProfile() throws {
        try importProfile(Profile.empty.jsonData())
    }

    /// Escribe el perfil en un archivo temporal para compartirlo (nombre `plata-AAAA-MM-DD_HH-mm.json`).
    func exportFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ProfileStore.exportFileName())
        try profile.jsonData().write(to: url, options: .atomic)
        return url
    }
}

/// Montos con la moneda principal (y la propia, si la hay), como `fmt` / `fmt2` de la web.
struct Fmt {
    let currency: String
    let custom: String

    func whole(_ n: Double) -> String { Money.whole(n, currency, custom: custom) }
    func exact(_ n: Double) -> String { Money.exact(n, currency, custom: custom) }
    func whole(_ n: Double, _ cur: String) -> String { Money.whole(n, cur, custom: custom) }
    func exact(_ n: Double, _ cur: String) -> String { Money.exact(n, cur, custom: custom) }
    func signed(_ n: Double, _ cur: String) -> String { Money.signed(n, cur, custom: custom) }
    func symbol(_ cur: String) -> String { Money.symbol(cur, custom: custom) }
}


enum DemoError: LocalizedError {
    case missing
    var errorDescription: String? { "No se encontró el perfil de demostración." }
}

/// Los perfiles de demostración de la web.
struct DemoPerson: Identifiable {
    let id: String
    let name: String
    let city: String
    let line: String
    let color: String
    let symbol: String

    static let all: [DemoPerson] = [
        DemoPerson(id: "shawn", name: "Shawn", city: "San Francisco, CA", line: "Sueldo por hora y vida social activa", color: "#22B573", symbol: "wineglass.fill"),
        DemoPerson(id: "brenda", name: "Brenda", city: "Lima, PE", line: "De EE. UU. a la universidad", color: "#2EC4B6", symbol: "graduationcap.fill"),
        DemoPerson(id: "alessandro", name: "Alessandro", city: "Lima, PE", line: "Primer empleo y vive con su familia", color: "#FF9F0A", symbol: "house.fill"),
        DemoPerson(id: "andrea", name: "Andrea", city: "Lake Placid, NY", line: "Dueña de un hotel con mucho capital", color: "#8E6BD8", symbol: "building.2.fill"),
        DemoPerson(id: "kevin", name: "Kevin", city: "Lima, PE", line: "Ayuda en el taller de su papá y ahorra para una PS5", color: "#5B8DEF", symbol: "gamecontroller.fill"),
    ]
}


/// Las hojas que se abren encima de todo.
enum ActiveSheet: Identifiable, Hashable {
    case transfer
    /// `kind`: "income" o "expense"; `id`: nil para uno nuevo.
    case expected(kind: String, id: String?)
    case job(id: String?)

    var id: String {
        switch self {
        case .transfer: return "transfer"
        case .expected(let kind, let id): return "expected-\(kind)-\(id ?? "new")"
        case .job(let id): return "job-\(id ?? "new")"
        }
    }
}

enum AppTab: Hashable, CaseIterable {
    case resumen, presupuesto, proyeccion, cuentas
}
