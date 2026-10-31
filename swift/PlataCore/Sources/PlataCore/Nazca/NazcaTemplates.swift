import Foundation

/// Lo que Nazca recuerda, en el dispositivo, de las capturas que ya aprendió (solo la forma de la captura: nada de montos, textos ni fechas).
/// La próxima vez que la persona suba una captura con la misma forma, Nazca la lee sin pedirle los dos movimientos.
public enum NazcaTemplates {
    public struct Saved: Codable, Equatable, Sendable {
        public var template: NazcaExample.Template
        /// Cuántas veces se usó o se confirmó.
        public var uses: Int
        /// La institución que la persona dijo (de la lista de verificadas), si la dijo.
        public var bank: String?
        public init(template: NazcaExample.Template, uses: Int = 1, bank: String? = nil) { self.template = template; self.uses = uses; self.bank = bank }
    }

    /// El catálogo VERIFICADO: formas de captura que Nazca global revisó y probó con capturas sintéticas. Vacío hasta que el aporte compartido exista;
    /// la app solo usa de forma automática estas y las que la propia persona enseñó, nunca una plantilla sin verificar.
    public static let verified: [Saved] = []

    public static let maxSaved = 8

    /// Dos plantillas son «la misma captura» si todo lo cualitativo coincide y las columnas están casi en el mismo lugar.
    public static func similar(_ a: NazcaExample.Template, _ b: NazcaExample.Template) -> Bool {
        a.rightAligned == b.rightAligned && a.descDy == b.descDy && a.dateMode == b.dateMode && a.signMode == b.signMode
            && abs(a.amountX - b.amountX) < 0.04 && abs(a.descLeft - b.descLeft) < 0.06
    }

    /// Añade una plantilla aprendida: si ya había una igual, se refuerza (y se queda la más reciente); si no, entra primera. Se guardan pocas.
    public static func remember(_ t: NazcaExample.Template, into list: [Saved], bank: String? = nil) -> [Saved] {
        var out = list
        if let i = out.firstIndex(where: { similar($0.template, t) }) {
            var s = out.remove(at: i); s.template = t; s.uses += 1; if let bank { s.bank = bank }
            out.insert(s, at: 0)
        } else { out.insert(Saved(template: t, bank: bank), at: 0) }
        return Array(out.prefix(maxSaved))
    }

    /// La guardada que mejor lee esta captura: la que saca más movimientos completos (con al menos 2). `nil` si ninguna la entiende.
    public static func best(_ saved: [Saved], boxes: [NazcaExample.Box], today: String) -> (index: Int, extraction: NazcaExample.Extraction)? {
        var found: (Int, NazcaExample.Extraction, Double)?
        for (i, s) in saved.enumerated() {
            let x = NazcaExample.extract(s.template, boxes: boxes, today: today)
            guard x.items.count >= 2 else { continue }
            let score = Double(x.items.count) - Double(x.flags.count) * 2 + Double(min(s.uses, 5)) * 0.1
            if found == nil || score > found!.2 { found = (i, x, score) }
        }
        return found.map { ($0.0, $0.1) }
    }

    /// Una vez que la persona confirmó una lectura hecha con una guardada, se refuerza.
    public static func reinforce(_ list: [Saved], at i: Int) -> [Saved] {
        guard list.indices.contains(i) else { return list }
        var out = list
        var s = out.remove(at: i); s.uses += 1
        out.insert(s, at: 0)
        return out
    }
}
