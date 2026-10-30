import Foundation
import Vision
import ImageIO
import PDFKit
import UIKit

/// Texto de una captura (o de un PDF) de una constancia, leído EN EL DISPOSITIVO con Vision. Nada sale del teléfono.
/// El texto se entrega línea por línea, de arriba abajo; lo que está en la misma fila (etiqueta a la izquierda, valor a la derecha) se une con un espacio,
/// que es la forma que espera `NazcaConstancia`.
enum ConstanciaOCR {
    enum Failure: Error { case unreadable }

    /// Las extensiones tienen poca memoria: se reduce la imagen antes de leerla.
    static let maxPixel = 2400

    /// Una lectura más: con `strict` se usa la corrección de idioma (mejor para palabras); sin ella, las cifras y los códigos salen tal cual (mejor para montos sobre fondos con confeti o degradados).
    static func text(fromImageData data: Data, strict: Bool) async throws -> String {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                    kCGImageSourceCreateThumbnailWithTransform: true,
                                                                    kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary)
        else { throw Failure.unreadable }
        return try await text(from: cg, strict: strict)
    }

    static func text(fromImageData data: Data) async throws -> String { try await text(fromImageData: data, strict: true) }

    static func text(fromPDFData data: Data) async throws -> String {
        guard let doc = PDFDocument(data: data), let page = doc.page(at: 0) else { throw Failure.unreadable }
        // un PDF con texto se lee directo; uno escaneado (o una captura convertida a PDF) se lee como imagen
        if let s = page.string, s.filter({ !$0.isWhitespace }).count >= 20 { return s }
        let box = page.bounds(for: .mediaBox), scale = min(2.5, CGFloat(maxPixel) / max(box.width, box.height))
        let img = page.thumbnail(of: CGSize(width: box.width * scale, height: box.height * scale), for: .mediaBox)
        guard let cg = img.cgImage else { throw Failure.unreadable }
        return try await text(from: cg)
    }

    static func text(from cg: CGImage, strict: Bool = true) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = strict
                if strict, let supported = try? req.supportedRecognitionLanguages() {
                    let want = ["es-ES", "en-US"].filter { supported.contains($0) }
                    if !want.isEmpty { req.recognitionLanguages = want }
                }
                do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req]) }
                catch { cont.resume(throwing: error); return }
                cont.resume(returning: rows(req.results ?? []))
            }
        }
    }

    private struct Piece { var text: String; var minX: CGFloat; var midY: CGFloat; var h: CGFloat }

    static func rows(_ obs: [VNRecognizedTextObservation]) -> String {
        // Vision mide desde abajo a la izquierda: mayor y = más arriba
        let pieces = obs.compactMap { o -> Piece? in
            guard let t = o.topCandidates(1).first?.string, !t.isEmpty else { return nil }
            return Piece(text: t, minX: o.boundingBox.minX, midY: o.boundingBox.midY, h: o.boundingBox.height)
        }.sorted { $0.midY > $1.midY }
        var lines: [[Piece]] = []
        for p in pieces {
            if let ref = lines.last?.first, abs(ref.midY - p.midY) < max(ref.h, p.h) * 0.6 { lines[lines.count - 1].append(p) }
            else { lines.append([p]) }
        }
        return lines.map { $0.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ") }.joined(separator: "\n")
    }
}
