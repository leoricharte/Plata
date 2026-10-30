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
        guard let text = try? await gatherText(), NazcaConstancia.detect(text) > 0, let r = NazcaConstancia.read(text, today: Self.todayISO()) else {
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

    /// Prueba, en este orden: texto, imagen (OCR) y PDF. Lo primero que da un texto con monto es lo que se usa.
    private func gatherText() async throws -> String {
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let t = try? await string(of: p), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let d = try? await data(of: p, type: .image), let t = try? await ConstanciaOCR.text(fromImageData: d), !t.isEmpty { return t }
        }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            if let d = try? await data(of: p, type: .pdf), let t = try? await ConstanciaOCR.text(fromPDFData: d), !t.isEmpty { return t }
        }
        throw ConstanciaOCR.Failure.unreadable
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
