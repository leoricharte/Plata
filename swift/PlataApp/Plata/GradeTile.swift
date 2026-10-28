import SwiftUI
import PlataCore

/// Las paletas de la nota (S, A, B, C, D, F) y de las rachas, las mismas de la web (`GRAD`, `CHAMP`, `PLAT`, `REDD`, `REDF`, `DIAM`).
enum GradePalette {
    static func colors(_ hex: [String]) -> [Color] { hex.map { Color(hex: $0) } }

    static func letter(_ l: String) -> [Color] {
        switch l {
        case "S": return colors(["#C9A2FF", "#6D6BF2", "#1F1B6B", "#5CC8FF"])
        case "A": return colors(["#6BE59A", "#1FA67A", "#0C4558", "#C4F54D"])
        case "C": return colors(["#FFE75A", "#F8BC2A", "#A0600C", "#FFF4A8"])
        case "D": return colors(["#FF9A3C", "#E8472B", "#7A1A33", "#FFB36B"])
        case "F": return colors(["#FF6A5C", "#C73A52", "#51103A", "#FF9F6B"])
        default: return colors(["#58D1AE", "#2A8FA8", "#1B3F7A", "#9BF0DC"])
        }
    }

    static let champagne = colors(["#F6E3A8", "#D9B35F", "#8A6527", "#FFF3CF"])
    static let platinum = colors(["#E3E7EE", "#A7B1C0", "#505A6C", "#FFFFFF"])
    static let redDark = colors(["#FF7A5C", "#D6302E", "#5A0E1F", "#FF9F7A"])
    static let redDeep = colors(["#FF4D4D", "#B3122C", "#3C0614", "#FF7A6B"])
    static let diamond = colors(["#EAFBFF", "#8ED6F3", "#4A7FD6", "#FFFFFF"])

    /// Colores de la racha (`tierG`): diamante, o el dorado/platino/rojo de la letra.
    static func tier(_ l: String, _ level: StreakLevel) -> [Color] {
        if level == .diamond { return diamond }
        switch l {
        case "S", "A": return champagne
        case "B", "C": return platinum
        case "D": return redDark
        default: return redDeep
        }
    }
}

/// El fondo con brillos de la web (`insBg`): degradado vertical y dos resplandores.
struct GradeFill: View {
    let g: [Color]
    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: g[0], location: 0), .init(color: g[1], location: 0.48), .init(color: g[2], location: 1)],
                           startPoint: .top, endPoint: .bottom)
            EllipticalGradient(colors: [g[3].opacity(0.8), .clear], center: UnitPoint(x: 0.88, y: 0), startRadiusFraction: 0, endRadiusFraction: 0.66)
            EllipticalGradient(colors: [g[0].opacity(0.33), .clear], center: UnitPoint(x: 0, y: 1), startRadiusFraction: 0, endRadiusFraction: 0.54)
        }
    }
}

/// La letra de la nota recortada sobre un cuadrado de color. Con racha de 2 meses o más la forma cambia:
/// rombo con «+» (S, A, B, C), triángulo con «−» (D, F) y gema para el Diamante.
struct GradeTile: View {
    let letter: String
    var level: StreakLevel = .none
    var size: CGFloat = 52

    private enum TileShape { case square, diamond, triangle, gem }

    var body: some View {
        let isLow = letter == "D" || letter == "F"
        let shape: TileShape = (level == .diamond && letter == "S") ? .gem
            : (level == .plus ? (isLow ? .triangle : .diamond) : .square)
        let label = level == .diamond ? "Diamante" : (level == .plus ? letter + (isLow ? "-" : "+") : letter)
        let k: CGFloat = shape == .gem ? 1.28 : (shape == .diamond ? 1.18 : (shape == .triangle ? 1.22 : 1))
        let box = (size * k).rounded()
        let palette: [Color] = level == .none ? GradePalette.letter(letter) : GradePalette.tier(letter, level)
        let twoChars = label.count > 1
        GradeFill(g: palette)
            .frame(width: box, height: box)
            .mask {
                Canvas { ctx, sz in
                    let s = sz.width / 100
                    ctx.scaleBy(x: s, y: s)
                    let black = GraphicsContext.Shading.color(.black)
                    var fontSize: CGFloat = 0
                    var y0: CGFloat = 50
                    switch shape {
                    case .square:
                        ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 32, style: .continuous), with: black)
                        fontSize = twoChars ? 44 : 56
                    case .diamond:
                        let r = Path(roundedRect: CGRect(x: 10.7, y: 10.7, width: 78.6, height: 78.6), cornerRadius: 16, style: .continuous)
                        let t = CGAffineTransform(translationX: -50, y: -50).concatenating(CGAffineTransform(rotationAngle: .pi / 4)).concatenating(CGAffineTransform(translationX: 50, y: 50))
                        ctx.fill(r.applying(t), with: black)
                        fontSize = twoChars ? 42 : 54
                    case .triangle:
                        var p = Path()
                        p.move(to: CGPoint(x: 19, y: 25)); p.addLine(to: CGPoint(x: 81, y: 25)); p.addLine(to: CGPoint(x: 50, y: 73)); p.closeSubpath()
                        ctx.fill(p, with: black)
                        ctx.stroke(p, with: black, style: StrokeStyle(lineWidth: 26, lineJoin: .round))
                        fontSize = twoChars ? 38 : 48
                        y0 = 47
                    case .gem:
                        var p = Path()
                        p.move(to: CGPoint(x: 31, y: 29)); p.addLine(to: CGPoint(x: 69, y: 29)); p.addLine(to: CGPoint(x: 87, y: 45))
                        p.addLine(to: CGPoint(x: 50, y: 85)); p.addLine(to: CGPoint(x: 13, y: 45)); p.closeSubpath()
                        ctx.fill(p, with: black)
                        ctx.stroke(p, with: black, style: StrokeStyle(lineWidth: 16, lineJoin: .round))
                    }
                    if shape != .gem {
                        ctx.blendMode = .destinationOut
                        ctx.draw(Text(label).font(.system(size: fontSize, weight: .heavy)).kerning(-1), at: CGPoint(x: 50, y: y0), anchor: .center)
                    }
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel(Text(label))
    }
}

/// El puntaje que aún no se puede mostrar: contorno punteado y «?».
struct GhostScore: View {
    var size: CGFloat = 52
    var letter = "?"
    var body: some View {
        let g: [Color] = letter == "?" ? [Color(hex: "#C7C7CC"), Color(hex: "#9A9AA2"), Color(hex: "#8E8E93")] : Array(GradePalette.letter(letter).prefix(3))
        ZStack {
            RoundedRectangle(cornerRadius: 20 * size / 64, style: .continuous)
                .stroke(g[1].opacity(0.8), style: StrokeStyle(lineWidth: 2.8 * size / 64, lineCap: .round, dash: [0.01, 5.2 * size / 64]))
                .frame(width: 60 * size / 64, height: 60 * size / 64)
            Text(letter)
                .font(.system(size: 36 * size / 64, weight: .heavy))
                .foregroundStyle(LinearGradient(colors: [g[0], g[1], g[2]], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// «Llevas 1 de 2 meses con B»: puntos de la racha y el texto que la acompaña (`streakHTML`).
struct StreakRow: View {
    let letter: String
    let streak: Int
    let level: StreakLevel

    var body: some View {
        let bad = letter == "D" || letter == "F"
        let mid = letter == "B" || letter == "C"
        let g = GradePalette.letter(letter)
        let pg = GradePalette.tier(letter, level)
        let sign = bad ? "-" : "+"
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if level == .diamond {
                    dot(true, false, g, pg); dot(true, true, g, pg); dot(true, false, g, pg); dot(true, true, g, pg)
                } else {
                    dot(streak >= 1, false, g, pg); dot(streak >= 2, true, g, pg)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                if level == .diamond {
                    gradientText("Diamante · \(streak) meses seguidos", pg)
                    sub("Perfección. En todo su esplendor.")
                } else if level == .plus {
                    gradientText("\(letter)\(sign) · \(streak) meses seguidos", pg)
                    sub(bad ? "Es momento de cambiar el rumbo." : mid ? "Nivel estable. Un ajuste más y subes." : "Mantienes tu nivel. ¡Sigue así!")
                } else {
                    Text("Llevas \(streak) de 2 meses con \(letter).").font(.inter(14, .semibold)).foregroundStyle(.primary.opacity(0.8))
                    sub(bad ? "Si sigues igual, al segundo pasas a \(letter)-." : "Al segundo subes a \(letter)+.")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) { Divider().overlay(Color(.separator).opacity(0.5)) }
        .padding(.top, 14)
    }

    private func dot(_ on: Bool, _ last: Bool, _ g: [Color], _ pg: [Color]) -> some View {
        let color = last ? pg[1] : g[1]
        return Circle()
            .fill(on ? color : Color.clear)
            .overlay(Circle().strokeBorder(on ? Color.clear : (last ? pg[1] : Color(hex: "#C7C7CC")), lineWidth: 2))
            .frame(width: 12, height: 12)
    }

    private func gradientText(_ t: String, _ pg: [Color]) -> some View {
        Text(t).font(.inter(15, .bold))
            .foregroundStyle(LinearGradient(colors: [pg[1], pg[2]], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func sub(_ t: String) -> some View {
        Text(t).font(.inter(13)).foregroundStyle(.secondary)
    }
}
