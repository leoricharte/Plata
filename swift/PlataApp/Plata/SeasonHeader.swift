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

    var body: some View {
        let g = season.palette
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 72, y: size.height / 56)
            func fill(_ path: Path, _ t: CGAffineTransform, _ color: Color, _ opacity: Double = 1) {
                ctx.fill(path.applying(t), with: .color(color.opacity(opacity)))
            }
            func stroke(_ path: Path, _ t: CGAffineTransform, _ color: Color, _ width: CGFloat, _ opacity: Double = 1) {
                ctx.stroke(path.applying(t), with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            let none = CGAffineTransform.identity
            switch season {
            case .autumn:
                fill(Self.leaf, Self.tf(18, 22, rot: -25, scale: 1.15), g[1], 0.95)
                fill(Self.leaf, Self.tf(46, 38, rot: 32, scale: 0.85), g[0])
                fill(Self.leaf, Self.tf(60, 12, rot: 62, scale: 0.6), g[2], 0.75)
            case .winter:
                stroke(Self.flake, Self.tf(18, 24, scale: 1.3), g[1], 2.2 * 1.3)
                stroke(Self.flake, Self.tf(46, 40, scale: 0.9), g[0], 2.2 * 0.9)
                stroke(Self.flake, Self.tf(60, 14, scale: 0.65), g[2], 2.2 * 0.65)
            case .spring:
                let petal = Path(ellipseIn: CGRect(x: -11, y: -5.5, width: 22, height: 11))
                fill(petal, Self.tf(20, 24, rot: -35), g[0], 0.95)
                fill(petal, Self.tf(46, 38, rot: 28), g[1], 0.9)
                fill(petal, Self.tf(60, 14, rot: -10, scale: 0.7), g[3], 0.9)
            case .summer:
                if right {
                    stroke(Self.wave(14), none, g[0], 2.4, 0.7)
                    stroke(Self.wave(25), none, g[1], 2.4, 1)
                    stroke(Self.wave(36), none, g[0], 2.4, 0.7)
                } else {
                    fill(Path(ellipseIn: CGRect(x: 11.5, y: 15.5, width: 17, height: 17)), none, g[0])
                    stroke(Self.rays, none, g[0], 2.4)
                }
                fill(Self.sparkle, Self.tf(48, 40), g[1], 0.95)
                fill(Self.sparkle, Self.tf(60, 14, scale: 0.65), g[3])
            }
        }
        .frame(width: 64, height: 50)
        .scaleEffect(x: right ? -1 : 1, y: 1)
        .accessibilityHidden(true)
    }
}

/// El título del mes del Resumen: temporada y año en pequeño, el mes en grande con degradado y el dibujo de la temporada a los lados.
struct MonthHeader: View {
    let month0: Int
    let year: Int
    let hemi: String
    @Environment(\.colorScheme) private var scheme

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
                    .padding(.horizontal, 2).padding(.bottom, 4)
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
        .padding(.top, 6).padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }
}
