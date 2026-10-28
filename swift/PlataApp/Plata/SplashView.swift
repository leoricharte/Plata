import SwiftUI

/// Pantalla de inicio: verde Plata con el logo en blanco; se desvanece sola.
struct SplashView: View {
    var body: some View {
        ZStack {
            Brand.accent.ignoresSafeArea()
            Image("PlataLogoWhite")
                .resizable().scaledToFit()
                .frame(width: 210)
                .accessibilityLabel("Plata")
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
            .padding(.bottom, 18)
        }
    }
}
