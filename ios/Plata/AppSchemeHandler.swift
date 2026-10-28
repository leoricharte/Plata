import Foundation
import WebKit

/// Sirve la app web empaquetada (carpeta `Web/` dentro del bundle) en `plata://localhost/`.
/// Así la app tiene un origen estable (la CSP con 'self' y el localStorage funcionan igual que en la web) y nunca carga código remoto.
final class AppSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "plata"
    static let startURL = URL(string: "plata://localhost/")!

    private let root: URL

    override init() {
        root = (Bundle.main.url(forResource: "Web", withExtension: nil) ?? Bundle.main.bundleURL).standardizedFileURL
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(path).standardizedFileURL
        // No salir nunca de la carpeta Web
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain"])!
            urlSchemeTask.didReceive(notFound)
            urlSchemeTask.didReceive(Data("No encontrado".utf8))
            urlSchemeTask.didFinish()
            return
        }
        let headers = [
            "Content-Type": Self.mime(file.pathExtension),
            "Content-Length": String(data.count),
            "Cache-Control": "no-store",
        ]
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(ok)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json", "webmanifest": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "woff2": return "font/woff2"
        case "txt", "md": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
