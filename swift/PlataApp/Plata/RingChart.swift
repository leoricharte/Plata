import SwiftUI
import PlataCore

/// El anillo de la web (`ringSVG`): pista gris y un arco redondeado por parte, con huecos entre ellos; el centro lo pone quien lo usa.
struct RingChart<Center: View>: View {
    struct Item { let value: Double; let color: Color }
    let items: [Item]
    var radius: CGFloat = 100
    var lineWidth: CGFloat = 22
    var gap: CGFloat = 4
    var box: CGFloat = 240
    /// Texto curvado dentro del anillo (`<textPath>` de la web): arriba sigue un arco que se lee de izquierda a derecha, abajo igual por debajo.
    struct Arc { let text: String; let radius: CGFloat }
    var arcTop: Arc? = nil
    var arcBottom: Arc? = nil
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let k = size.width / box
                let r = radius * k, sw = lineWidth * k, g = gap * k
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let circ = 2 * Double.pi * Double(r)
                var track = Path()
                track.addArc(center: c, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                ctx.stroke(track, with: .color(Color(light: "#F3F3F5", dark: "#2C2C2E")), lineWidth: sw)
                let total = max(items.reduce(0) { $0 + $1.value }, 0.000001)
                var cum = 0.0
                for it in items where it.value > 0 {
                    let share = it.value / total
                    let dash = max(1, circ * share - Double(g) - Double(sw))
                    let start = (cum * circ + Double(g + sw) / 2) / Double(r)   // radianes desde las 12 en punto
                    let end = start + dash / Double(r)
                    var p = Path()
                    p.addArc(center: c, radius: r, startAngle: .radians(start - .pi / 2), endAngle: .radians(end - .pi / 2), clockwise: false)
                    ctx.stroke(p, with: .color(it.color), style: StrokeStyle(lineWidth: sw, lineCap: .round))
                    cum += share
                }
                if let a = arcTop { Self.drawArc(&ctx, a, c, k, top: true) }
                if let a = arcBottom { Self.drawArc(&ctx, a, c, k, top: false) }
            }
            center()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Dibuja `a.text` letra a letra sobre un arco centrado en el anillo (11 pt, tracking 1.6, como la web).
    private static func drawArc(_ ctx: inout GraphicsContext, _ a: Arc, _ c: CGPoint, _ k: CGFloat, top: Bool) {
        let r = a.radius * k, tracking = 1.6 * k
        let glyphs: [(GraphicsContext.ResolvedText, CGFloat)] = a.text.map { ch in
            let t = ctx.resolve(Text(verbatim: String(ch)).font(.inter(11 * k, .medium)).foregroundColor(.secondary))
            let w = t.measure(in: CGSize(width: 200, height: 200)).width
            return (t, ch == " " ? max(w, 3.2 * k) : w)   // un espacio puede medir 0: que nunca se pegue la palabra
        }
        let total = glyphs.reduce(0) { $0 + $1.1 + tracking } - tracking
        var s = -total / 2
        for (t, w) in glyphs {
            let mid = (s + w / 2) / r                       // ángulo del centro de la letra, 0 = arriba (o abajo)
            var g = ctx
            // La base de la letra va sobre el arco (como `<textPath>`): el recuadro llega a `desc` por debajo de la base.
            let desc = 11 * k * 0.22
            let rr = top ? r - desc : r + desc
            if top {
                g.translateBy(x: c.x + rr * sin(mid), y: c.y - rr * cos(mid)); g.rotate(by: .radians(mid))
            } else {
                g.translateBy(x: c.x + rr * sin(mid), y: c.y + rr * cos(mid)); g.rotate(by: .radians(-mid))
            }
            g.draw(t, at: .zero, anchor: .bottom)
            s += w + tracking
        }
    }
}
