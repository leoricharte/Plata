import Foundation
#if canImport(WebKit)
import WebKit

/// Lee un PDF con el MISMO código que la web: pdf.js y `nazca-pdf.js` (copias idénticas de `dev/`, ver `swift/tools/sync-pdfjs.sh`),
/// dentro de un WKWebView oculto (nunca se muestra ni se añade a ninguna pantalla).
/// Así los textos y posiciones son los que ven los lectores de banco de la web, y una mejora en la web llega a iPhone con solo sincronizar.
///
/// Seguridad: todo es local (esquema propio `plata-pdf://`, sin red: CSP `default-src 'none'`, regla de contenido que bloquea http/https y navegación cerrada),
/// almacenamiento no persistente y una vista nueva por PDF. El PDF y la clave solo entran por la llamada; la clave no se guarda ni se devuelve.
@MainActor
public enum NazcaPDFWeb {
    static let scheme = "plata-pdf"
    static let timeout: UInt64 = 90_000_000_000
    /// Solo para diagnóstico en pruebas: el tipo y el mensaje técnico del último fallo de pdf.js (nunca el contenido del PDF).
    public internal(set) static var lastDetail = ""

    public static func read(_ data: Data, password: String? = nil) async throws -> PdfDoc {
        if data.count > NazcaPDF.maxBytes { throw NazcaPDF.Failure.tooBig }
        if !NazcaPDF.hasHeader([UInt8](data.prefix(1100))) { throw NazcaPDF.Failure.notPDF }
        let session = Session()
        defer { session.close() }
        return try await withThrowingTaskGroup(of: PdfDoc.self) { group in
            group.addTask { @MainActor in try await session.run(data, password: password) }
            group.addTask { try await Task.sleep(nanoseconds: timeout); throw NazcaPDF.Failure.unavailable }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    // MARK: - Una vista por PDF

    @MainActor private final class Session: NSObject, WKNavigationDelegate {
        private var web: WKWebView?
        private var loaded: CheckedContinuation<Void, Error>?
        private var mainLoad = true

        func close() { web?.navigationDelegate = nil; web?.stopLoading(); web = nil }

        func run(_ data: Data, password: String?) async throws -> PdfDoc {
            let cfg = WKWebViewConfiguration()
            cfg.websiteDataStore = .nonPersistent()
            cfg.preferences.javaScriptCanOpenWindowsAutomatically = false
            cfg.setURLSchemeHandler(Handler(), forURLScheme: NazcaPDFWeb.scheme)
            if let rules = try? await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "plata-pdf-sin-red", encodedContentRuleList: #"[{"trigger":{"url-filter":"^(https?|wss?|ftp)://"},"action":{"type":"block"}}]"#) {
                cfg.userContentController.add(rules)
            }
            let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 4, height: 4), configuration: cfg)
            w.navigationDelegate = self
            web = w
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                loaded = c
                w.load(URLRequest(url: URL(string: "\(NazcaPDFWeb.scheme)://app/index.html")!))
            }
            let body = """
            for (let i = 0; i < 400 && !window.__ok && !window.__err; i++) await new Promise(r => setTimeout(r, 25));
            if (!window.__ok) return JSON.stringify({ ok: false, code: 'unavailable', detail: window.__err || 'sin cargar' });
            try {
              const bin = atob(b64), u = new Uint8Array(bin.length);
              for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
              const d = await NazcaPDF.read(u, window.__lib, pw || undefined);
              return JSON.stringify({ ok: true, d });
            } catch (e) { return JSON.stringify({ ok: false, code: (e && e.code) || 'invalid', detail: (e && e.detail) || '' }); }
            """
            let any = try await w.callAsyncJavaScript(body, arguments: ["b64": data.base64EncodedString(), "pw": password ?? ""], in: nil, contentWorld: .page)
            guard let s = any as? String, let raw = s.data(using: .utf8) else { throw NazcaPDF.Failure.unavailable }
            let r: Reply
            do { r = try JSONDecoder().decode(Reply.self, from: raw) } catch { NazcaPDFWeb.lastDetail = "respuesta: \(error)".prefix(300).description; throw NazcaPDF.Failure.invalid }
            if r.ok, let d = r.d {
                return PdfDoc(pages: d.pages.map { p in PdfPage(w: p.w, h: p.h, items: p.items.map { PdfItem(str: $0.str, x: $0.x, y: $0.y, w: $0.w) }) },
                              total: d.total, truncated: d.truncated)
            }
            NazcaPDFWeb.lastDetail = r.detail ?? ""
            throw NazcaPDF.Failure(rawValue: r.code ?? "") ?? .invalid
        }

        // La página interna se carga una vez; cualquier otra navegación se cancela.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            if mainLoad, action.request.url?.scheme == NazcaPDFWeb.scheme { mainLoad = false; return .allow }
            return .cancel
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded?.resume(); loaded = nil }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loaded?.resume(throwing: NazcaPDF.Failure.unavailable); loaded = nil }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loaded?.resume(throwing: NazcaPDF.Failure.unavailable); loaded = nil }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { loaded?.resume(throwing: NazcaPDF.Failure.unavailable); loaded = nil }
    }

    private struct Reply: Decodable {
        struct Item: Decodable { let str: String; let x: Double; let y: Double; let w: Double }
        struct Page: Decodable { let w: Double; let h: Double; let items: [Item] }
        struct Doc: Decodable { let pages: [Page]; let total: Int; let truncated: Bool }
        let ok: Bool
        let d: Doc?
        let code: String?
        let detail: String?
    }

    // MARK: - Sirve solo los 4 archivos del paquete

    @MainActor private final class Handler: NSObject, WKURLSchemeHandler {
        static let files: [String: String] = ["index.html": "text/html", "boot.js": "text/javascript", "nazca-pdf.js": "text/javascript", "pdf.mjs": "text/javascript", "pdf.worker.mjs": "text/javascript"]
        func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
            guard let url = task.request.url, url.host == "app", let mime = Self.files[url.lastPathComponent],
                  let file = Bundle.module.resourceURL?.appendingPathComponent("pdfjs/\(url.lastPathComponent)"),
                  let data = try? Data(contentsOf: file) else { task.didFailWithError(URLError(.fileDoesNotExist)); return }
            let head = ["Content-Type": mime + "; charset=utf-8", "Content-Length": String(data.count), "Cache-Control": "no-store"]
            task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: head)!)
            task.didReceive(data)
            task.didFinish()
        }
        func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
    }
}
#endif
