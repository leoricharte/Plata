import SwiftUI
import PlataCore

/// La captura en un visor de esquinas redondeadas: la persona arrastra en diagonal desde una esquina y encierra una fila, varias o toda la lista.
/// Lo de afuera se oscurece y el cuadro queda con más brillo; las filas que Nazca reconoce dentro se iluminan mientras se arrastra.
struct CaptureRegionView: View {
    let image: UIImage
    let boxes: [NazcaExample.Box]
    @Binding var region: NazcaExample.Region?

    /// Qué está haciendo el dedo: dibujar uno nuevo, moverlo o estirarlo desde una esquina (la opuesta queda fija).
    private enum Mode { case new(CGPoint), move(NazcaExample.Region), resize(CGPoint) }
    @State private var mode: Mode?

    private let corner: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let fit = fitted(in: geo.size)
            ZStack {
                Image(uiImage: image).resizable().frame(width: fit.width, height: fit.height)
                overlay(size: fit)
            }
            .frame(width: fit.width, height: fit.height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(drag(size: fit))
            .frame(width: geo.size.width, height: geo.size.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Tr.t("Captura. Arrastra para encerrar los movimientos."))
        }
    }

    private func fitted(in box: CGSize) -> CGSize {
        let iw = max(image.size.width, 1), ih = max(image.size.height, 1)
        let s = min(box.width / iw, box.height / ih)
        return CGSize(width: iw * s, height: ih * s)
    }

    // MARK: lo que se dibuja encima

    private func rect(_ r: NazcaExample.Region, _ size: CGSize) -> CGRect {
        CGRect(x: r.x * size.width, y: r.y * size.height, width: r.w * size.width, height: r.h * size.height)
    }

    @ViewBuilder private func overlay(size: CGSize) -> some View {
        if let r = region {
            let sel = rect(r, size)
            let bands = NazcaExample.rows(in: r, boxes: boxes)
            Canvas { ctx, sz in
                var dim = Path(CGRect(origin: .zero, size: sz))
                dim.addRect(sel)
                ctx.fill(dim, with: .color(.black.opacity(0.46)), style: FillStyle(eoFill: true))
                ctx.fill(Path(sel), with: .color(.white.opacity(0.10)))
                ctx.stroke(Path(sel), with: .color(.white.opacity(0.55)), lineWidth: 1)
                for b in bands {
                    let band = CGRect(x: sel.minX + 3, y: b.y * sz.height - 2, width: sel.width - 6, height: b.h * sz.height + 4)
                    ctx.fill(Path(roundedRect: band, cornerRadius: 5), with: .color(.white.opacity(0.16)))
                }
            }
            .allowsHitTesting(false)
            ForEach(Array(corners(sel).enumerated()), id: \.offset) { _, p in
                Circle().fill(.white).frame(width: 13, height: 13)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .position(p).allowsHitTesting(false)
            }
            .sensoryFeedback(.selection, trigger: bands.count)
        } else {
            VStack {
                Spacer()
                Text("Arrastra en diagonal sobre los movimientos")
                    .font(.inter(14, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 18)
            }
            .allowsHitTesting(false)
        }
    }

    private func corners(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
    }

    // MARK: el gesto

    private func norm(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: min(1, max(0, p.x / max(size.width, 1))), y: min(1, max(0, p.y / max(size.height, 1))))
    }

    private func make(_ a: CGPoint, _ b: CGPoint) -> NazcaExample.Region {
        NazcaExample.Region(x: min(a.x, b.x), y: min(a.y, b.y), w: abs(a.x - b.x), h: abs(a.y - b.y))
    }

    private func drag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0).onChanged { v in
            if mode == nil {
                mode = pick(at: v.startLocation, size: size)
                if case .new = mode { region = nil }
            }
            let p = norm(v.location, size)
            switch mode {
            case .new(let start): region = make(start, p)
            case .resize(let anchor): region = make(anchor, p)
            case .move(let r0):
                let dx = v.translation.width / max(size.width, 1), dy = v.translation.height / max(size.height, 1)
                region = NazcaExample.Region(x: min(max(0, r0.x + dx), 1 - r0.w), y: min(max(0, r0.y + dy), 1 - r0.h), w: r0.w, h: r0.h)
            case nil: break
            }
        }
        .onEnded { _ in
            mode = nil
            if let r = region, r.w < 0.04 || r.h < 0.008 { region = nil }     // un toque suelto no es un cuadro
        }
    }

    private func pick(at loc: CGPoint, size: CGSize) -> Mode {
        let start = norm(loc, size)
        guard let r = region else { return .new(start) }
        let sel = rect(r, size)
        // una esquina: se estira desde ella y la opuesta queda fija
        let opposite: [CGPoint] = [CGPoint(x: r.x + r.w, y: r.y + r.h), CGPoint(x: r.x, y: r.y + r.h), CGPoint(x: r.x + r.w, y: r.y), CGPoint(x: r.x, y: r.y)]
        for (i, c) in corners(sel).enumerated() where hypot(c.x - loc.x, c.y - loc.y) < 30 { return .resize(opposite[i]) }
        if sel.contains(loc) { return .move(r) }
        return .new(start)
    }
}
