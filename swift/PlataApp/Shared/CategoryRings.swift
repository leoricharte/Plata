import SwiftUI

// Aros de categoría: los mismos en el Apple Watch (presupuesto del día) y en el iPhone (Presupuesto).
// Este archivo está en `Shared`, así que lo compilan los dos.

extension Color {
    init(watchHex h: String?) {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { self = Color(red: 0.133, green: 0.710, blue: 0.451); return }
        self = Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

extension Color {
    /// ¿Es un color casi negro? (una categoría en negro no se ve sobre el fondo oscuro del reloj).
    static func watchIsDark(_ h: String?) -> Bool {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { return false }
        let r = Double((v >> 16) & 255) / 255, g = Double((v >> 8) & 255) / 255, b = Double(v & 255) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.30
    }
    /// El color de la categoría para dibujarlo sobre fondo oscuro: si ya es oscuro, blanco; si no, el suyo.
    init(watchOnDark h: String?) { self = Color.watchIsDark(h) ? Color(white: 0.94) : Color(watchHex: h) }
}

extension Color {
    /// El mismo tono, muy oscuro (o casi blanco si el aro ya es oscuro): para el texto y el icono que van encima de un aro de ese color.
    init(watchDark h: String?) {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { self = Color(white: 0.08); return }
        let r = Double((v >> 16) & 255) / 255, g = Double((v >> 8) & 255) / 255, b = Double(v & 255) / 255
        // Un aro que ya es oscuro (p. ej. «Proyectos» en casi negro) no admite un tono aún más oscuro: ahí el texto y el icono van claros.
        if 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.30 { self = Color(white: 0.92); return }
        let k = 0.30
        self = Color(red: r * k, green: g * k, blue: b * k)
    }
}

/// Texto pegado a un arco, en el sentido del reloj desde `start` (grados desde las 12), con letras espaciadas.
struct CurvedLabel: View {
    var text: String
    var radius: CGFloat
    var size: CGFloat
    var start: Double = 4
    var color: Color = .black

    private static func weight(_ ch: Character) -> Double {
        switch ch {
        case "I", "·", " ", "1", ".", ",": return 0.55
        case "M", "W", "%": return 1.2
        default: return 1
        }
    }
    static func step(_ ch: Character, radius: CGFloat, size: CGFloat) -> Double { Double(size * 0.98) * weight(ch) / Double(radius) * 180 / .pi }
    /// Grados que ocupa un texto en un arco de ese radio.
    static func span(_ text: String, radius: CGFloat, size: CGFloat) -> Double { text.uppercased().reduce(0) { $0 + step($1, radius: radius, size: size) } }

    var body: some View {
        let chars = Array(text.uppercased())
        let angles: [Double] = {
            var a = start, out: [Double] = []
            for ch in chars { let st = Self.step(ch, radius: radius, size: size); out.append(a + st / 2); a += st }
            return out
        }()
        ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angles[i]))
            }
        }
    }
}


/// Icono y nombre de la categoría pegados al aro, centrados abajo (a las 6), leyéndose de izquierda a derecha.
struct BottomArcLabel: View {
    var text: String
    var symbol: String
    var radius: CGFloat
    var size: CGFloat
    var iconSize: CGFloat
    var color: Color

    /// Grados que ocupa el conjunto (icono, hueco y nombre).
    static func span(_ text: String, radius: CGFloat, size: CGFloat, iconSize: CGFloat) -> Double {
        Double((iconSize + 3) / radius) * 180 / .pi + CurvedLabel.span(text, radius: radius, size: size)
    }

    var body: some View {
        let chars = Array(text.uppercased())
        let iconSpan = Double((iconSize + 3) / radius) * 180 / .pi
        let steps = chars.map { CurvedLabel.step($0, radius: radius, size: size) }
        let total = iconSpan + steps.reduce(0, +)
        let left = -total / 2
        var pos: [Double] = []
        var a = left + iconSpan
        for st in steps { pos.append(a + st / 2); a += st }
        return ZStack {
            Image(systemName: symbol).font(.system(size: iconSize, weight: .heavy)).foregroundStyle(color)
                .offset(y: radius).rotationEffect(.degrees(-(left + iconSpan / 2 - 1.5 / Double(radius) * 180 / .pi)))
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                Text(String(ch)).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color)
                    .offset(y: radius).rotationEffect(.degrees(-pos[i]))
            }
        }
    }
}

/// Un aro de categoría: su avance (como mucho una vuelta), el porcentaje en el arranque del aro y, abajo en el centro, el icono y el nombre.
struct CategoryRing: View {
    var cat: WatchCat
    var symbol: String
    var width: CGFloat
    var radius: CGFloat
    var fontSize: CGFloat = 9.5

    var body: some View {
        let frac = cat.limit > 0 ? cat.spent / cat.limit : 0
        let size = fontSize
        let iconSize = width * 0.62
        let dark = Color(watchDark: cat.color)
        let toDeg = 180 / Double.pi
        let tip = 360 * min(1, max(0, frac))
        let begin = Double(width * 0.35 / radius) * toDeg + 3          // pasada la tapa redonda del arranque
        let pct = String(Int((frac * 100).rounded())) + "%"
        // el porcentaje va donde empieza el aro; si el avance es tan corto que no cabe, se escribe sobre la pista
        let pctFits = CurvedLabel.span(pct, radius: radius, size: size) <= tip - begin - 2
        // abajo: el nombre más largo que cabe (como mucho 130°), con «…» si hay que recortarlo
        let maxSpan = 130.0
        let name = Self.fitName(cat.name, radius: radius, size: size, iconSize: iconSize, maxSpan: maxSpan)
        let nameSpan = name.map { BottomArcLabel.span($0, radius: radius, size: size, iconSize: iconSize) } ?? 0
        let nameOnColor = tip >= 180 + nameSpan / 2
        return ZStack {
            ActivityRing(frac: frac, color: Color.watchIsDark(cat.color) ? Color(white: 0.30) : Color(watchHex: cat.color), width: width, radius: radius, symbol: nil, iconSize: iconSize, iconColor: dark)
            CurvedLabel(text: pct, radius: radius, size: size, start: begin, color: pctFits ? dark : Color.secondary)
            if let name { BottomArcLabel(text: name, symbol: symbol, radius: radius, size: size, iconSize: iconSize, color: nameOnColor ? dark : Color.secondary) }
        }
    }

    private static func fitName(_ name: String, radius: CGFloat, size: CGFloat, iconSize: CGFloat, maxSpan: Double) -> String? {
        var n = name.count
        while n >= 2 {
            let nm = n == name.count ? name : String(name.prefix(n - 1)) + "…"
            if BottomArcLabel.span(nm, radius: radius, size: size, iconSize: iconSize) <= maxSpan { return nm }
            n -= 1
        }
        return nil
    }
}

/// Un anillo como los de Actividad: la pista tenue y el progreso con degradado. Se queda en una sola vuelta aunque te pases.
struct ActivityRing: View {
    var frac: Double
    var color: Color
    var width: CGFloat
    var radius: CGFloat
    var arrow = false
    var symbol: String? = nil          // icono de la categoría en la punta (en vez de la flecha)
    var iconSize: CGFloat = 9
    var iconColor: Color = .black.opacity(0.75)
    var body: some View {
        let lap = min(1, max(0.004, frac))
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: width)
            Circle().trim(from: 0, to: lap)
                .stroke(AngularGradient(colors: [color.opacity(0.65), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(max(1, 360 * lap))),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let symbol {
                let deg = frac > 0.02 ? 360 * lap : 0
                Image(systemName: symbol).font(.system(size: iconSize, weight: .heavy)).foregroundStyle(iconColor)
                    .offset(x: radius * CGFloat(sin(deg * .pi / 180)), y: -radius * CGFloat(cos(deg * .pi / 180)))
            } else if arrow && frac > 0.02 {
                let deg = 360 * lap
                Image(systemName: "arrow.right").font(.system(size: width * 0.6, weight: .heavy)).foregroundStyle(.black.opacity(0.7))
                    .rotationEffect(.degrees(deg))
                    .offset(x: radius * CGFloat(sin(deg * .pi / 180)), y: -radius * CGFloat(cos(deg * .pi / 180)))
            }
        }
    }
}

