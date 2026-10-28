import SwiftUI
import UIKit
import PlataCore

// El avatar del perfil de la web (`avatarHTML`, `laurelSVG`, `gradeBadge`, `profileViewHTML`):
// foto con un aro del color de la nota del mes pasado, insignia con la letra en la esquina y,
// con notas altas, una corona de laurel alrededor.

// MARK: foto (data URL jpeg, igual que la web: `photo` 256 px, `photoSrc` 640 px, `photoCrop`)

enum PhotoCodec {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(fromDataURL s: String) -> UIImage? {
        guard s.hasPrefix("data:image/"), let comma = s.firstIndex(of: ",") else { return nil }
        let key = NSString(string: "\(s.count)-\(s.hashValue)")
        if let hit = cache.object(forKey: key) { return hit }
        guard let data = Data(base64Encoded: String(s[s.index(after: comma)...])), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    static func dataURL(_ img: UIImage, quality: CGFloat) -> String? {
        img.jpegData(compressionQuality: quality).map { "data:image/jpeg;base64," + $0.base64EncodedString() }
    }

    private static func format() -> UIGraphicsImageRendererFormat {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = true
        return f
    }

    /// La imagen entera con 640 px como máximo, sobre fondo blanco (`readPhotoSrc`).
    static func fitted(_ img: UIImage, maxEdge: CGFloat = 640) -> UIImage {
        let w = img.size.width, h = img.size.height
        let k = min(1, maxEdge / max(w, h))
        let size = CGSize(width: max(1, (w * k).rounded()), height: max(1, (h * k).rounded()))
        return UIGraphicsImageRenderer(size: size, format: format()).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Un cuadrado de la imagen (en puntos de la imagen) reducido a `side` px (`cropOpen` → «Listo»).
    static func square(_ img: UIImage, from r: CGRect, side: CGFloat = 256) -> UIImage {
        let size = CGSize(width: side, height: side)
        let k = side / r.width
        return UIGraphicsImageRenderer(size: size, format: format()).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            img.draw(in: CGRect(x: -r.minX * k, y: -r.minY * k, width: img.size.width * k, height: img.size.height * k))
        }
    }
}

extension AppModel {
    /// La foto de perfil guardada, si hay una válida.
    var avatarImage: UIImage? {
        PhotoCodec.image(fromDataURL: Engine.text(engine.data["settings"]?["photo"]))
    }

    var photoSource: UIImage? {
        PhotoCodec.image(fromDataURL: Engine.text(engine.data["settings"]?["photoSrc"]))
    }

    var photoCrop: PhotoCrop? {
        guard let c = engine.data["settings"]?["photoCrop"], Engine.flag(c) else { return nil }
        return PhotoCrop(x: Engine.number(c["x"]), y: Engine.number(c["y"]), z: Engine.number(c["z"]))
    }
}

struct PhotoCrop: Equatable {
    var x: Double
    var y: Double
    var z: Double
}

// MARK: colores de la nota

extension AvatarInfo {
    var palette: [Color] { level == .none ? GradePalette.letter(letter) : GradePalette.tier(letter, level) }
}

// MARK: insignia

/// La insignia de la nota: círculo con la letra, rombo («+»), triángulo («−») o gema (Diamante).
struct GradeBadge: View {
    enum Kind { case circle, diamond, triangle, gem }
    let label: String
    let kind: Kind
    let g: [Color]
    /// Lado de la caja que ocupa.
    let box: CGFloat
    /// El rombo de la ficha de Resumen es más grande que el del avatar (`letterCut` con `full`).
    var full = true

    static func kind(for label: String) -> Kind {
        if label == "S*" { return .gem }
        if label.count == 2, label.hasSuffix("+") { return .diamond }
        if label.count == 2, label.hasSuffix("-") { return .triangle }
        return .circle
    }

    var body: some View {
        GradeFill(g: g)
            .frame(width: box, height: box)
            .mask { BadgeMask(label: label, kind: kind, full: full) }
            .frame(width: box, height: box)
            .accessibilityLabel(Text(label == "S*" ? "Diamante" : label))
    }
}

private struct BadgeMask: View {
    let label: String
    let kind: GradeBadge.Kind
    let full: Bool

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 100
            ctx.scaleBy(x: s, y: s)
            let black = GraphicsContext.Shading.color(.black)
            let two = label.count > 1
            var fs: CGFloat = 0
            var y0: CGFloat = 50
            switch kind {
            case .circle:
                ctx.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100)), with: black)
                fs = two ? 50 : 64
            case .diamond:
                let r: CGRect = full ? CGRect(x: 10.7, y: 10.7, width: 78.6, height: 78.6) : CGRect(x: 19, y: 19, width: 62, height: 62)
                let t = CGAffineTransform(translationX: -50, y: -50).concatenating(CGAffineTransform(rotationAngle: .pi / 4)).concatenating(CGAffineTransform(translationX: 50, y: 50))
                ctx.fill(Path(roundedRect: r, cornerRadius: full ? 16 : 14, style: .continuous).applying(t), with: black)
                fs = full ? (two ? 42 : 54) : (two ? 37 : 50)
            case .triangle:
                let p = AvatarShapes.triangle()
                ctx.fill(p, with: black)
                ctx.stroke(p, with: black, style: StrokeStyle(lineWidth: 26, lineJoin: .round))
                fs = two ? 38 : 48
                y0 = 47
            case .gem:
                let p = AvatarShapes.gem()
                ctx.fill(p, with: black)
                ctx.stroke(p, with: black, style: StrokeStyle(lineWidth: 16, lineJoin: .round))
            }
            if kind != .gem {
                ctx.blendMode = .destinationOut
                ctx.draw(Text(label).font(.system(size: fs, weight: .heavy)).kerning(-1), at: CGPoint(x: 50, y: y0), anchor: .center)
            }
        }
    }
}

enum AvatarShapes {
    /// El triángulo (`TRI`) y la gema (`GEM`) de la web, en una caja de 100.
    static func triangle() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 19, y: 25)); p.addLine(to: CGPoint(x: 81, y: 25)); p.addLine(to: CGPoint(x: 50, y: 73)); p.closeSubpath()
        return p
    }

    static func gem() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 31, y: 29)); p.addLine(to: CGPoint(x: 69, y: 29)); p.addLine(to: CGPoint(x: 87, y: 45))
        p.addLine(to: CGPoint(x: 50, y: 85)); p.addLine(to: CGPoint(x: 13, y: 45)); p.closeSubpath()
        return p
    }

    /// La forma rellena y engordada `stroke` (el hueco que se recorta alrededor de una insignia).
    static func fat(_ p: Path, stroke: CGFloat) -> Path {
        p.union(p.strokedPath(StrokeStyle(lineWidth: stroke, lineJoin: .round)))
    }

    /// Una forma de caja 100 puesta con su esquina en (x, y) y de lado `box`.
    static func placed(_ p: Path, x: CGFloat, y: CGFloat, box: CGFloat) -> Path {
        p.applying(CGAffineTransform(scaleX: box / 100, y: box / 100).concatenating(CGAffineTransform(translationX: x, y: y)))
    }

    static func rotatedSquare(center: CGPoint, side: CGFloat, radius: CGFloat) -> Path {
        let r = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        let t = CGAffineTransform(translationX: -center.x, y: -center.y).concatenating(CGAffineTransform(rotationAngle: .pi / 4)).concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        return Path(roundedRect: r, cornerRadius: radius, style: .circular).applying(t)
    }
}

// MARK: avatar

/// Foto de perfil con aro y insignia. Sin foto, un círculo del color de la nota con una persona.
struct AvatarView: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat
    /// `false` = sin insignia ni recorte (como `nobadge` de la web).
    var badge = true
    /// Para mostrar una foto distinta de la guardada (por ejemplo, al elegirla).
    var photo: UIImage?? = nil

    private static let fallback = GradePalette.colors(["#C9CFDD", "#98A2BA", "#5A6482", "#E1E6F2"])

    var body: some View {
        let info = model.engine.avatarInfo()
        let img: UIImage? = photo ?? model.avatarImage
        if let img {
            if let info { ringed(img, info) } else { plain(img) }
        } else {
            placeholder(info?.palette ?? Self.fallback)
        }
    }

    private func placeholder(_ g: [Color]) -> some View {
        ZStack {
            GradeFill(g: g)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.82))
                .foregroundStyle(.white)
                .offset(y: size * 0.2)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func plain(_ img: UIImage) -> some View {
        Image(uiImage: img).resizable().scaledToFill()
            .frame(width: size, height: size)
            .background(Color(.tertiarySystemFill))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func ringed(_ img: UIImage, _ info: AvatarInfo) -> some View {
        let sz = size
        let rw = max(2, (sz * 0.055).rounded())
        let bs = (sz * 0.38).rounded()
        let bw = max(2, (sz * 0.035).rounded())
        let off = (bs * 0.12).rounded()
        let bc = sz + off - bs / 2
        let kind = GradeBadge.kind(for: info.label)
        let box: CGFloat = bs * (kind == .gem ? 1.55 : (kind == .triangle ? 1.32 : 1.42))
        let hole = BadgeHole(kind: kind, bc: bc, cr: bs / 2 + bw, bw: bw, box: box)
        let g = info.palette
        let inner = sz - 2 * (rw + bw)
        let core = ZStack {
            GradeFill(g: g).frame(width: sz, height: sz).mask { Circle().strokeBorder(Color.black, lineWidth: rw) }
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: inner, height: inner)
                .background(Color(.tertiarySystemFill))
                .clipShape(Circle())
        }
        .frame(width: sz, height: sz)
        return Group {
            if badge {
                core
                    .mask { Rectangle().overlay { hole.fill(Color.black).blendMode(.destinationOut) }.compositingGroup() }
                    .overlay(alignment: .topLeading) {
                        let side = kind == .circle ? bs : box
                        GradeBadge(label: info.label, kind: kind, g: g, box: side, full: false)
                            .offset(x: bc - side / 2, y: bc - side / 2)
                    }
            } else {
                core
            }
        }
        .frame(width: sz, height: sz)
        .accessibilityHidden(true)
    }
}

/// El hueco que deja la insignia en el aro (las máscaras `dcut` / `tcut` / `gcut` de la web).
private struct BadgeHole: Shape {
    let kind: GradeBadge.Kind
    let bc: CGFloat
    let cr: CGFloat
    let bw: CGFloat
    let box: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.minX + bc, y: rect.minY + bc)
        switch kind {
        case .circle:
            return Path(ellipseIn: CGRect(x: c.x - cr, y: c.y - cr, width: cr * 2, height: cr * 2))
        case .diamond:
            let dw = box * 0.62, dr = box * 0.14
            return AvatarShapes.rotatedSquare(center: c, side: dw + 2 * bw, radius: dr + bw)
        case .triangle:
            let p = AvatarShapes.fat(AvatarShapes.triangle(), stroke: 26 + 2 * bw * 100 / box)
            return AvatarShapes.placed(p, x: c.x - box / 2, y: c.y - box / 2, box: box)
        case .gem:
            let p = AvatarShapes.fat(AvatarShapes.gem(), stroke: 16 + 2 * (bw + 0.5) * 100 / box)
            return AvatarShapes.placed(p, x: c.x - box / 2, y: c.y - box / 2, box: box)
        }
    }
}

// MARK: laurel

struct LaurelConfig {
    var n: Int
    var a0: Double
    var a1: Double
    var L: Double
    var W: Double

    static let diamond = LaurelConfig(n: 7, a0: 68, a1: 6, L: 25, W: 6.8)
    static let s = LaurelConfig(n: 3, a0: 62, a1: 36, L: 18, W: 4.6)
    static func plus(_ letter: String) -> LaurelConfig {
        switch letter {
        case "A": return LaurelConfig(n: 5, a0: 65, a1: 6, L: 27, W: 7.4)
        case "B": return LaurelConfig(n: 4, a0: 61, a1: 6, L: 23, W: 6)
        case "C": return LaurelConfig(n: 3, a0: 60, a1: 22, L: 21, W: 5.4)
        default: return diamond
        }
    }
}

/// La corona de laurel (`laurelSVG`): hojas a los dos lados. Con `hole` deja libre el sitio de la insignia.
struct LaurelView: View {
    struct Hole { var kind: GradeBadge.Kind; var cy: CGFloat; var px: CGFloat }
    let size: CGFloat
    let pal: [Color]
    let cfg: LaurelConfig
    var hole: Hole? = nil

    var body: some View {
        Canvas { ctx, _ in
            let c = Double(size) / 2
            let r = c - 11
            var leaves = Path()
            for side in [1.0, -1.0] {
                for i in 0..<cfg.n {
                    let A = cfg.n > 1 ? cfg.a0 + (cfg.a1 - cfg.a0) * Double(i) / Double(cfg.n - 1) : cfg.a0
                    let a = A * .pi / 180
                    let k = 1 - Double(i) * 0.04
                    let x = c + side * r * cos(a), y = c + r * sin(a)
                    let tx = side * sin(a), ty = -cos(a), nx = side * cos(a), ny = sin(a)
                    let t = 32.0 * .pi / 180
                    let dx = tx * cos(t) + nx * sin(t), dy = ty * cos(t) + ny * sin(t)
                    let f = atan2(dy, dx)
                    let co = cos(f), si = sin(f)
                    func P(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: x + (u * co - v * si) * k, y: y + (u * si + v * co) * k) }
                    leaves.move(to: P(-cfg.L / 2, 0))
                    leaves.addQuadCurve(to: P(cfg.L / 2, 0), control: P(0, -cfg.W))
                    leaves.addQuadCurve(to: P(-cfg.L / 2, 0), control: P(0, cfg.W))
                    leaves.closeSubpath()
                }
            }
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [.init(color: pal[0], location: 0), .init(color: pal[1], location: 0.5), .init(color: pal[2], location: 1)]),
                startPoint: CGPoint(x: 0, y: c - 64), endPoint: CGPoint(x: 0, y: c + 64))
            ctx.drawLayer { l in
                l.fill(leaves, with: shading)
                if let hole {
                    l.blendMode = .destinationOut
                    l.fill(holePath(hole, c: CGFloat(c)), with: .color(.black))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func holePath(_ h: Hole, c: CGFloat) -> Path {
        let gap: CGFloat = 4.5
        switch h.kind {
        case .gem:
            let p = AvatarShapes.fat(AvatarShapes.gem(), stroke: 16 + 2 * gap * 100 / h.px)
            return AvatarShapes.placed(p, x: c - h.px / 2, y: h.cy - h.px / 2, box: h.px)
        case .diamond:
            return AvatarShapes.rotatedSquare(center: CGPoint(x: c, y: h.cy), side: h.px * 0.786 + 2 * gap, radius: h.px * 0.16 + gap)
        default:
            let r = h.px / 2 + gap
            return Path(ellipseIn: CGRect(x: c - r, y: h.cy - r, width: r * 2, height: r * 2))
        }
    }
}

// MARK: avatar grande del perfil

/// Lo de arriba de «Perfil»: con S, A+, B+, C+ o Diamante lleva laurel y la insignia en el hueco del aro;
/// con el resto, el avatar y la insignia debajo (`profileViewHTML`).
struct ProfileHero: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let info = model.engine.avatarInfo()
        if let info, let gold = Gold(info) {
            goldHero(info, gold)
        } else if let info, info.label == "S" {
            goldHero(info, Gold(pal: info.palette, cfg: .s, a0: 76, gem: false, diamond: false))
        } else {
            VStack(spacing: 0) {
                AvatarView(size: 128, badge: false)
                if let info {
                    let kind = GradeBadge.kind(for: info.label)
                    let box: CGFloat = kind == .diamond ? (34 * 1.18).rounded() : (kind == .triangle ? (34 * 1.22).rounded() : 34)
                    GradeBadge(label: info.label, kind: kind, g: info.palette, box: box).padding(.top, 10)
                }
            }
        }
    }

    private struct Gold {
        var pal: [Color]
        var cfg: LaurelConfig
        var a0: Double
        var gem: Bool
        var diamond: Bool

        /// `goldGrade` de la web: S*, S+, A+ (dorado) y B+, C+ (platino).
        init?(_ i: AvatarInfo) {
            if i.label == "S*" { self.init(pal: GradePalette.diamond, cfg: .diamond, a0: 80, gem: true, diamond: false) }
            else if i.label == "S+" || i.label == "A+" { self.init(pal: GradePalette.champagne, cfg: .plus(i.letter), a0: 80, gem: false, diamond: true) }
            else if i.label == "B+" || i.label == "C+" { self.init(pal: GradePalette.platinum, cfg: .plus(i.letter), a0: 80, gem: false, diamond: true) }
            else { return nil }
        }

        init(pal: [Color], cfg: LaurelConfig, a0: Double, gem: Bool, diamond: Bool) {
            self.pal = pal; self.cfg = cfg; self.a0 = a0; self.gem = gem; self.diamond = diamond
        }
    }

    private func goldHero(_ info: AvatarInfo, _ gold: Gold) -> some View {
        let gp: CGFloat = 4, cy: CGFloat = 152, ac = cy - 24
        let bp: CGFloat = gold.gem ? 34 * 1.28 : (gold.diamond ? 34 * 1.18 : 34)
        let hs = gold.diamond ? bp * 0.786 : bp
        let kind: GradeBadge.Kind = gold.gem ? .gem : (gold.diamond ? .diamond : .circle)
        var cfg = gold.cfg
        cfg.a0 = gold.a0
        let badgeLabel = gold.gem ? "S*" : (gold.diamond ? info.letter + "+" : info.label)
        let badgeBox: CGFloat = gold.gem ? bp : (gold.diamond ? (34 * 1.18).rounded() : 34)
        let hole: Path = {
            switch kind {
            case .gem:
                return AvatarShapes.placed(AvatarShapes.fat(AvatarShapes.gem(), stroke: 16 + 2 * (gp + 0.5) * 100 / bp), x: 64 - bp / 2, y: ac - bp / 2, box: bp)
            case .diamond:
                return AvatarShapes.rotatedSquare(center: CGPoint(x: 64, y: ac), side: hs + 2 * gp, radius: bp * 0.16 + gp)
            default:
                let r = bp / 2 + gp
                return Path(ellipseIn: CGRect(x: 64 - r, y: ac - r, width: r * 2, height: r * 2))
            }
        }()
        return ZStack(alignment: .topLeading) {
            LaurelView(size: 176, pal: gold.pal, cfg: cfg, hole: .init(kind: kind, cy: cy, px: bp))
            AvatarView(size: 128, badge: false)
                .mask { Rectangle().overlay { hole.fill(Color.black).blendMode(.destinationOut) }.compositingGroup().frame(width: 128, height: 128) }
                .offset(x: 24, y: 24)
            GradeBadge(label: badgeLabel, kind: kind, g: gold.pal, box: badgeBox)
                .offset(x: 88 - badgeBox / 2, y: cy - badgeBox / 2)
        }
        .frame(width: 176, height: 176)
        .padding(.top, -8).padding(.bottom, 6)
    }
}
