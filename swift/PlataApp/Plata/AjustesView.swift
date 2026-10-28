import SwiftUI
import UniformTypeIdentifiers
import PlataCore

struct AjustesView: View {
    @Environment(AppModel.self) private var model
    @State private var nick = ""
    @State private var cushion = ""
    @State private var variable = ""
    @State private var fxText = ""
    @State private var loaded = false
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingImport: Data?
    @State private var confirmReset = false
    @State private var message: String?

    var body: some View {
        let e = model.engine
        let f = model.fmt
        Group {
            Form {
                Section("Perfil") {
                    TextField("Tu nombre", text: $nick)
                        .textContentType(.givenName)
                        .onSubmit { model.setSetting("nick", .string(nick.trimmingCharacters(in: .whitespaces))) }
                }

                Section {
                    LabeledContent("Moneda principal", value: "\(f.symbol(e.primaryCurrency)) \(e.primaryCurrency)")
                    if !e.secondaryCurrency.isEmpty {
                        LabeledContent("Segunda moneda", value: "\(f.symbol(e.secondaryCurrency)) \(e.secondaryCurrency)")
                        HStack {
                            Text("1 \(e.primaryCurrency) =")
                            TextField("Tipo de cambio", text: $fxText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onSubmit(saveFx)
                            Text(e.secondaryCurrency).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Monedas")
                } footer: {
                    Text("Cambiar de moneda llega en una próxima versión; por ahora se hace en la web.")
                }

                Section {
                    HStack {
                        Text("Colchón")
                        TextField("0", text: $cushion).keyboardType(.decimalPad).multilineTextAlignment(.trailing).onSubmit { saveNumber("cushion", cushion) }
                    }
                    HStack {
                        Text("Gasto variable semanal")
                        TextField("0", text: $variable).keyboardType(.decimalPad).multilineTextAlignment(.trailing).onSubmit { saveNumber("variable_weekly", variable) }
                    }
                } header: {
                    Text("Proyección")
                } footer: {
                    Text("El colchón es el mínimo que quieres conservar. El gasto variable es lo que sueles gastar cada semana fuera de lo previsto.")
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Exportar archivo de perfil", systemImage: "square.and.arrow.up") }
                    }
                    Button { importing = true } label: { Label("Importar archivo de perfil", systemImage: "square.and.arrow.down") }
                    Button(role: .destructive) { confirmReset = true } label: { Label("Borrar todos los datos", systemImage: "trash") }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("El archivo de perfil es el mismo que usa la versión web de Plata: lo que exportes aquí lo abres allá, y al revés.")
                }

                if let message {
                    Section { Text(message).foregroundStyle(.secondary) }
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("Ajustes")
            .onAppear { load() }
            .onChange(of: model.changes) { _, _ in refreshExport() }
            .onDisappear(perform: commitFields)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) { pendingImport = data } else { message = "No se pudo leer el archivo." }
            }
            .confirmationDialog("¿Reemplazar tus datos con este archivo?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                Button("Reemplazar", role: .destructive) { applyImport() }
                Button("Cancelar", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Lo que tienes ahora se sustituye. Exporta antes un archivo si quieres conservarlo.")
            }
            .confirmationDialog("¿Borrar todos los datos de este dispositivo?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { try? model.resetProfile(); load(force: true) }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("No se puede deshacer. Exporta un archivo antes si quieres una copia.")
            }
        }
    }

    // MARK: campos

    private func load(force: Bool = false) {
        if loaded && !force { return }
        loaded = true
        let e = model.engine
        let s = e.data["settings"]
        nick = Engine.text(s?["nick"])
        cushion = numText(Engine.number(s?["cushion"]))
        variable = numText(Engine.number(s?["variable_weekly"]))
        fxText = numText(Engine.number(s?["fx"]))
        refreshExport()
    }

    private func numText(_ n: Double) -> String { n == 0 ? "" : (n == n.rounded() ? String(Int64(n)) : String(n)) }

    private func saveNumber(_ key: String, _ text: String) {
        let t = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let n = t.isEmpty ? 0 : (Double(t) ?? 0)
        model.setSetting(key, .number(max(0, min(999_999_999, n))))
    }

    private func saveFx() {
        let t = fxText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let n = Double(t), n > 0 { model.setSetting("fx", .number(n)) }
    }

    /// Al salir de la pantalla se guardan los campos que quedaron a medias (sin pulsar intro).
    private func commitFields() {
        model.setSetting("nick", .string(nick.trimmingCharacters(in: .whitespaces)))
        saveNumber("cushion", cushion)
        saveNumber("variable_weekly", variable)
        if !model.engine.secondaryCurrency.isEmpty { saveFx() }
    }

    private func refreshExport() { exportURL = try? model.exportFile() }

    private func applyImport() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try model.importProfile(data)
            message = "Archivo importado."
            load(force: true)
        } catch MigrationError.legacyFormat {
            message = "Este archivo es de una versión muy antigua de Plata y no se puede abrir aquí."
        } catch {
            message = "Este archivo no parece un perfil de Plata."
        }
    }
}
