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
        let width = Double(cg.width), height = Double(cg.height)
        let area = CGRect(x: rect.minX * width, y: (1 - rect.maxY) * height, width: rect.width * width, height: rect.height * height).integral
        guard area.width >= 2, area.height >= 2, let crop = cg.cropping(to: area) else { return 0 }
        let w = 32, h = 8
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rs = [Double](), gs = [Double](), bs = [Double]()
        for i in 0..<(w * h) {
            rs.append(Double(data[i * 4])); gs.append(Double(data[i * 4 + 1])); bs.append(Double(data[i * 4 + 2]))
        }
        // el fondo: el promedio de las cuatro esquinas
        let corners = [0, w - 1, (h - 1) * w, h * w - 1]
        var bgR = 0.0, bgG = 0.0, bgB = 0.0
        for c in corners { bgR += rs[c]; bgG += gs[c]; bgB += bs[c] }
        bgR /= 4; bgG /= 4; bgB /= 4
        var dist = [(d: Double, i: Int)]()
        for i in 0..<(w * h) {
            let d = abs(rs[i] - bgR) + abs(gs[i] - bgG) + abs(bs[i] - bgB)
            dist.append((d, i))
        }
        dist.sort { $0.d > $1.d }
        guard let first = dist.first, first.d > 90 else { return 0 }
        let top = dist.prefix(max(4, dist.count / 12))
        var r = 0.0, g = 0.0, b = 0.0
        for t in top { r += rs[t.i]; g += gs[t.i]; b += bs[t.i] }
        let n = Double(top.count)
        r /= n; g /= n; b /= n
        if r > g + 45 && r > b + 35 { return -1 }
        if g > r + 25 && g > b + 15 { return 1 }
        return 0
    }
}
