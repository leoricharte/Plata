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
    /// Zoom con dos dedos (se ancla donde están los dedos) y doble toque para volver.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var pinchBase: (zoom: CGFloat, pan: CGSize)?
    @State private var pinching = false
    @State private var saved: NazcaExample.Region?

    private let corner: CGFloat = 22
    private let maxZoom: CGFloat = 6

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
            .scaleEffect(zoom, anchor: .center)
            .offset(pan)
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(magnify(fit: fit, box: geo.size))
            .simultaneousGesture(TapGesture(count: 2).onEnded { withAnimation(.snappy) { zoom = 1; pan = .zero } })
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Tr.t("Captura. Arrastra para encerrar los movimientos."))
        }
    }

    private func fitted(in box: CGSize) -> CGSize {
        let iw = max(image.size.width, 1), ih = max(image.size.height, 1)
        let s = min(box.width / iw, box.height / ih)
        return CGSize(width: iw * s, height: ih * s)
    }

    private func magnify(fit: CGSize, box: CGSize) -> some Gesture {
        MagnifyGesture().onChanged { v in
            if !pinching {
                pinching = true
                mode = nil
                region = saved          // el primer dedo ya empezó un cuadro: se deshace
                pinchBase = (zoom, pan)
            }
            guard let base = pinchBase else { return }
            let s1 = min(maxZoom, max(1, base.zoom * v.magnification))
            let c = CGPoint(x: box.width / 2, y: box.height / 2)
            let f = v.startLocation
            let r = s1 / base.zoom
            var o = CGSize(width: f.x - c.x - r * (f.x - c.x - base.pan.width), height: f.y - c.y - r * (f.y - c.y - base.pan.height))
            let mx = max(0, (s1 * fit.width - box.width) / 2), my = max(0, (s1 * fit.height - box.height) / 2)
            o.width = min(mx, max(-mx, o.width)); o.height = min(my, max(-my, o.height))
            zoom = s1; pan = s1 <= 1.001 ? .zero : o
        }
        .onEnded { _ in
            pinchBase = nil
            if zoom < 1.02 { withAnimation(.snappy) { zoom = 1; pan = .zero } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pinching = false }
        }
    }

    // MARK: lo que se dibuja encima

    private func rect(_ r: NazcaExample.Region, _ size: CGSize) -> CGRect {
        CGRect(x: r.x * size.width, y: r.y * size.height, width: r.w * size.width, height: r.h * size.height)
    }

    @ViewBuilder private func overlay(size: CGSize) -> some View {
        if let r = region {
            let sel = rect(r, size)
            let bands = NazcaExample.rows(in: r, boxes: boxes)
            let rad = min(14, sel.height / 2, sel.width / 2) / zoom, line = 1 / zoom
            let shape = Path(roundedRect: sel, cornerRadius: rad, style: .continuous)
            Canvas { ctx, sz in
                var dim = Path(CGRect(origin: .zero, size: sz))
                dim.addPath(shape)
                ctx.fill(dim, with: .color(.black.opacity(0.46)), style: FillStyle(eoFill: true))
                ctx.fill(shape, with: .color(.white.opacity(0.10)))
                ctx.stroke(shape, with: .color(.white.opacity(0.50)), lineWidth: line)
                for b in bands {
                    let band = CGRect(x: sel.minX + 4 / zoom, y: b.y * sz.height - 2 / zoom, width: max(0, sel.width - 8 / zoom), height: b.h * sz.height + 4 / zoom)
                    ctx.fill(Path(roundedRect: band, cornerRadius: 5 / zoom, style: .continuous), with: .color(.white.opacity(0.14)))
                }
            }
            .allowsHitTesting(false)
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
            if pinching { return }
            if mode == nil {
                saved = region
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
        for (i, c) in corners(sel).enumerated() where hypot(c.x - loc.x, c.y - loc.y) < 30 / zoom { return .resize(opposite[i]) }
        if sel.contains(loc) { return .move(r) }
        return .new(start)
    }
}
