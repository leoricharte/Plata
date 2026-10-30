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
    /// El mismo tono, muy oscuro: para el texto y el icono que van encima de un aro de ese color.
    init(watchDark h: String?) {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { self = Color(white: 0.08); return }
        let k = 0.30
        self = Color(red: Double((v >> 16) & 255) / 255 * k, green: Double((v >> 8) & 255) / 255 * k, blue: Double(v & 255) / 255 * k)
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
    private static func step(_ ch: Character, radius: CGFloat, size: CGFloat) -> Double { Double(size * 0.98) * weight(ch) / Double(radius) * 180 / .pi }
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


/// Un aro de categoría: su avance (como mucho una vuelta), el icono en la punta y, sobre el color, el nombre y el porcentaje curvados en un tono oscuro.
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
        let iconHalf = Double((iconSize / 2 + 1) / radius) * toDeg
        let tip = 360 * min(1, max(0, frac))
        let start = Double(width * 0.35 / radius) * toDeg + 3          // pasada la tapa redonda del arranque
        let end = (frac >= 1 ? 360 : tip) - iconHalf - 3               // antes del icono
        let avail = end - (frac >= 1 ? max(start, iconHalf + 3) : start)
        let begin = frac >= 1 ? max(start, iconHalf + 3) : start
        let pct = " · " + String(Int((frac * 100).rounded())) + "%"
        let label = Self.fit(cat.name, pct, avail: avail, radius: radius, size: size)
        return ZStack {
            ActivityRing(frac: frac, color: Color(watchHex: cat.color), width: width, radius: radius, symbol: symbol, iconSize: iconSize, iconColor: dark)
            if let label { CurvedLabel(text: label, radius: radius, size: size, start: begin, color: dark) }
        }
    }

    /// El texto más completo que cabe: «Nombre · 12 %», luego el nombre recortado con «…», luego solo el nombre.
    private static func fit(_ name: String, _ pct: String, avail: Double, radius: CGFloat, size: CGFloat) -> String? {
        guard avail > 0 else { return nil }
        func ok(_ t: String) -> Bool { CurvedLabel.span(t, radius: radius, size: size) <= avail }
        var n = name.count
        while n >= 3 {
            let nm = n == name.count ? name : String(name.prefix(n - 1)) + "…"
            if ok(nm + pct) { return nm + pct }
            n -= 1
        }
        n = name.count
        while n >= 3 {
            let nm = n == name.count ? name : String(name.prefix(n - 1)) + "…"
            if ok(nm) { return nm }
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

