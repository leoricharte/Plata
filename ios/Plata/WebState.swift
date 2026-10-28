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
    case tab(TabKey), plus, gear, nid(Int)

    /// Selectores fijos (nunca vienen de datos de la persona).
    var selector: String {
        switch self {
        case .tab(let k): return "#tabs [data-act=\"tab:\(k.rawValue)\"]"
        case .plus: return "#plusbtn"
        case .gear: return "#gearbtn"
        case .nid(let n): return "[data-nid=\"\(n)\"]"
        }
    }
}

enum NativeFlags {
    /// true = barra de pestañas real del sistema (vidrio, lupa al mantener y arrastrar). false = la cápsula propia de antes.
    static let systemTabBar = true
}

enum NativeIcons {
    /// true = SF Symbols en la barra nativa (decisión de iOS). false = los Remix Icon de la web, extraídos a Assets.
    static let useSFSymbols = true
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

/// Un botón de la web que se dibuja en nativo (ver KINDS en Bridge.js).
struct NativeBtn: Equatable, Identifiable {
    var id = 0
    var kind = "glass"      // prominent · glass · icon
    var act = ""
    var label = ""
    var box = Box()
    var chk = false          // interruptores: aria-checked
    var dis = false
    var val = 0.0, lo = 0.0, hi = 1.0   // sliders

    init(_ m: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        id = Int(n(m["id"])); kind = (m["kind"] as? String) ?? "glass"
        act = (m["act"] as? String) ?? ""; label = (m["label"] as? String) ?? ""
        chk = (m["chk"] as? Bool) ?? false; dis = (m["dis"] as? Bool) ?? false
        val = n(m["val"]); lo = n(m["min"]); hi = n(m["max"])
        box = Box(["x": n(m["x"]), "y": n(m["y"]), "w": n(m["w"]), "h": n(m["h"]), "o": n(m["o"])])
    }

    /// SF Symbol de los botones de solo icono, según la acción que dispara en la web.
    var symbol: String {
        switch act {
        case "wback", "back", "acctback": return "chevron.left"
        case "whome", "close": return "xmark"
        case "wmenu": return "ellipsis"
        case "wdown", "wnext": return "chevron.down"
        case "wfin": return "checkmark"
        default: return label.isEmpty ? "circle" : "chevron.right"
        }
    }
}

/// Una fila del menú del «+».
struct MenuItem: Equatable, Identifiable {
    var id = 0
    var sep = false
    var act = ""
    var title = ""
    var sub = ""

    init(_ m: [String: Any], index: Int) {
        sep = (m["sep"] as? Bool) ?? false
        id = sep ? -(index + 1) : ((m["id"] as? NSNumber)?.intValue ?? index)
        act = (m["act"] as? String) ?? ""
        title = (m["title"] as? String) ?? ""
        sub = (m["sub"] as? String) ?? ""
    }

    var symbol: String {
        switch act {
        case "add": return "plus.circle"
        case "new:income": return "building.columns"
        case "new:expense": return "creditcard"
        case "xfer": return "arrow.left.arrow.right"
        case "new:job": return "banknote"
        default: return "circle"
        }
    }
}

/// El menú del «+» abierto en la web (#qmenu).
struct NativeMenu: Equatable {
    var box = Box()
    var vh = 0.0
    var up = false
    var items: [MenuItem] = []

    init(_ m: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        box = Box(["x": n(m["x"]), "y": n(m["y"]), "w": n(m["w"]), "h": n(m["h"]), "o": 1.0])
        vh = n(m["vh"])
        up = (m["up"] as? Bool) ?? false
        items = ((m["items"] as? [[String: Any]]) ?? []).enumerated().map { MenuItem($0.element, index: $0.offset) }
    }
}

/// Lo que la web le cuenta a Swift (ver Bridge.js).
struct WebState: Equatable {
    var bar = Box()
    var plus = Box()
    var gear = Box()
    var compact = false
    var btns: [NativeBtn] = []
    var menu: NativeMenu? = nil
    var gdot = 0            // 0 nada · 1 cambios sin guardar (naranja) · 2 nube: falta algo (rojo)
    var on = "resumen"
    var tab = ""            // valor de data-tab en la web (resumen, cuenta, movimientos…)
    var labels: [String: String] = [:]
    var plusLabel = ""
    var gearLabel = ""
    var theme = ""          // "dark", "light" o "" (sistema)

    init() {}
    init(_ b: [String: Any]) {
        bar = Box(b["bar"]); plus = Box(b["plus"]); gear = Box(b["gear"])
        compact = (b["compact"] as? Bool) ?? false
        gdot = (b["gdot"] as? NSNumber)?.intValue ?? 0
        btns = ((b["btns"] as? [[String: Any]]) ?? []).map(NativeBtn.init)
        menu = (b["menu"] as? [String: Any]).map { NativeMenu($0) }
        on = (b["on"] as? String) ?? ""
        tab = (b["tab"] as? String) ?? ""
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
