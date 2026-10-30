import SwiftUI

/// El icono de la nota (el mismo de `GradeTile` en la app) para widgets y complicaciones, que no ven `PlataCore`.
/// Cuadrado con la letra recortada; con racha: rombo con «+» (S–C), triángulo con «−» (D, F) o gema (Diamante).
/// `tier`: "none", "plus" o "diamond".
struct GradeMark: View {
    let letter: String
    var tier: String? = nil
    var size: CGFloat = 52

    private enum Kind { case square, diamond, triangle, gem }

    private static func hex(_ v: UInt32) -> Color { Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) }
    private static func pal(_ l: [UInt32]) -> [Color] { l.map(hex) }

    private var palette: [Color] {
        if tier == "diamond" { return Self.pal([0xEAFBFF, 0x8ED6F3, 0x4A7FD6, 0xFFFFFF]) }
        if tier == "plus" {
            switch letter {
            case "S", "A": return Self.pal([0xF6E3A8, 0xD9B35F, 0x8A6527, 0xFFF3CF])
            case "B", "C": return Self.pal([0xE3E7EE, 0xA7B1C0, 0x505A6C, 0xFFFFFF])
            case "D": return Self.pal([0xFF7A5C, 0xD6302E, 0x5A0E1F, 0xFF9F7A])
            default: return Self.pal([0xFF4D4D, 0xB3122C, 0x3C0614, 0xFF7A6B])
            }
        }
        switch letter {
        case "S": return Self.pal([0xC9A2FF, 0x6D6BF2, 0x1F1B6B, 0x5CC8FF])
        case "A": return Self.pal([0x6BE59A, 0x1FA67A, 0x0C4558, 0xC4F54D])
        case "C": return Self.pal([0xFFE75A, 0xF8BC2A, 0xA0600C, 0xFFF4A8])
        case "D": return Self.pal([0xFF9A3C, 0xE8472B, 0x7A1A33, 0xFFB36B])
        case "F": return Self.pal([0xFF6A5C, 0xC73A52, 0x51103A, 0xFF9F6B])
        default: return Self.pal([0x58D1AE, 0x2A8FA8, 0x1B3F7A, 0x9BF0DC])
        }
    }

    var body: some View {
        let isLow = letter == "D" || letter == "F"
        let kind: Kind = (tier == "diamond" && letter == "S") ? .gem : (tier == "plus" ? (isLow ? .triangle : .diamond) : .square)
        let label = tier == "diamond" ? "Diamante" : (tier == "plus" ? letter + (isLow ? "-" : "+") : letter)
        let k: CGFloat = kind == .gem ? 1.28 : (kind == .diamond ? 1.18 : (kind == .triangle ? 1.22 : 1))
        let box = (size * k).rounded()
        let g = palette
        ZStack {
            LinearGradient(stops: [.init(color: g[0], location: 0), .init(color: g[1], location: 0.48), .init(color: g[2], location: 1)], startPoint: .top, endPoint: .bottom)
            EllipticalGradient(colors: [g[3].opacity(0.8), .clear], center: UnitPoint(x: 0.88, y: 0), startRadiusFraction: 0, endRadiusFraction: 0.66)
            EllipticalGradient(colors: [g[0].opacity(0.33), .clear], center: UnitPoint(x: 0, y: 1), startRadiusFraction: 0, endRadiusFraction: 0.54)
        }
        .frame(width: box, height: box)
        .mask { MarkMask(kind: kind == .square ? 0 : kind == .diamond ? 1 : kind == .triangle ? 2 : 3, label: label, box: box) }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(label))
    }
}

private struct MarkMask: View {
    let kind: Int
    let label: String
    let box: CGFloat

    var body: some View {
        let s = box / 100
        let two = label.count > 1
        ZStack {
            switch kind {
            case 1:
                RoundedRectangle(cornerRadius: 16 * s, style: .continuous).frame(width: 78.6 * s, height: 78.6 * s).rotationEffect(.degrees(45))
            case 2:
                MarkPoly(pts: [(19, 25), (81, 25), (50, 73)]).fill(.black)
                MarkPoly(pts: [(19, 25), (81, 25), (50, 73)]).stroke(.black, style: StrokeStyle(lineWidth: 26 * s, lineJoin: .round))
            case 3:
                MarkPoly(pts: [(31, 29), (69, 29), (87, 45), (50, 85), (13, 45)]).fill(.black)
                MarkPoly(pts: [(31, 29), (69, 29), (87, 45), (50, 85), (13, 45)]).stroke(.black, style: StrokeStyle(lineWidth: 16 * s, lineJoin: .round))
            default:
                RoundedRectangle(cornerRadius: 32 * s, style: .continuous).frame(width: box, height: box)
            }
            if kind != 3 {
                let fs: CGFloat = kind == 1 ? (two ? 42 : 54) : kind == 2 ? (two ? 38 : 48) : (two ? 44 : 56)
                Text(label).font(.system(size: fs * s, weight: .heavy)).kerning(-1).blendMode(.destinationOut)
                    .offset(y: kind == 2 ? -3 * s : 0)
            }
        }
        .frame(width: box, height: box)
        .compositingGroup()
    }
}

private struct MarkPoly: Shape {
    let pts: [(CGFloat, CGFloat)]
    func path(in r: CGRect) -> Path {
        let s = r.width / 100
        var p = Path()
        for (i, q) in pts.enumerated() { let c = CGPoint(x: q.0 * s, y: q.1 * s); if i == 0 { p.move(to: c) } else { p.addLine(to: c) } }
        p.closeSubpath()
        return p
    }
}
