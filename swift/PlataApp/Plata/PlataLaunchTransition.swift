import SwiftUI

// MARK: - Launch: fondo verde + logo blanco que se arma, hace bounce elástico y se "eyecta" revelando la app
//
// Uso (en tu @main):
//
//   WindowGroup {
//       PlataLaunchTransition {
//           RootView()          // tu app actual, tal cual
//       }
//   }
//
// Requiere PlataLaunchAnimation.swift en el mismo target (geometría, tablas y PlataFrame).
// LaunchScreen.storyboard: solo color de fondo #22B573 (sin imagen), así el primer frame es idéntico.

struct PlataLaunchTransition<Content: View>: View {
    /// Ancho del logo en pantalla (pt) y desplazamiento vertical respecto al centro.
    var logoWidth: CGFloat = 260
    var yOffset: CGFloat = -40
    var onFinished: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?
    @State private var finished = false

    // Tiempos (s)
    private let hold = 0.30      // pausa con el logo completo
    private let ant = 0.42       // tensión hacia atrás (bounce elástico)
    private let zd = 0.62        // zoom / eyección
    private let dip = 0.82       // cuánto se encoge antes de soltarse
    private let maxScale = 300.0 // zoom final
    // Punto del logo (coordenadas del SVG) desde el que se hace zoom: la parte sólida de la punta,
    // para que crezca hasta llenar la pantalla y no queden pedazos.
    private let origin = CGPoint(x: 481.2, y: 79.9)

    private var tTotal: Double { PlataTimeline.total }
    private var tZoomStart: Double { tTotal + hold }
    private var tEnd: Double { tTotal + hold + ant + zd }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: finished)) { ctx in
                let t = startDate.map { ctx.date.timeIntervalSince($0) } ?? 0
                let st = zoomState(t)
                let xf = transform(size: geo.size, sx: st.sx, sy: st.sy)

                ZStack {
                    if !finished { PlataGeometry.green }

                    content()
                        .opacity(finished || t >= tZoomStart + ant ? 1 : 0)
                        .allowsHitTesting(finished || reduceMotion)
                        .mask {
                            if finished || reduceMotion {
                                Rectangle()
                            } else {
                                Canvas { gc, _ in
                                    gc.fill(PlataGeometry.logo.applying(xf), with: .color(.white))
                                }
                            }
                        }

                    if !finished {
                        // Aviso de beta: sube sobre el borde inferior y se apaga antes del zoom
                        VStack(spacing: 8) {
                            Spacer()
                            Text("Beta 4").font(.system(size: 13, weight: .medium)).tracking(0.5)
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill").font(.system(size: 14))
                                Text("Aún en fase de pruebas. Podrían haber errores.").font(.system(size: 12))
                            }
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28).padding(.bottom, 96)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(reduceMotion ? 1 : 1 - PlataTimeline.smooth(PlataTimeline.clamp((t - (tTotal - 0.25)) / 0.3)))
                        .allowsHitTesting(false)
                    }

                    if !finished && !reduceMotion {
                        if t < tTotal {
                            // Construcción del logo (flecha, punta, letras con pop)
                            LogoCanvas { PlataFrame(t: t, ink: .white) }
                                .frame(width: logoWidth)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2 + yOffset)
                        } else {
                            // Logo blanco: tensión elástica y eyección (mismo transform que la máscara)
                            Canvas { gc, _ in
                                gc.fill(PlataGeometry.logo.applying(xf), with: .color(.white.opacity(st.logoOpacity)))
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            let delay = reduceMotion ? 0.4 : tEnd
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                finished = true
                onFinished()
            }
        }
    }

    // MARK: Geometría

    /// logo (coords SVG) -> pantalla, con el zoom aplicado desde `origin`.
    private func transform(size: CGSize, sx: CGFloat, sy: CGFloat) -> CGAffineTransform {
        let k = logoWidth / PlataGeometry.size.width
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + yOffset)
        let base = CGAffineTransform(translationX: c.x - PlataGeometry.size.width * k / 2,
                                     y: c.y - PlataGeometry.size.height * k / 2)
            .scaledBy(x: k, y: k)
        let o = origin.applying(base)
        let zoom = CGAffineTransform(translationX: o.x, y: o.y)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -o.x, y: -o.y)
        return base.concatenating(zoom)
    }

    // MARK: Movimiento

    private func zoomState(_ t: Double) -> (sx: CGFloat, sy: CGFloat, logoOpacity: Double) {
        let T = PlataTimeline.self
        let a = T.clamp((t - tZoomStart) / ant)
        let z = T.clamp((t - tZoomStart - ant) / zd)

        // Se estira hacia atrás como una liga (ease-out) y se aplasta un poco en vertical
        let back = 1 - pow(1 - a, 3)
        let d = 1 - (1 - dip) * back
        let squash = sin(.pi * min(1, a)) * 0.05

        // Se suelta: acelera sin parar (exponencial con potencia alta) y se estira en horizontal con la velocidad
        let lz = min(1, z / 0.45)
        let stretch = sin(.pi * lz) * 0.05 + 0.2 * pow(z, 2.2)
        let s = d * exp(log(maxScale / dip) * pow(z, 3.3))

        let sx = s * (1 + stretch - squash * 0.4)
        let sy = s * (1 - stretch * 0.45 + squash)

        let f = T.clamp((z - 0.6) / 0.25)
        return (CGFloat(sx), CGFloat(sy), 1 - T.smooth(f))
    }
}

#Preview {
    PlataLaunchTransition {
        ZStack {
            Color(red: 14 / 255, green: 15 / 255, blue: 17 / 255)
            Text("Tu app").foregroundStyle(.white).font(.largeTitle.bold())
        }
    }
}
