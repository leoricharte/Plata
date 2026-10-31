import Foundation

/// Lo que la extensión «Compartir» le pasa a la app cuando la persona elige qué hacer con una captura o un archivo
/// (sesión de reconocimiento, importar archivo, elegir banco). Una extensión no puede abrir la app, así que deja el archivo en el App Group
/// y la app lo recoge sola la próxima vez que se abre. Se guarda una sola cosa a la vez y se borra al recogerla.
enum ShareHandoff {
    static let group = "group.net.plataapp.plata"
    static let folder = "handoff"
    static let maxBytes = 30_000_000

    enum Choice: String, Codable, Sendable {
        /// Una captura para la sesión de reconocimiento (Nazca aprende encerrando movimientos).
        case recognition
        /// Un archivo (CSV, Excel, PDF) para importar: Plata reconoce el banco sola.
        case file
        /// Un archivo cuyo banco elige la persona.
        case banks
    }

    struct Item: Codable, Equatable, Sendable {
        var name: String
        var choice: Choice
        var added: Double
    }

    struct Payload: Sendable { var item: Item; var data: Data }

    private static var dir: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent(folder, isDirectory: true)
    }

    /// La extensión deja un archivo (reemplaza al anterior, si lo había). `false` si no se pudo guardar.
    @discardableResult static func stash(data: Data, name: String, choice: Choice) -> Bool {
        guard data.count <= maxBytes, let d = dir else { return false }
        let fm = FileManager.default
        try? fm.removeItem(at: d)
        do {
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
            let opts: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            try data.write(to: d.appendingPathComponent("file.bin"), options: opts)
            let meta = try JSONEncoder().encode(Item(name: name, choice: choice, added: Date().timeIntervalSince1970))
            try meta.write(to: d.appendingPathComponent("meta.json"), options: opts)
            return true
        } catch { try? fm.removeItem(at: d); return false }
    }

    /// La app recoge lo que haya y lo borra. Lo que lleva más de un día esperando se descarta.
    static func take() -> Payload? {
        guard let d = dir else { return nil }
        defer { try? FileManager.default.removeItem(at: d) }
        guard let meta = try? Data(contentsOf: d.appendingPathComponent("meta.json")),
              let item = try? JSONDecoder().decode(Item.self, from: meta),
              Date().timeIntervalSince1970 - item.added < 86_400,
              let data = try? Data(contentsOf: d.appendingPathComponent("file.bin")) else { return nil }
        return Payload(item: item, data: data)
    }
}
