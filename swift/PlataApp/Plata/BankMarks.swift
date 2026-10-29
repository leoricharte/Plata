import SwiftUI

/// Las marcas de cada banco en la pantalla de importar (`IMP_MARKS` de la web): el glifo cuadrado de las listas y el logo completo de la pantalla del banco.
/// Se dibujan con el color del texto (`foregroundStyle`), igual que `currentColor` en la web.
enum BankMarks {
    struct Shape { let path: Path; let evenOdd: Bool }
    /// `clip`: el recuadro interno que recorta un logotipo completo para dejar solo el icono (el `<svg>` anidado de la web).
    struct Mark { let vb: CGRect; let gs: CGFloat?; let clip: CGRect?; let shapes: [Shape] }
    struct Entry { let glyph: Mark; let logo: Mark; let h: CGFloat }

    private struct RawShape: Decodable { let d: String?; let eo: Bool?; let p: String? }
    private struct RawMark: Decodable { let vb: [CGFloat]; let gs: CGFloat?; let clip: [CGFloat]?; let s: [RawShape] }
    private struct RawEntry: Decodable { let glyph: RawMark; let logo: RawMark; let h: CGFloat }

    private static func polygon(_ points: String) -> Path {
        let n = points.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }).compactMap { Double($0) }
        var p = Path()
        var i = 0
        while i + 1 < n.count {
            let pt = CGPoint(x: n[i], y: n[i + 1])
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            i += 2
        }
        p.closeSubpath()
        return p
    }

    private static func mark(_ r: RawMark) -> Mark {
        let shapes = r.s.map { s -> Shape in
            if let d = s.d { return Shape(path: SVGPath.parse(d), evenOdd: s.eo ?? false) }
            return Shape(path: polygon(s.p ?? ""), evenOdd: false)
        }
        let clip = (r.clip?.count == 4) ? CGRect(x: r.clip![0], y: r.clip![1], width: r.clip![2], height: r.clip![3]) : nil
        return Mark(vb: CGRect(x: r.vb[0], y: r.vb[1], width: r.vb[2], height: r.vb[3]), gs: r.gs, clip: clip, shapes: shapes)
    }

    static let all: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "bank_marks", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode([String: RawEntry].self, from: data) else { return [:] }
        return raw.mapValues { Entry(glyph: mark($0.glyph), logo: mark($0.logo), h: $0.h) }
    }()
}

private struct MarkCanvas: View {
    let mark: BankMarks.Mark
    var body: some View {
        Canvas { ctx, size in
            let vb = mark.vb
            let s = min(size.width / vb.width, size.height / vb.height)
            let t = CGAffineTransform(translationX: (size.width - vb.width * s) / 2 - vb.minX * s, y: (size.height - vb.height * s) / 2 - vb.minY * s).scaledBy(x: s, y: s)
            if let c = mark.clip { ctx.clip(to: Path(c).applying(t)) }
            for sh in mark.shapes { ctx.fill(sh.path.applying(t), with: .foreground, style: FillStyle(eoFill: sh.evenOdd)) }
        }
    }
}

/// La marca de un banco. `logo` = el logo completo (alto fijo); si no, el glifo cuadrado. Sin marca propia, un edificio genérico.
struct BankMarkView: View {
    let id: String
    var logo = false
    /// Tamaño del glifo; por defecto el de la web para ese banco.
    var size: CGFloat? = nil

    var body: some View {
        if let e = BankMarks.all[id] {
            if logo {
                MarkCanvas(mark: e.logo)
                    .aspectRatio(e.logo.vb.width / e.logo.vb.height, contentMode: .fit)
                    .frame(height: e.h)
                    .accessibilityHidden(true)
            } else {
                let g = size ?? e.glyph.gs ?? 26
                MarkCanvas(mark: e.glyph).frame(width: g, height: g).accessibilityHidden(true)
            }
        } else {
            Image(systemName: "building.columns").font(.system(size: size ?? 22)).accessibilityHidden(true)
        }
    }
}
