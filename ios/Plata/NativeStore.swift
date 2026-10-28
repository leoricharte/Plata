import Foundation

/// Copia de seguridad nativa de los datos locales de la web (claves `finanzas.*` y `plata.*`).
/// Existe porque iOS puede vaciar el almacenamiento web de una app; si pasa, la copia se restaura al abrir.
/// Si la persona borra sus datos desde la app, la copia se actualiza (queda vacía) y no los "resucita".
struct NativeStore {
    private static let maxBytes = 20 * 1024 * 1024

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Plata", isDirectory: true).appendingPathComponent("local-backup.json")
    }

    func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
        return obj.filter { Self.allowed($0.key) }
    }

    func save(_ items: [String: String]) {
        let clean = items.filter { Self.allowed($0.key) }
        let fm = FileManager.default
        if clean.isEmpty { try? fm.removeItem(at: fileURL); return }
        guard let data = try? JSONSerialization.data(withJSONObject: clean), data.count <= Self.maxBytes else { return }
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func allowed(_ key: String) -> Bool {
        key.hasPrefix("finanzas.") || key.hasPrefix("plata.")
    }
}
