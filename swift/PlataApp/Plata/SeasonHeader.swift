import SwiftUI
import PlataCore

/// La temporada del hemisferio de la persona: decide los colores y el dibujo del título del mes (igual que `seasonKey` de la web).
enum Season {
    case winter, spring, summer, autumn

    static let southZones = try? NSRegularExpression(pattern: "^(America/(Lima|Santiago|Sao_Paulo|Argentina|Buenos_Aires|Montevideo|Asuncion|La_Paz|Punta_Arenas|Bahia|Fortaleza|Recife|Manaus|Cuiaba|Campo_Grande|Belem)|Australia|Antarctica|Pacific/(Auckland|Fiji|Tongatapu|Chatham|Apia|Noumea)|Africa/(Johannesburg|Maputo|Harare|Lusaka|Windhoek|Gaborone|Maseru|Mbabane)|Indian/(Reunion|Mauritius|Antananarivo)|Atlantic/(Stanley|South_Georgia))")

    /// `hemi`: "n", "s" o vacío (entonces se deduce de la zona horaria).
    static func of(month0: Int, hemi: String, timeZone: String = TimeZone.current.identifier) -> Season {
        var south = false
        if let re = southZones {
            south = re.firstMatch(in: timeZone, range: NSRange(timeZone.startIndex..., in: timeZone)) != nil
        }
        let m = (month0 + ((hemi == "s" || (hemi != "n" && south)) ? 6 : 0)) % 12
        if m == 11 || m < 2 { return .winter }
        if m < 5 { return .spring }
        if m < 8 { return .summer }
        return .autumn
    }

    var name: String {
        switch self {
        case .winter: return "Invierno"
        case .spring: return "Primavera"
        case .summer: return "Verano"
        case .autumn: return "Otoño"
        }
    }

    /// Los 4 colores de la temporada (`SEASON_GRAD`).
    var palette: [Color] {
        let hex: [String]
        switch self {
        case .winter: hex = ["#8EC5FF", "#4F86E6", "#1B2A66", "#E6F4FF"]
        case .spring: hex = ["#FF9ECF", "#5FCB94", "#1B6F66", "#FFF3A8"]
        case .summer: hex = ["#FFB347", "#FF7F3F", "#C2255C", "#7FE0FF"]
        case .autumn: hex = ["#FFC857", "#E5702F", "#6B1F2E", "#FFB199"]
        }
        return hex.map { Color(hex: $0) }
    }
}

/// El dibujo pequeño a cada lado del mes (hojas, copos, pétalos, sol y olas), en un lienzo de 72×56 como el SVG de la web.
struct SeasonArt: View {
    let season: Season
    var right = false

    private static func tf(_ x: CGFloat, _ y: CGFloat, rot: CGFloat = 0, scale: CGFloat = 1) -> CGAffineTransform {
        CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(rotationAngle: rot * .pi / 180))
            .concatenating(CGAffineTransform(translationX: x, y: y))
    }

    private static var leaf: Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -14))
        p.addCurve(to: CGPoint(x: 0, y: 16), control1: CGPoint(x: 10, y: -8), control2: CGPoint(x: 12, y: 6))
        p.addCurve(to: CGPoint(x: 0, y: -14), control1: CGPoint(x: -12, y: 6), control2: CGPoint(x: -10, y: -8))
        p.closeSubpath()
        return p
    }

    private static var sparkle: Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -9))
        p.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 1, y: -1))
        p.addQuadCurve(to: CGPoint(x: 0, y: 9), control: CGPoint(x: 1, y: 1))
        p.addQuadCurve(to: CGPoint(x: -9, y: 0), control: CGPoint(x: -1, y: 1))
        p.addQuadCurve(to: CGPoint(x: 0, y: -9), control: CGPoint(x: -1, y: -1))
        p.closeSubpath()
        return p
    }

    private static var flake: Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -9)); p.addLine(to: CGPoint(x: 0, y: 9))
        p.move(to: CGPoint(x: -7.8, y: -4.5)); p.addLine(to: CGPoint(x: 7.8, y: 4.5))
        p.move(to: CGPoint(x: -7.8, y: 4.5)); p.addLine(to: CGPoint(x: 7.8, y: -4.5))
        return p
    }

    /// `M4 y q4.5 -6 9 0 t9 0 t9 0 t9 0`
    private static func wave(_ y: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 4, y: y))
        p.addQuadCurve(to: CGPoint(x: 13, y: y), control: CGPoint(x: 8.5, y: y - 6))
        p.addQuadCurve(to: CGPoint(x: 22, y: y), control: CGPoint(x: 17.5, y: y + 6))
        p.addQuadCurve(to: CGPoint(x: 31, y: y), control: CGPoint(x: 26.5, y: y - 6))
        p.addQuadCurve(to: CGPoint(x: 40, y: y), control: CGPoint(x: 35.5, y: y + 6))
        return p
    }

    private static var rays: Path {
        var p = Path()
        let lines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (20, 8, 20, 11), (20, 37, 20, 40), (4, 24, 7, 24), (33, 24, 36, 24),
            (8.5, 12.5, 10.6, 14.6), (31.5, 35.5, 29.4, 33.4), (8.5, 35.5, 10.6, 33.4), (31.5, 12.5, 29.4, 14.6),
        ]
        for l in lines { p.move(to: CGPoint(x: l.0, y: l.1)); p.addLine(to: CGPoint(x: l.2, y: l.3)) }
        return p
    }

    // MARK: movimiento de entrada (misma coreografía que la web: una sola vez por apertura y todo vuelve a su sitio)

    private static func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
    /// 0 → 1 → 0 mientras dura la animación (`del` y `dur` en segundos); fuera de ella, 0.
    private static func bump(_ t: Double, _ del: Double, _ dur: Double) -> Double {
        let p = (t - del) / dur
        return t >= 0 && p > 0 && p < 1 ? sin(.pi * p) : 0
    }
    /// Una oscilación completa que termina en 0.
    private static func osc(_ t: Double, _ del: Double, _ dur: Double) -> Double {
        let p = (t - del) / dur
        return t >= 0 && p > 0 && p < 1 ? sin(2 * .pi * p) : 0
    }
    /// Pieza extra que cruza cayendo (o flotando) y se desvanece. `y`: altura al inicio, a mitad y al final; `a`: giro al inicio, a mitad y al final.
    private struct Faller {
        var x: Double, y: Double, rot: Double, scale: Double, sx: Double, del: Double, dur: Double
        var ys: (Double, Double, Double), spin: (Double, Double), peak: Double, mid: Double
        func state(_ t: Double) -> (dx: Double, dy: Double, rot: Double, op: Double)? {
            let p = (t - del) / dur
            guard t >= 0, p > 0, p < 1 else { return nil }
            let k = 0.55
            let dy = p < k ? SeasonArt.lerp(ys.0, ys.1, p / k) : SeasonArt.lerp(ys.1, ys.2, (p - k) / (1 - k))
            let dx = p < k ? SeasonArt.lerp(0, sx, p / k) : SeasonArt.lerp(sx, -sx * 0.5, (p - k) / (1 - k))
            let r = p < k ? SeasonArt.lerp(0, spin.0, p / k) : SeasonArt.lerp(spin.0, spin.1, (p - k) / (1 - k))
            let op = p < 0.14 ? SeasonArt.lerp(0, peak, p / 0.14) : (p < k ? SeasonArt.lerp(peak, mid, (p - 0.14) / (k - 0.14)) : SeasonArt.lerp(mid, 0, (p - k) / (1 - k)))
            return (dx, dy, r, op)
        }
    }
    private static let leafFall = [
        Faller(x: 30, y: 2, rot: -20, scale: 0.62, sx: 7, del: 0.5, dur: 2.5, ys: (-10, 20, 44), spin: (38, 80), peak: 0.95, mid: 0.8),
        Faller(x: 54, y: -2, rot: 35, scale: 0.5, sx: -6, del: 1.3, dur: 2.7, ys: (-10, 20, 44), spin: (38, 80), peak: 0.95, mid: 0.8),
        Faller(x: 8, y: 4, rot: 10, scale: 0.45, sx: 8, del: 2.0, dur: 2.3, ys: (-10, 20, 44), spin: (38, 80), peak: 0.95, mid: 0.8),
    ]
    private static let petalFall = [
        Faller(x: 34, y: 0, rot: -40, scale: 0.55, sx: 9, del: 0.6, dur: 3.0, ys: (-8, 16, 36), spin: (50, -30), peak: 0.9, mid: 0.75),
        Faller(x: 56, y: -2, rot: 30, scale: 0.45, sx: -8, del: 1.6, dur: 3.0, ys: (-8, 16, 36), spin: (50, -30), peak: 0.9, mid: 0.75),
    ]
    /// Cuánto dura todo el movimiento.
    static let total: Double = 4.8

    var body: some View {
        let m = SeasonMotion.shared
        let running = m.start != nil && !m.done
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { tl in
            let t: Double = (m.start != nil && !m.done) ? min(Self.total, max(0, tl.date.timeIntervalSince(m.start!))) : -1
            art(t: t)
        }
        .frame(width: 64, height: 50)
        .scaleEffect(x: right ? -1 : 1, y: 1)
        .accessibilityHidden(true)
    }

    /// `t < 0`: en reposo (el dibujo de siempre).
    private func art(t: Double) -> some View {
        let g = season.palette
        return Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 72, y: size.height / 56)
            func fill(_ path: Path, _ t: CGAffineTransform, _ color: Color, _ opacity: Double = 1) {
                ctx.fill(path.applying(t), with: .color(color.opacity(opacity)))
            }
            func stroke(_ path: Path, _ t: CGAffineTransform, _ color: Color, _ width: CGFloat, _ opacity: Double = 1) {
                ctx.stroke(path.applying(t), with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            /// Gira y escala alrededor de un punto (en el sistema de la pieza).
            func about(_ cx: CGFloat, _ cy: CGFloat, rot: Double = 0, scale: CGFloat = 1) -> CGAffineTransform {
                CGAffineTransform(translationX: -cx, y: -cy).concatenating(CGAffineTransform(scaleX: scale, y: scale))
                    .concatenating(CGAffineTransform(rotationAngle: rot * .pi / 180)).concatenating(CGAffineTransform(translationX: cx, y: cy))
            }
            switch season {
            case .autumn:
                // las hojas se mecen desde el tallo
                func sway(_ del: Double) -> CGAffineTransform { about(0, -14, rot: 7 * Self.osc(t, del, 2.2)) }
                fill(Self.leaf, sway(0.2).concatenating(Self.tf(18, 22, rot: -25, scale: 1.15)), g[1], 0.95)
                fill(Self.leaf, sway(0.5).concatenating(Self.tf(46, 38, rot: 32, scale: 0.85)), g[0])
                fill(Self.leaf, sway(0.8).concatenating(Self.tf(60, 12, rot: 62, scale: 0.6)), g[2], 0.75)
                for (i, f) in Self.leafFall.enumerated() {
                    guard let st = f.state(t) else { continue }
                    fill(Self.leaf, Self.tf(CGFloat(f.x + st.dx), CGFloat(f.y + st.dy), rot: CGFloat(f.rot + st.rot), scale: CGFloat(f.scale)), [g[0], g[1], g[3]][i], 0.9 * st.op)
                }
            case .winter:
                // los copos crecen, se atenúan y vuelven
                func pulse(_ del: Double, _ dur: Double, _ k: Double) -> (CGAffineTransform, Double) {
                    let b = Self.bump(t, del, dur)
                    return (about(0, 0, rot: 24 * b, scale: CGFloat(1 + (k - 1) * b)), 1 - 0.72 * b)
                }
                let a = pulse(0.25, 2.0, 1.4), b = pulse(0.9, 1.9, 1.45), c = pulse(1.5, 1.8, 1.5)
                stroke(Self.flake, a.0.concatenating(Self.tf(18, 24, scale: 1.3)), g[1], 2.2 * 1.3, a.1)
                stroke(Self.flake, b.0.concatenating(Self.tf(46, 40, scale: 0.9)), g[0], 2.2 * 0.9, b.1)
                stroke(Self.flake, c.0.concatenating(Self.tf(60, 14, scale: 0.65)), g[2], 2.2 * 0.65, c.1)
            case .spring:
                // los pétalos se mecen y dos más pasan flotando
                func flut(_ del: Double) -> CGAffineTransform {
                    let o = Self.osc(t, del, 2.2), b = Self.bump(t, del, 2.2)
                    return CGAffineTransform(rotationAngle: 12 * o * .pi / 180).concatenating(CGAffineTransform(translationX: CGFloat(1.5 * o), y: CGFloat(2.5 * b)))
                }
                let petal = Path(ellipseIn: CGRect(x: -11, y: -5.5, width: 22, height: 11))
                fill(petal, flut(0.2).concatenating(Self.tf(20, 24, rot: -35)), g[0], 0.95)
                fill(petal, flut(0.55).concatenating(Self.tf(46, 38, rot: 28)), g[1], 0.9)
                fill(petal, flut(0.9).concatenating(Self.tf(60, 14, rot: -10, scale: 0.7)), g[3], 0.9)
                for (i, f) in Self.petalFall.enumerated() {
                    guard let st = f.state(t) else { continue }
                    fill(petal, Self.tf(CGFloat(f.x + st.dx), CGFloat(f.y + st.dy), rot: CGFloat(f.rot + st.rot), scale: CGFloat(f.scale)), [g[0], g[3]][i], 0.9 * st.op)
                }
            case .summer:
                func twinkle(_ del: Double) -> (CGFloat, Double) {
                    // dos destellos seguidos (1.4 s cada uno)
                    let b = max(Self.bump(t, del, 1.4), Self.bump(t, del + 1.4, 1.4))
                    return (CGFloat(1 - 0.45 * b), 1 - 0.65 * b)
                }
                if right {
                    for (n, y) in [14, 25, 36].enumerated() {
                        let b = Self.bump(t, Double(n) * 0.22, 2.6)
                        stroke(Self.wave(CGFloat(y)), CGAffineTransform(translationX: CGFloat(-5 * b), y: CGFloat(1.6 * b)), n == 1 ? g[1] : g[0], 2.4, n == 1 ? 1 : 0.7)
                    }
                } else {
                    // el sol late dos veces; los rayos giran un poco
                    let beat = max(Self.bump(t, 0.25, 1.15), Self.bump(t, 1.4, 1.15))
                    let r = Self.bump(t, 0.25, 2.3)
                    fill(Path(ellipseIn: CGRect(x: 11.5, y: 15.5, width: 17, height: 17)), about(20, 24, scale: CGFloat(1 + 0.18 * beat)), g[0])
                    stroke(Self.rays, about(20, 24, rot: 20 * r, scale: CGFloat(1 + 0.12 * r)), g[0], 2.4, 1 - 0.25 * r)
                }
                let a = twinkle(0.3), b = twinkle(0.7)
                fill(Self.sparkle, CGAffineTransform(scaleX: a.0, y: a.0).concatenating(Self.tf(48, 40)), g[1], 0.95 * a.1)
                fill(Self.sparkle, CGAffineTransform(scaleX: b.0, y: b.0).concatenating(Self.tf(60, 14, scale: 0.65)), g[3], b.1)
            }
        }
    }
}

/// El movimiento de entrada del dibujo de temporada: arranca una sola vez por apertura de la app, la primera vez que el título del mes se ve,
/// dura unos segundos y luego todo queda quieto como siempre. Con «Reducir movimiento» no se anima nada.
@MainActor @Observable final class SeasonMotion {
    static let shared = SeasonMotion()
    var start: Date?
    var done = false
    private var run = 0
    func begin(reduceMotion: Bool) {
        guard start == nil, !done else { return }
        play(reduceMotion: reduceMotion)
    }
    /// Arranca (o vuelve a arrancar) el movimiento: al abrir la app y cada vez que cambias de mes.
    func play(reduceMotion: Bool) {
        if reduceMotion { done = true; return }
        run += 1
        let mine = run
        done = false
        start = Date()
        Task { try? await Task.sleep(for: .seconds(SeasonArt.total + 0.3)); if mine == self.run { self.done = true } }
    }
}

/// El título del mes del Resumen: temporada y año en pequeño, el mes en grande con degradado y el dibujo de la temporada a los lados.
struct MonthHeader: View {
    let month0: Int
    let year: Int
    let hemi: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var seen = false

    var body: some View {
        let season = Season.of(month0: month0, hemi: hemi)
        let g = season.palette
        let s1 = scheme == .dark ? g[0] : g[1]
        let s2 = scheme == .dark ? g[1] : g[2]
        let name = Spanish.monthsFull[month0].capitalized
        HStack(spacing: 0) {
            Color.clear.frame(maxWidth: .infinity, minHeight: 50)
                .overlay(alignment: .trailing) { SeasonArt(season: season).padding(.trailing, -8) }
                .clipped()
            VStack(spacing: 0) {
                Text("\(season.name) \(String(year))").font(.inter(15, .semibold)).tracking(-0.1).foregroundStyle(s1)
                Text(name)
                    .font(.inter(40, .heavy, relativeTo: .largeTitle))
                    .tracking(-1.4)
                    .foregroundStyle(LinearGradient(colors: [s1, s2], startPoint: .leading, endPoint: .trailing))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.leading, 2).padding(.trailing, 2 + 1.4).padding(.bottom, 4)   // el tracking negativo deja la tinta 0.7 pt a la derecha del centro
            }
            .layoutPriority(1)
            .background {
                EllipticalGradient(colors: [s1.opacity(0.2), .clear], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .padding(.horizontal, -44).padding(.vertical, -14)
                    .allowsHitTesting(false)
            }
            Color.clear.frame(maxWidth: .infinity, minHeight: 50)
                .overlay(alignment: .leading) { SeasonArt(season: season, right: true).padding(.leading, -8) }
                .clipped()
        }
        .padding(.top, 16).padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .onScrollVisibilityChange(threshold: 0.6) { seen = $0 }
        .onChange(of: year * 12 + month0) { _, _ in
            // al cambiar de mes en el selector, el dibujo vuelve a moverse una vez
            if SeasonMotion.shared.start != nil || SeasonMotion.shared.done { SeasonMotion.shared.play(reduceMotion: reduceMotion) }
        }
        .task(id: seen) {
            guard seen else { return }
            while !model.splashDone || AppLock.shared.locked { try? await Task.sleep(for: .milliseconds(100)); if Task.isCancelled { return } }
            SeasonMotion.shared.begin(reduceMotion: reduceMotion)
        }
    }
}
