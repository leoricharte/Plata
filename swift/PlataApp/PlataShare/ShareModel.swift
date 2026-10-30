import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers
import PlataCore

/// Lo que pasa dentro de la extensión: juntar el texto de lo compartido, leerlo con Nazca y dejarlo en la bandeja.
@MainActor
@Observable
final class ShareModel {
    enum Phase { case reading, ready(NazcaConstancia.Result), saved(NazcaConstancia.Result), failed }

    private(set) var phase: Phase = .reading
    @ObservationIgnored private let context: NSExtensionContext?

    init(context: NSExtensionContext?) { self.context = context }

    func start() async {
        // Se prueba cada lectura posible (texto, imagen con y sin corrección de idioma, PDF) y se queda con la primera que da una constancia.
        var found: NazcaConstancia.Result?
        for text in await candidates() where NazcaConstancia.detect(text) > 0 {
            if let r = NazcaConstancia.read(text, today: Self.todayISO()) { found = r; break }
        }
        guard let r = found else {
            phase = .failed
            return
        }
        // Si reconoce Yape o Plin, hay número de operación y no hay dudas, se guarda sin preguntar; si no, se muestra para confirmar.
        if r.auto { save(r) } else { phase = .ready(r) }
    }

    func save(_ r: NazcaConstancia.Result) {
        guard ConstanciaInbox.append(ConstanciaInbox.Entry(r)) else { phase = .failed; return }
        phase = .saved(r)
        Task { try? await Task.sleep(for: .milliseconds(1500)); finish() }
    }

    func finish() { context?.completeRequest(returningItems: nil) }

    func cancel() { context?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)) }

    static func todayISO() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: lo compartido

    /// Las lecturas posibles de lo compartido, en este orden: texto, imagen (OCR, dos pasadas) y PDF.
    private func candidates() async -> [String] {
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var out: [String] = []
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let t = try? await string(of: p), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(t) }
        }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            guard let d = try? await data(of: p, type: .image) else { continue }
            for strict in [true, false] {
                if let t = try? await ConstanciaOCR.text(fromImageData: d, strict: strict), !t.isEmpty { out.append(t) }
            }
        }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            if let d = try? await data(of: p, type: .pdf), let t = try? await ConstanciaOCR.text(fromPDFData: d), !t.isEmpty { out.append(t) }
        }
        return out
    }

    private func string(of p: NSItemProvider) async throws -> String? {
        let item = try await p.loadItem(forTypeIdentifier: UTType.plainText.identifier)
        if let s = item as? String { return s }
        if let d = item as? Data { return String(data: d, encoding: .utf8) }
        if let u = item as? URL { return try? String(contentsOf: u, encoding: .utf8) }
        return nil
    }

    private func data(of p: NSItemProvider, type: UTType) async throws -> Data? {
        let item = try await p.loadItem(forTypeIdentifier: type.identifier)
        if let u = item as? URL { return try Data(contentsOf: u) }
        if let d = item as? Data { return d }
        if let i = item as? UIImage { return i.pngData() }
        return nil
    }
}
