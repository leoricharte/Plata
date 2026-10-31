import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers
import PlataCore

/// Lo que pasa dentro de la extensión: juntar el texto de lo compartido, leerlo con Nazca y dejarlo en la bandeja.
@MainActor
@Observable
final class ShareModel {
    enum Kind { case image, file }
    enum Phase { case reading, choose(Kind), ready(NazcaConstancia.Result), saved(NazcaConstancia.Result), handedOff, failed }

    private(set) var phase: Phase = .reading
    @ObservationIgnored private let context: NSExtensionContext?

    init(context: NSExtensionContext?) { self.context = context }

    private var providers: [NSItemProvider] { (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] } }

    private static let sheetTypes: [UTType] = [UTType("org.openxmlformats.spreadsheetml.sheet"), UTType("com.microsoft.excel.xls"), UTType(filenameExtension: "xlsx"), UTType(filenameExtension: "xls")].compactMap { $0 }

    private func conforms(_ p: NSItemProvider, to types: [UTType]) -> Bool {
        p.registeredTypeIdentifiers.contains { id in UTType(id).map { t in types.contains { t.conforms(to: $0) } } ?? false }
    }

    private func isTable(_ p: NSItemProvider) -> Bool { conforms(p, to: [.commaSeparatedText, .tabSeparatedText] + Self.sheetTypes) }

    func start() async {
        // Una captura o una hoja de cálculo: primero se elige qué hacer. El resto (texto, PDF) intenta leerse como constancia.
        if providers.contains(where: isTable) { phase = .choose(.file); return }
        if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) { phase = .choose(.image); return }
        await readConstancia()
    }

    /// «Constancia de Yape o Plin»: la lectura de siempre.
    func readAsConstancia() async { phase = .reading; await readConstancia() }

    /// Deja la captura o el archivo para la app y avisa. La app lo recoge cuando se abre.
    func handOff(_ choice: ShareHandoff.Choice) async {
        phase = .reading
        guard let (data, name) = await payload(for: choice), ShareHandoff.stash(data: data, name: name, choice: choice) else { phase = .failed; return }
        phase = .handedOff
        Task { try? await Task.sleep(for: .milliseconds(2600)); finish() }
    }

    private func payload(for choice: ShareHandoff.Choice) async -> (Data, String)? {
        let p: NSItemProvider?
        let id: String
        if choice == .recognition {
            p = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }; id = UTType.image.identifier
        } else if let t = providers.first(where: isTable) {
            p = t; id = t.registeredTypeIdentifiers.first { UTType($0).map { u in ([.commaSeparatedText, .tabSeparatedText] + Self.sheetTypes).contains { u.conforms(to: $0) } } ?? false } ?? UTType.data.identifier
        } else {
            p = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }; id = UTType.pdf.identifier
        }
        guard let p, let item = try? await p.loadItem(forTypeIdentifier: id) else { return nil }
        let ext = UTType(id)?.preferredFilenameExtension ?? ""
        let base = p.suggestedName ?? (choice == .recognition ? "captura" : "archivo")
        if let u = item as? URL, let d = try? Data(contentsOf: u) { return (d, u.lastPathComponent) }
        if let d = item as? Data { return (d, ext.isEmpty || base.lowercased().hasSuffix("." + ext) ? base : base + "." + ext) }
        if let i = item as? UIImage, let d = i.pngData() { return (d, base + ".png") }
        return nil
    }

    private func readConstancia() async {
        // Se prueba cada lectura posible (texto, imagen con y sin corrección de idioma, PDF) y se queda con la primera que da una constancia.
        var found: NazcaConstancia.Result?
        for text in await candidates() where NazcaConstancia.detect(text) > 0 {
            if let r = NazcaConstancia.read(text, today: Self.todayISO()) { found = r; break }
        }
        guard let r = found else {
            // Un PDF que no es una constancia es un estado de cuenta: se ofrece importarlo.
            phase = providers.contains { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) } ? .choose(.file) : .failed
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
