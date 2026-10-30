import Foundation
import Vision
import ImageIO
import CoreGraphics
import PlataCore

/// El texto de una captura CON su posición y el color de cada trozo, leído en el dispositivo con Vision.
/// Es lo que necesita «Sesión de reconocimiento» para aprender cómo está armada la captura. Nada sale del teléfono.
enum CaptureBoxes {
    enum Failure: Error { case unreadable }

    static let maxPixel = 2400

    static func read(imageData data: Data) async throws -> [NazcaExample.Box] {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                    kCGImageSourceCreateThumbnailWithTransform: true,
                                                                    kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary)
        else { throw Failure.unreadable }
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                // sin corrección de idioma: los montos y los códigos salen tal cual
                req.usesLanguageCorrection = false
                do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req]) }
                catch { cont.resume(throwing: error); return }
                let boxes = (req.results ?? []).compactMap { o -> NazcaExample.Box? in
                    guard let t = o.topCandidates(1).first?.string, !t.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                    let b = o.boundingBox   // Vision mide desde abajo a la izquierda
                    return NazcaExample.Box(text: t, x: b.minX, y: 1 - b.maxY, w: b.width, h: b.height, tone: tone(of: cg, rect: b))
                }
                cont.resume(returning: boxes)
            }
        }
    }

    /// −1 si el texto es rojizo, 1 si es verdoso, 0 si no se distingue. Se toma el color de los píxeles que más se alejan del fondo.
    static func tone(of cg: CGImage, rect: CGRect) -> Int {
        let W = cg.width, H = cg.height
        let px = CGRect(x: rect.minX * Double(W), y: (1 - rect.maxY) * Double(H), width: rect.width * Double(W), height: rect.height * Double(H)).integral
        guard px.width >= 2, px.height >= 2, let crop = cg.cropping(to: px) else { return 0 }
        let w = 32, h = 8
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        func px(_ i: Int) -> (Double, Double, Double) { (Double(data[i * 4]), Double(data[i * 4 + 1]), Double(data[i * 4 + 2])) }
        // el fondo: el promedio de las esquinas
        let corners = [0, w - 1, (h - 1) * w, h * w - 1].map(px)
        let bg = (corners.map { $0.0 }.reduce(0, +) / 4, corners.map { $0.1 }.reduce(0, +) / 4, corners.map { $0.2 }.reduce(0, +) / 4)
        var far: [(Double, Double, Double, Double)] = []
        for i in 0..<(w * h) {
            let p = px(i)
            let d = abs(p.0 - bg.0) + abs(p.1 - bg.1) + abs(p.2 - bg.2)
            far.append((d, p.0, p.1, p.2))
        }
        far.sort { $0.0 > $1.0 }
        let top = far.prefix(max(4, far.count / 12))
        guard top.first?.0 ?? 0 > 90 else { return 0 }
        let n = Double(top.count)
        let r = top.map { $0.1 }.reduce(0, +) / n, g = top.map { $0.2 }.reduce(0, +) / n, b = top.map { $0.3 }.reduce(0, +) / n
        if r > g + 45 && r > b + 35 { return -1 }
        if g > r + 25 && g > b + 15 { return 1 }
        return 0
    }
}
