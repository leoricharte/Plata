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
            }
            center()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
