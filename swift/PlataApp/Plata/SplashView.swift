import SwiftUI

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
                    // el logo no se apaga: se queda hasta que el círculo que se abre lo "come", como en la pantalla de arranque
                    .scaleEffect(opening ? 1.06 : 1)
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
                .animation(.easeOut(duration: 0.25), value: opening)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask {
                // un rectángulo con un círculo hueco en el centro que crece y deja ver la app
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: opening ? far * 2 : 0, height: opening ? far * 2 : 0)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .animation(.easeInOut(duration: 0.75), value: opening)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!opening)
    }
}
