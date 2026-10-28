import SwiftUI
import WebKit

@main
struct PlataApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// La app web a pantalla completa (debajo) y la barra de vidrio nativa (encima).
struct RootView: View {
    @StateObject private var model = WebModel()

    var body: some View {
        // El GeometryReader respeta el área segura: así sabemos cuánto mide la barra de estado.
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                WebViewHost(webView: model.webView).ignoresSafeArea()
                NativeBar(state: model.state, perform: model.perform).ignoresSafeArea()
                topEdge(height: geo.safeAreaInsets.top)
                #if DEBUG
                hud
                #endif
            }
        }
        .preferredColorScheme(model.state.colorScheme)
    }

    /// Borde suave de vidrio bajo la hora y la batería: el contenido que sube ya no se pisa con la barra de estado.
    private func topEdge(height: CGFloat) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.6),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(height: height + 14)
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    #if DEBUG
    /// Solo en compilaciones de prueba: muestra lo que la web le está contando a Swift.
    private var hud: some View {
        let s = model.state
        return Text("tab:\(s.tab) on:\(s.on) bar:\(s.bar.o) gear:\(s.gear.o) plus:\(s.plus.o)")
            .font(.system(size: 9, design: .monospaced))
            .padding(3)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 2)
            .allowsHitTesting(false)
    }
    #endif
}

struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
