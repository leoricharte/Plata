import SwiftUI
import PlataCore

/// Logos de bancos y de suscripciones (los de la web: `BANKS` y `SUBBRANDS`), cargados de `Brands.json`.
struct BrandShape { let path: Path; let accFill: Color; let cardFill: Color; let opacity: Double; let evenOdd: Bool }

struct BankBrand {
    let keys: [String]
    let bg: Color
    let fixed: Bool
    let box: CGRect
    let size: CGFloat
    let shapes: [BrandShape]
    /// Recuadro (en coordenadas del trazo) que recorta el logotipo completo para dejar solo el icono: el `<svg>` anidado de la web.
    var clip: CGRect? = nil
}

struct SubBrand {
    let id: String
    let bg: Color
    /// Color del glifo (la mayoría de las marcas lo dibujan en blanco; Apple Music, en negro sobre blanco).
    var fg: Color = .white
    let vb: Bool
    let bb: [CGFloat]?
    let k: CGFloat
    let evenOdd: Bool
    let keys: [String]
    let path: Path
}

enum Brands {
    private struct RawShape: Decodable { let d: String; let a: String; let aD: String?; let c: String; let o: Double; let eo: Bool }
    private struct RawBank: Decodable { let keys: [String]; let bg: String; let bgD: String?; let fixed: Bool; let box: [CGFloat]; let sz: CGFloat; let shapes: [RawShape] }
    private struct RawSub: Decodable { let i: String; let bg: String; let fg: String?; let vb: Bool; let bb: [CGFloat]?; let k: CGFloat; let eo: Bool; let keys: [String]; let d: String }
    private struct Raw: Decodable { let banks: [RawBank]; let subs: [RawSub] }

    static let (banks, subs): ([BankBrand], [SubBrand]) = {
        guard let url = Bundle.main.url(forResource: "Brands", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return ([], []) }
        let b = raw.banks.map { r in
            BankBrand(keys: r.keys, bg: Brands.themed(r.bg, r.bgD), fixed: r.fixed, box: CGRect(x: r.box[0], y: r.box[1], width: r.box[2], height: r.box[3]), size: r.sz,
                      shapes: r.shapes.map { BrandShape(path: SVGPath.parse($0.d), accFill: Brands.themed($0.a, $0.aD), cardFill: Color(hex: $0.c), opacity: $0.o, evenOdd: $0.eo) })
        }
        let s = raw.subs.map { r in
            SubBrand(id: r.i, bg: Color(hex: r.bg), fg: r.fg.map { Color(hex: $0) } ?? .white, vb: r.vb, bb: r.bb, k: r.k, evenOdd: r.eo, keys: r.keys, path: SVGPath.parse(r.d))
        }
        return (b, s)
    }()

    /// Un color que cambia con el tema cuando el logo trae variante oscura (Plin: fondo blanco y burbuja celeste en claro; al revés en oscuro).
    fileprivate static func themed(_ light: String, _ dark: String?) -> Color {
        guard let dark else { return Color(hex: light) }
        return Color(light: light, dark: dark)
    }

    static func norm(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }

    /// `key` aparece como palabra completa dentro de `n` (la regla `(^|[^a-z0-9])key([^a-z0-9]|$)` de la web).
    private static func contains(_ n: String, _ key: String, spaces: Bool) -> Bool {
        let pat = "(^|[^a-z0-9])" + (spaces ? NSRegularExpression.escapedPattern(for: key).replacingOccurrences(of: "\\ ", with: "[^a-z0-9]*").replacingOccurrences(of: " ", with: "[^a-z0-9]*") : NSRegularExpression.escapedPattern(for: key)) + "([^a-z0-9]|$)"
        return n.range(of: pat, options: .regularExpression) != nil
    }

    static func bank(named name: String) -> BankBrand? {
        let n = norm(name)
        if n.isEmpty { return nil }
        return banks.first { b in b.keys.contains { contains(n, $0, spaces: false) } }
    }

    static func sub(named name: String) -> SubBrand? {
        let n = norm(name)
        if n.isEmpty { return nil }
        return subs.first { b in b.keys.contains { contains(n, $0, spaces: true) } }
    }

    /// El logo gana, salvo que la persona haya elegido un icono a mano (`bankPick`).
    static func bankPick(_ o: JSONValue) -> BankBrand? {
        if !Engine.text(o["icon"]).isEmpty && Engine.flag(o["iconUser"]) { return nil }
        return bank(named: Engine.text(o["name"]))
    }
}

/// Dibuja las formas de un banco en el lienzo de 460 de la web, escalado a `side`.
struct BankGlyph: View {
    let bank: BankBrand
    let card: Bool
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 460
            let bs = bank.size / max(bank.box.width, bank.box.height)
            let w = bank.box.width * bs, h = bank.box.height * bs
            let ox = (460 - w) / 2, oy = (460 - h) / 2
            let t = CGAffineTransform(translationX: -bank.box.minX, y: -bank.box.minY)
                .concatenating(CGAffineTransform(scaleX: bs, y: bs))
                .concatenating(CGAffineTransform(translationX: ox, y: oy))
                .concatenating(CGAffineTransform(scaleX: k, y: k))
            if !card { ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)), with: .color(bank.bg)) }
            if let c = bank.clip { ctx.clip(to: Path(c).applying(t)) }
            for s in bank.shapes {
                let path = s.path.applying(t)
                ctx.opacity = card ? s.opacity : 1
                ctx.fill(path, with: .color(card ? s.cardFill : s.accFill), style: FillStyle(eoFill: s.evenOdd))
            }
        }
        .allowsHitTesting(false)
    }
}

struct SubGlyph: View {
    let brand: SubBrand
    var body: some View {
        Canvas { ctx, size in
            var vx: CGFloat = 0, vy: CGFloat = 0, sd: CGFloat = 24
            if brand.vb, let bb = brand.bb {
                sd = max(bb[2], bb[3]) / brand.k
                vx = bb[0] + bb[2] / 2 - sd / 2
                vy = bb[1] + bb[3] / 2 - sd / 2
            }
            let k = size.width / sd
            let t = CGAffineTransform(translationX: -vx, y: -vy).concatenating(CGAffineTransform(scaleX: k, y: k))
            ctx.fill(brand.path.applying(t), with: .color(brand.fg), style: FillStyle(eoFill: brand.evenOdd))
        }
        .allowsHitTesting(false)
    }
}

/// Cuadrito de suscripción: logo de marca si lo reconoce, si no la letra (`subTile`).
struct SubTile: View {
    let name: String
    let fallback: Color
    var size: CGFloat = 46
    var body: some View {
        if let b = Brands.sub(named: name) {
            ZStack {
                if b.vb { SubGlyph(brand: b).frame(width: size, height: size) }
                else { SubGlyph(brand: b).frame(width: size * 0.565, height: size * 0.565) }
            }
            .frame(width: size, height: size)
            .background(b.bg, in: RoundedRectangle(cornerRadius: size * 0.283, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.283, style: .continuous))
            .accessibilityHidden(true)
        } else {
            LetterTile(letter: String(name.prefix(1)), color: fallback)
        }
    }
}

/// Cuadrito de cuenta o tarjeta (`tileObj`): logo del banco, icono elegido o glifo de siempre.
struct AccountTile: View {
    let o: JSONValue
    let color: String
    let debt: Bool
    var size: CGFloat = 46
    var body: some View {
        let col = Color(hex: color)
        let bk = Brands.bankPick(o)
        let r = size * 0.283
        if let bk {
            if !debt && !bk.fixed && Engine.flag(o["colorUser"]) && !Engine.text(o["color"]).isEmpty || (debt && !bk.fixed) {
                BankGlyph(bank: bk, card: true).frame(width: size, height: size)
                    .background(col, in: RoundedRectangle(cornerRadius: r, style: .continuous)).accessibilityHidden(true)
            } else {
                BankGlyph(bank: bk, card: false).frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous)).accessibilityHidden(true)
            }
        } else if let s = iconSymbol(Engine.text(o["icon"])) {
            Tile(symbol: s, color: col, size: size)
        } else if debt {
            Tile(symbol: "creditcard", color: col, size: size)
        } else {
            LetterTile(letter: String(Engine.text(o["name"]).prefix(1)), color: col)
        }
    }
}
