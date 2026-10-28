import SwiftUI

/// Pestañas de la barra (mismas claves que `data-act="tab:…"` en la web).
enum TabKey: String, CaseIterable, Identifiable {
    case resumen, presupuesto, proyeccion, deuda
    var id: String { rawValue }

    /// Nombres de SF Symbols, por si se activa `NativeIcons.useSFSymbols`.
    var sfLine: String {
        switch self {
        case .resumen: return "chart.pie"
        case .presupuesto: return "wallet.bifold"
        case .proyeccion: return "chart.line.uptrend.xyaxis"
        case .deuda: return "creditcard"
        }
    }
    var sfFill: String {
        switch self {
        case .resumen: return "chart.pie.fill"
        case .presupuesto: return "wallet.bifold.fill"
        case .proyeccion: return "chart.line.uptrend.xyaxis"
        case .deuda: return "creditcard.fill"
        }
    }
}

/// Qué control de la web "toca" la barra nativa.
enum WebAction {
    case tab(TabKey), plus, gear

    /// Selectores fijos (nunca vienen de datos de la persona).
    var selector: String {
        switch self {
        case .tab(let k): return "#tabs [data-act=\"tab:\(k.rawValue)\"]"
        case .plus: return "#plusbtn"
        case .gear: return "#gearbtn"
        }
    }
}

enum NativeIcons {
    /// false = Remix Icon (regla de Plata: solo Remix). true = SF Symbols en la barra nativa.
    static let useSFSymbols = false
}

/// Rectángulo (en px CSS = puntos) y opacidad de un control de la web.
struct Box: Equatable {
    var x = 0.0, y = 0.0, w = 0.0, h = 0.0, o = 0.0

    init() {}
    init(_ any: Any?) {
        guard let m = any as? [String: Any] else { return }
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        x = n(m["x"]); y = n(m["y"]); w = n(m["w"]); h = n(m["h"]); o = n(m["o"])
    }

    var center: CGPoint { CGPoint(x: x + w / 2, y: y + h / 2) }
    var isUsable: Bool { w > 1 && h > 1 }
}

/// Lo que la web le cuenta a Swift (ver Bridge.js).
struct WebState: Equatable {
    var bar = Box()
    var plus = Box()
    var gear = Box()
    var compact = false
    var gdot = 0            // 0 nada · 1 cambios sin guardar (naranja) · 2 nube: falta algo (rojo)
    var on = "resumen"
    var labels: [String: String] = [:]
    var plusLabel = ""
    var gearLabel = ""
    var theme = ""          // "dark", "light" o "" (sistema)

    init() {}
    init(_ b: [String: Any]) {
        bar = Box(b["bar"]); plus = Box(b["plus"]); gear = Box(b["gear"])
        compact = (b["compact"] as? Bool) ?? false
        gdot = (b["gdot"] as? NSNumber)?.intValue ?? 0
        on = (b["on"] as? String) ?? ""
        labels = (b["labels"] as? [String: String]) ?? [:]
        plusLabel = (b["plusLabel"] as? String) ?? ""
        gearLabel = (b["gearLabel"] as? String) ?? ""
        theme = (b["theme"] as? String) ?? ""
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}
