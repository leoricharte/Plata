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
                if NativeFlags.systemTabBar {
                    SystemTabs(model: model)
                } else {
                    WebViewHost(webView: model.webView).ignoresSafeArea()
                }
                NativeBar(state: model.state, perform: model.perform, setValue: model.setValue).ignoresSafeArea()
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

/// La barra de pestañas real de iOS (en iOS 26: Liquid Glass flotante con la lupa al mantener y arrastrar).
/// El contenido de cada pestaña es la misma web: la pestaña activa le "presta" su vista al WKWebView.
/// Tocar una pestaña manda la acción a la web; la pestaña marcada sigue la de la web. El «+» es la pestaña de rol búsqueda
/// (en iOS 26 sale como botón de vidrio aparte): al tocarlo se dispara el «+» de la web y la selección vuelve a la pestaña anterior.
struct SystemTabs: View {
    @ObservedObject var model: WebModel
    @State private var selection = "resumen"
    @State private var lastReal = "resumen"

    private func title(_ key: TabKey) -> String {
        model.state.labels[key.rawValue] ?? key.rawValue.capitalized
    }

    /// iOS 27 separa el botón redondo solo con el rol .prominent; iOS 18–26 lo hacen con .search.
    private var plusRole: TabRole {
        if #available(iOS 27.0, *) { return .prominent }
        return .search
    }

    private func slot(_ id: String) -> some View {
        WebSlot(webView: model.webView, active: selection == id)
            .ignoresSafeArea()
            .toolbarVisibility(model.state.bar.o > 0.5 ? .visible : .hidden, for: .tabBar)
    }

    var body: some View {
        TabView(selection: Binding(get: { selection }, set: { new in
            if new == "plus" {
                // La pestaña "+" se selecciona un instante: el WKWebView se muda a ella (no queda pantalla en blanco)
                // y se devuelve a la pestaña anterior cuando el menú ya abrió.
                selection = "plus"
                model.perform(.plus)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if selection == "plus" { selection = lastReal }
                }
            } else {
                selection = new
                lastReal = new
                if let k = TabKey(rawValue: new) { model.perform(.tab(k)) }
            }
        })) {
            Tab(title(.resumen), systemImage: TabKey.resumen.sfLine, value: "resumen") { slot("resumen") }
            Tab(title(.presupuesto), systemImage: TabKey.presupuesto.sfLine, value: "presupuesto") { slot("presupuesto") }
            Tab(title(.proyeccion), systemImage: TabKey.proyeccion.sfLine, value: "proyeccion") { slot("proyeccion") }
            Tab(title(.deuda), systemImage: TabKey.deuda.sfLine, value: "deuda") { slot("deuda") }
            Tab("", systemImage: "plus", value: "plus", role: plusRole) { slot("plus") }
        }
        .onChange(of: model.state.on) { _, new in
            if TabKey(rawValue: new) != nil, new != selection {
                selection = new
                lastReal = new
            }
        }
    }
}

/// Vista vacía que aloja al WKWebView mientras su pestaña está activa.
struct WebSlot: UIViewRepresentable {
    let webView: WKWebView
    let active: Bool

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        if active {
            guard webView.superview !== v else { return }
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: v.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: v.trailingAnchor),
                webView.topAnchor.constraint(equalTo: v.topAnchor),
                webView.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            ])
        } else if webView.superview === v {
            webView.removeFromSuperview()
        }
    }
}
