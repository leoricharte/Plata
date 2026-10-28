import Foundation
#if canImport(PDFKit)
import PDFKit
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#endif

extension NazcaPDF {
    /// Abre el PDF en el dispositivo y saca el texto de cada página con su posición. `password` solo sirve para abrirlo: no se guarda ni se devuelve.
    /// A diferencia de `pdf.js`, PDFKit no entrega los textos tal como están en el archivo: aquí se arman a partir de la posición de cada letra
    /// (letras seguidas del mismo renglón forman un texto; un hueco más ancho que un espacio abre otro).
    public static func read(_ data: Data, password: String? = nil) throws -> PdfDoc {
        let bytes = [UInt8](data.prefix(1100))
        if data.count > maxBytes { throw Failure.tooBig }
        if !hasHeader(bytes) { throw Failure.notPDF }
        guard let doc = PDFDocument(data: data) else { throw Failure.invalid }
        if doc.isLocked {
            guard let password, !password.isEmpty else { throw Failure.needPassword }
            if !doc.unlock(withPassword: password) { throw Failure.badPassword }
        }
        var pages: [PdfPage] = []
        var count = 0
        let last = min(doc.pageCount, maxPages)
        for n in 0..<last {
            guard let page = doc.page(at: n) else { continue }
            let box = page.bounds(for: .cropBox)
            let items = extract(page)
            count += items.count
            if count > maxItems { throw Failure.invalid }
            pages.append(PdfPage(w: Double(box.width), h: Double(box.height), items: items))
        }
        if count == 0 { throw Failure.noText }
        return PdfDoc(pages: pages, total: doc.pageCount, truncated: doc.pageCount > maxPages)
    }

    /// Un renglón de letras seguidas se parte en textos donde el hueco supera `splitEm` veces el tamaño de la letra (un espacio mide ~0.28).
    static let splitEm = 0.40
    /// Cuánto sube la línea base respecto del borde de abajo de la letra, en veces el tamaño de la letra (el descenso de la fuente).
    static let descentEm = 0.21

    private struct Run {
        var text = ""
        var x0 = 0.0, x1 = 0.0
        var base = 0.0
        var size = 0.0
        var lastMax = 0.0
    }

    static func extract(_ page: PDFKit.PDFPage) -> [PdfItem] {
        let n = page.numberOfCharacters
        guard n > 0, let str = page.string else { return [] }
        let ns = str as NSString
        let attr = page.attributedString
        var items: [PdfItem] = []
        var cur: Run?
        var pendingSpace = false

        func flush() {
            if let r = cur {
                let t = PDFx.clean(r.text)
                if !t.isEmpty { items.append(PdfItem(str: t, x: r.x0, y: r.base, w: r.x1 - r.x0)) }
            }
            cur = nil; pendingSpace = false
        }

        for i in 0..<min(n, ns.length) {
            let c = ns.character(at: i)
            let isNewline = c == 10 || c == 13 || c == 0x2028 || c == 0x2029
            if isNewline { flush(); continue }
            let isSpace = c == 32 || c == 0xA0 || c == 9 || (c >= 0x2000 && c <= 0x200A) || c == 0x202F || c == 0x3000
            if isSpace { pendingSpace = true; continue }
            let r = page.characterBounds(at: i)
            if r.isNull || r.isInfinite || r.width <= 0 || r.height <= 0 { continue }
            var size = Double(r.height) / 1.15
            if let attr, i < attr.length, let f = attr.attribute(.font, at: i, effectiveRange: nil) as? PlatformFont, f.pointSize > 0 { size = Double(f.pointSize) }
            let base = Double(r.minY) + descentEm * size
            let ch = String(utf16CodeUnits: [c], count: 1)
            if var run = cur {
                let sameLine = abs(base - run.base) < 0.45 * max(size, run.size)
                let gap = Double(r.minX) - run.lastMax
                if sameLine && gap <= splitEm * run.size && gap > -run.size {
                    if pendingSpace || gap > 0.16 * run.size { run.text += " " }
                    run.text += ch
                    run.x1 = max(run.x1, Double(r.maxX)); run.lastMax = Double(r.maxX)
                    cur = run
                    pendingSpace = false
                    continue
                }
                flush()
            }
            cur = Run(text: ch, x0: Double(r.minX), x1: Double(r.maxX), base: base, size: size, lastMax: Double(r.maxX))
        }
        flush()
        return items
    }
}
#endif
