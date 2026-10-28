import XCTest
@testable import PlataCore

/// Lectura de PDF: el texto con su posición que arma PDFKit debe parecerse al que ve `pdf.js` en la web (los vectores salen de swift/tools/gen-nazca-pdf.mjs).
final class NazcaPDFTests: XCTestCase {
    static func golden() throws -> JSONValue { try fixture("nazca_pdf") }

    static func pdfData(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/pdf/\(name)"))
    }

    /// El documento tal como lo vio `pdf.js` (de los vectores).
    static func jsDoc(_ d: JSONValue) -> PdfDoc {
        PdfDoc(pages: d["pages"]!.arrayValue!.map { p in
            PdfPage(w: p["w"]!.doubleValue!, h: p["h"]!.doubleValue!, items: p["items"]!.arrayValue!.map { i in
                let a = i.arrayValue!
                return PdfItem(str: a[0].stringValue!, x: a[1].doubleValue!, y: a[2].doubleValue!, w: a[3].doubleValue!)
            })
        }, total: d["total"]!.intValue!, truncated: d["truncated"]!.boolValue!)
    }

    func testLinesGroupLikeTheWeb() {
        let page = PdfPage(w: 100, h: 100, items: [
            PdfItem(str: "b", x: 50, y: 70, w: 5), PdfItem(str: "a", x: 10, y: 71.5, w: 5), PdfItem(str: "c", x: 10, y: 60, w: 5), PdfItem(str: "d", x: 5, y: 40, w: 5)])
        let ls = NazcaPDF.lines(page)
        XCTAssertEqual(ls.count, 3)
        XCTAssertEqual(ls[0].items.map(\.str), ["a", "b"])
        XCTAssertEqual(ls[1].items.map(\.str), ["c"])
        XCTAssertEqual(ls[2].items.map(\.str), ["d"])
    }

    func testBadInputs() {
        XCTAssertThrowsError(try NazcaPDF.read(Data("hola".utf8))) { XCTAssertEqual($0 as? NazcaPDF.Failure, .notPDF) }
    }

    #if canImport(PDFKit)
    func testExtractionMatchesPdfJs() throws {
        let g = try Self.golden()
        var report: [String] = []
        var checked = 0
        for d in g["docs"]!.arrayValue! {
            let name = d["name"]!.stringValue!
            if d["error"] != nil, !(d["error"]!.isNull) {
                // los que pdf.js no abre: aquí tampoco
                let want = d["error"]!.stringValue!
                do { _ = try NazcaPDF.read(Self.pdfData(name), password: d["key"]?.stringValue); report.append("\(name): debía fallar con \(want)") }
                catch let e as NazcaPDF.Failure { if e.rawValue != want { report.append("\(name): falló con \(e.rawValue), debía \(want)") } }
                continue
            }
            let want = Self.jsDoc(d)
            let got: PdfDoc
            do { got = try NazcaPDF.read(Self.pdfData(name), password: d["key"]?.stringValue) } catch { report.append("\(name): no abrió (\(error))"); continue }
            checked += 1
            if got.pages.count != want.pages.count { report.append("\(name): \(got.pages.count) páginas, debían ser \(want.pages.count)"); continue }
            var miss = 0, total = 0, dy: [Double] = [], examples: [String] = []
            for (pi, wp) in want.pages.enumerated() {
                let gp = got.pages[pi]
                if abs(gp.w - wp.w) > 1 || abs(gp.h - wp.h) > 1 { report.append("\(name) p\(pi): tamaño \(gp.w)x\(gp.h) vs \(wp.w)x\(wp.h)") }
                for w in wp.items {
                    total += 1
                    if let m = gp.items.first(where: { $0.str == w.str && abs($0.x - w.x) <= 2 && abs($0.y - w.y) <= 3 && abs($0.w - w.w) <= 3 }) { dy.append(m.y - w.y); continue }
                    miss += 1
                    if examples.count < 3 {
                        let near = gp.items.filter { abs($0.y - w.y) < 8 && abs($0.x - w.x) < 40 }.prefix(2).map { "[\($0.str)|\(Int($0.x))|\(String(format: "%.1f", $0.y))|\(Int($0.w))]" }.joined()
                        examples.append("«\(w.str)»(\(Int(w.x)),\(String(format: "%.1f", w.y))) ~ \(near)")
                    }
                }
                if gp.items.count != wp.items.count { examples.append("p\(pi): \(gp.items.count) textos vs \(wp.items.count)") }
            }
            if miss > 0 { report.append("\(name): \(miss)/\(total) sin pareja. " + examples.joined(separator: " · ") + (dy.isEmpty ? "" : " · dy~\(String(format: "%.2f", dy.reduce(0, +) / Double(dy.count)))")) }
        }
        XCTAssertGreaterThan(checked, 40)
        XCTAssertTrue(report.isEmpty, "\n" + report.prefix(12).joined(separator: "\n") + (report.count > 12 ? "\n… y \(report.count - 12) más" : ""))
    }
    #endif
}
