import SwiftUI
import UIKit
import WebKit

/// Dueño del WKWebView: carga la app empaquetada, recibe el estado del puente y atiende descargas, enlaces y diálogos.
final class WebModel: NSObject, ObservableObject {
    @Published private(set) var state = WebState()
    let webView: WKWebView

    private let store = NativeStore()
    private var downloadTargets: [ObjectIdentifier: URL] = [:]

    override init() {
        let cfg = WKWebViewConfiguration()
        // Sin "Safari/" en el user agent, la app creería que está en un navegador integrado y mostraría su aviso "Ábrela en tu navegador".
        cfg.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        cfg.setURLSchemeHandler(AppSchemeHandler(), forURLScheme: AppSchemeHandler.scheme)
        cfg.allowsInlineMediaPlayback = true
        cfg.dataDetectorTypes = []

        let ucc = cfg.userContentController
        let restore = WebModel.restoreScript(NativeStore().load())
        if !restore.isEmpty {
            ucc.addUserScript(WKUserScript(source: restore, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        if let url = Bundle.main.url(forResource: "Bridge", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        webView = PlataWebView(frame: .zero, configuration: cfg)
        super.init()

        webView.configuration.userContentController.add(WeakHandler(self), name: "plata")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false   // sin zoom con pellizco: es una app, no una página
        #if DEBUG
        webView.isInspectable = true   // Safari → Develop → tu iPhone
        #endif
        webView.load(URLRequest(url: AppSchemeHandler.startURL))
    }

    /// Restaura el respaldo nativo solo si la web arrancó sin su perfil (iOS vació el almacenamiento).
    private static func restoreScript(_ items: [String: String]) -> String {
        guard !items.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: items),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return "(function(){try{var B=\(json);if(!localStorage.getItem('finanzas.v3')){for(var k in B){localStorage.setItem(k,B[k])}}}catch(e){}})();"
    }

    func perform(_ action: WebAction) {
        let js = "window.__plataGo&&window.__plataGo('\(action.selector)')"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Valor de un slider nativo → input original de la web.
    func setValue(_ id: Int, _ value: Double) {
        guard value.isFinite else { return }
        webView.evaluateJavaScript("window.__plataSet&&window.__plataSet(\(id),\(value))", completionHandler: nil)
    }

    fileprivate func handle(_ body: [String: Any]) {
        guard let t = body["t"] as? String else { return }
        switch t {
        case "state":
            let s = WebState(body)
            if s != state { state = s }
        case "save":
            if let items = body["items"] as? [String: String] { store.save(items) }
        default:
            break
        }
    }

    // MARK: utilidades de presentación

    static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let next = vc?.presentedViewController { vc = next }
        return vc
    }

    private static func systemString(_ key: String) -> String {
        Bundle(identifier: "com.apple.UIKit")?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
}

/// Evita el ciclo de retención WKUserContentController → manejador → WebModel.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebModel?
    init(_ target: WebModel) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Solo mensajes del marco principal y del origen de la app (plata://localhost)
        guard message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.`protocol` == AppSchemeHandler.scheme,
              let body = message.body as? [String: Any] else { return }
        target?.handle(body)
    }
}

// MARK: - Navegación y descargas

extension WebModel: WKNavigationDelegate, WKDownloadDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = (url.scheme ?? "").lowercased()

        switch scheme {
        case AppSchemeHandler.scheme, "about", "blob", "data":
            decisionHandler(.allow)
        case "http", "https":
            // La app solo incrusta plataapp.net (puente de mudanza) en un marco; todo lo demás se abre en Safari.
            if navigationAction.targetFrame?.isMainFrame == false, url.host == "plataapp.net" {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        case "mailto", "tel":
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        default:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.load(URLRequest(url: AppSchemeHandler.startURL))
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = (suggestedFilename as NSString).lastPathComponent
        if name.isEmpty || name == "/" { name = "plata-archivo" }
        let dest = dir.appendingPathComponent(name)
        downloadTargets[ObjectIdentifier(download)] = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadTargets.removeValue(forKey: ObjectIdentifier(download)),
              let top = WebModel.topController() else { return }
        // Hoja de compartir: "Guardar en Archivos", AirDrop, etc. (así sale el archivo de perfil)
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        top.present(sheet, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadTargets.removeValue(forKey: ObjectIdentifier(download))
    }
}

// MARK: - Diálogos de JavaScript y ventanas nuevas

extension WebModel: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let top = WebModel.topController() else { completionHandler(); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: WebModel.systemString("OK"), style: .default) { _ in completionHandler() })
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let top = WebModel.topController() else { completionHandler(false); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: WebModel.systemString("Cancel"), style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: WebModel.systemString("OK"), style: .default) { _ in completionHandler(true) })
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target="_blank" / window.open: se abre fuera de la app
        if let url = navigationAction.request.url, ["http", "https", "mailto", "tel"].contains((url.scheme ?? "").lowercased()) {
            UIApplication.shared.open(url)
        }
        return nil
    }
}


/// WKWebView cuya área segura es la del dispositivo (hora, isla, indicador de inicio).
/// Con la barra de pestañas del sistema, UIKit le sumaría la altura de la barra; la web ya reserva ese espacio por su cuenta
/// y, si el valor cambiara, todo el diseño (env(safe-area-inset-*)) se movería.
final class PlataWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        guard NativeFlags.systemTabBar, let w = window else { return super.safeAreaInsets }
        return w.safeAreaInsets
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        safeAreaInsetsDidChange()
    }
}
