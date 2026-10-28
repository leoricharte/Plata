import SwiftUI

/// Un rectángulo con un círculo hueco en el centro: al crecer el círculo, la pantalla verde se abre y deja ver la app.
private struct CircleHole: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        return p
    }
}

/// Pantalla de inicio: el mismo verde y logo blanco de la pantalla de arranque del sistema, y luego se abre en círculo.
struct SplashView: View {
    var opening: Bool

    var body: some View {
        GeometryReader { geo in
            let far = hypot(geo.size.width, geo.size.height) / 2 + 20
            ZStack {
                Brand.accent
                Image("SplashLogo")
                    .accessibilityLabel("Plata")
                    .scaleEffect(opening ? 0.8 : 1)
                    .opacity(opening ? 0 : 1)
                VStack(spacing: 10) {
                    Spacer()
                    Text("Beta 4").font(.inter(13, .medium)).tracking(0.5)
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14))
                        Text("Aún en fase de pruebas. Podrían haber errores.").font(.inter(12))
                    }
                    .padding(.horizontal, 32)
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 18 + geo.safeAreaInsets.bottom)
                .opacity(opening ? 0 : 1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask(CircleHole(radius: opening ? far : 0).fill(style: FillStyle(eoFill: true)))
        }
        .ignoresSafeArea()
        .allowsHitTesting(!opening)
    }
}
