import Foundation
import PlataCore

/// La bandeja de constancias de Yape y Plin: lo que la extensión «Compartir» (PlataShare) deja para que la app lo añada la próxima vez que se abra.
/// Va por el App Group (el mismo de los widgets). Guarda solo lo que se LEYÓ (monto, fecha, nombre, número de operación), nunca la captura ni el texto completo.
/// La extensión no escribe en el perfil: dos procesos tocando el mismo archivo (y la nube) darían conflictos. La app lo añade con la misma revisión de Nazca
/// (repetidos incluidos) y se puede deshacer.
enum ConstanciaInbox {
    static let group = "group.net.plataapp.plata"
    static let fileName = "constancias-pendientes.json"
    static let maxEntries = 20

    struct Entry: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var added: Double
        var brand: String
        var bank: String
        var label: String
        var name: String
        var cur: String
        var date: String
        var desc: String
        var amount: Double
        var ref: String
        var flags: [String]
        var auto: Bool

        init(_ r: NazcaConstancia.Result) {
            let it = r.statement.items[0]
            id = UUID().uuidString
            added = Date().timeIntervalSince1970
            brand = r.brand; bank = r.statement.bank ?? ""; label = r.statement.label; name = r.statement.name; cur = r.statement.cur
            date = it.date; desc = it.desc; amount = it.amount; ref = it.ref ?? ""
            flags = r.flags; auto = r.auto
        }

        /// Lo mismo que leyó `NazcaConstancia`, para pasarlo por la revisión de Nazca.
        var statement: Nazca.StatementResult {
            var st = Nazca.StatementResult(bank: bank.isEmpty ? nil : bank, kind: "corriente", label: label, cur: cur,
                                           items: [Nazca.Item(line: 1, date: date, desc: desc, amount: amount, cur: cur, ref: ref.isEmpty ? nil : ref)])
            st.name = name
            st.period = date.isEmpty ? nil : .init(from: date, to: date)
            return st
        }

        /// Dos entradas son la misma constancia reenviada.
        var key: String { date + "|" + String(format: "%.2f", amount) + "|" + (ref.isEmpty ? desc : ref) }
    }

    static var url: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent(fileName) }

    private static func coordinated(_ u: URL, _ body: (URL) -> Void) -> Bool {
        var err: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: u, options: .forMerging, error: &err) { body($0) }
        return err == nil
    }

    private static func read(_ u: URL) -> [Entry] {
        guard let d = try? Data(contentsOf: u), let list = try? JSONDecoder().decode([Entry].self, from: d) else { return [] }
        return list
    }

    /// La extensión deja una constancia (si ya había una igual, la reemplaza). `false` si no se pudo guardar.
    @discardableResult static func append(_ e: Entry) -> Bool {
        guard let u = url else { return false }
        var ok = false
        let done = coordinated(u) { target in
            var list = read(target).filter { $0.key != e.key }
            list.append(e)
            if list.count > maxEntries { list.removeFirst(list.count - maxEntries) }
            guard let d = try? JSONEncoder().encode(list) else { return }
            ok = (try? d.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil
        }
        return done && ok
    }

    /// La app recoge todo lo que hay y vacía la bandeja.
    static func take() -> [Entry] {
        guard let u = url, FileManager.default.fileExists(atPath: u.path) else { return [] }
        var out: [Entry] = []
        _ = coordinated(u) { target in
            out = read(target)
            try? FileManager.default.removeItem(at: target)
        }
        return out
    }

    /// Cuántas hay esperando (sin tocarlas).
    static var count: Int { url.map { read($0).count } ?? 0 }
}
