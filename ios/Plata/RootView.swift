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
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            WebViewHost(webView: model.webView).ignoresSafeArea()
            NativeBar(state: model.state, perform: model.perform).ignoresSafeArea()
        }
        .preferredColorScheme(model.state.colorScheme)
    }
}

struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
