import Foundation
import PlataCore

/// Las plantillas que Nazca aprendió, guardadas SOLO en este dispositivo (la forma de cada captura; nada de montos, textos ni fechas).
enum TemplateVault {
    private static let key = "nazca.templates.v1"

    static func load() -> [NazcaTemplates.Saved] {
        guard let d = UserDefaults.standard.data(forKey: key), let l = try? JSONDecoder().decode([NazcaTemplates.Saved].self, from: d) else { return [] }
        return l
    }

    static func save(_ list: [NazcaTemplates.Saved]) {
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func remember(_ t: NazcaExample.Template, bank: String? = nil) { save(NazcaTemplates.remember(t, into: load(), bank: bank)) }
    static func reinforce(at i: Int) { save(NazcaTemplates.reinforce(load(), at: i)) }
}
