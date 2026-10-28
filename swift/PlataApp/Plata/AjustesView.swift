import SwiftUI
import UniformTypeIdentifiers
import PlataCore

/// Título de pantalla de la web: texto pequeño arriba (`.eyebrow`) y título de 34 pt (`h1`).
struct PageHead: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow).font(.inter(15)).foregroundStyle(.secondary)
            Text(title).font(.inter(34, .bold, relativeTo: .largeTitle)).tracking(-1.2).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 10)
    }
}

/// Nota pequeña bajo una tarjeta de ajustes.
struct SettingsNote: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text).font(.inter(13)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.bottom, 6)
    }
}

/// Fila de ajustes (`.row`): título a la izquierda y el control a la derecha.
struct SettingRow<Trailing: View>: View {
    let title: LocalizedStringKey
    var note: LocalizedStringKey? = nil
    var first = false
    let trailing: Trailing
    init(_ title: LocalizedStringKey, note: LocalizedStringKey? = nil, first: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.note = note; self.first = first; self.trailing = trailing()
    }
    var body: some View {
        VStack(spacing: 0) {
            if !first { RowDivider() }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.inter(17))
                    if let note { Text(note).font(.inter(13)).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 12)
        }
    }
}

/// Campo numérico o de texto pequeño de la web (`.mini`): 40 pt de alto, fondo gris, texto a la derecha.
struct MiniField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var width: CGFloat = 96
    var numeric = true
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(numeric ? .decimalPad : .default)
            .multilineTextAlignment(.trailing)
            .font(.inter(17))
            .padding(.horizontal, 12)
            .frame(width: width, height: 40)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Fila-botón con enlace verde (`.linkrow`): icono y texto de 17 pt, 44 pt como mínimo.
struct LinkRow: View {
    var symbol: String?
    let title: LocalizedStringKey
    var color: Color = Brand.accent
    var first = false
    var trailing: AnyView? = nil
    let action: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            if !first { RowDivider() }
            Button(action: action) {
                HStack(spacing: 10) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 20)).frame(width: 26) }
                    Text(title).font(.inter(17)).frame(maxWidth: trailing == nil ? .infinity : nil, alignment: .leading)
                    if let trailing { Spacer(minLength: 8); trailing }
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// «Perfil de demostración» con el botón para salir (la web lo muestra en Ajustes).
struct DemoNoticeCard: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Brand.accent).frame(width: 10, height: 10)
                Text("Perfil de demostración").font(.inter(16, .semibold))
            }
            Text("Estás viendo datos de ejemplo. Tus datos reales siguen guardados aparte y vuelven cuando salgas del demo.")
                .font(.inter(14)).foregroundStyle(.secondary).padding(.top, 6).padding(.bottom, 10)
            Button { try? model.exitDemo() } label: {
                Text("Salir del demo").font(.inter(15, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Brand.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 14)
    }
}

/// La pantalla «Ajustes» de la web (`settingsHTML`).
struct AjustesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var cushion = ""
    @State private var variable = ""
    @State private var loaded = false
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingImport: Data?
    @State private var confirmWipe = false
    @State private var showDemos = false
    @State private var message: String?

    var body: some View {
        let e = model.engine
        let s = e.data["settings"]
        let insights = s?["insights"] != .bool(false)
        let score = insights && s?["score"] != .bool(false)
        let hidden = hiddenAccounts(e)
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: "Perfil y preferencias", title: "Ajustes")
                profileCard(e)
                if model.isDemo { DemoNoticeCard() }
                status
                    .padding(.top, 12).padding(.bottom, 4)

                SCard {
                    LinkRow(symbol: "folder", title: "Cargar archivo de perfil", color: Brand.green, first: true) { importing = true }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 20)).frame(width: 26)
                                Text("Guardar archivo de perfil").font(.inter(17))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Brand.green)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .overlay(alignment: .top) { RowDivider() }
                    }
                }
                .padding(.top, 8)

                SCard {
                    SettingRow("Insights y half‑time", first: true) {
                        Toggle("", isOn: Binding(get: { insights }, set: { model.setSetting("insights", .bool($0)) })).labelsHidden().tint(Brand.accent)
                    }
                    SettingRow("Puntuación mensual") {
                        Toggle("", isOn: Binding(get: { score }, set: { model.setSetting("score", .bool($0)) })).labelsHidden().tint(Brand.accent)
                            .disabled(!insights)
                    }
                }
                SettingsNote(text: "Esta información no es recopilada por Plata ni Estudio 22. Toda la información se maneja en tu archivo de perfil.")

                if !hidden.isEmpty {
                    SectionHead("Cuentas ocultas").padding(.top, 30).padding(.bottom, 0)
                    SCard {
                        ForEach(Array(hidden.enumerated()), id: \.offset) { i, a in
                            SettingRow(LocalizedStringKey(Engine.text(a["name"])), first: i == 0) {
                                Toggle("", isOn: Binding(get: { false }, set: { _ in model.setAccountHidden(id: Engine.identifier(a["id"]), hidden: false) }))
                                    .labelsHidden().tint(Brand.accent)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }

                SCard {
                    SettingRow("Gasto variable por semana", note: "Gasto semanal estimado fuera de lo programado.", first: true) {
                        MiniField(placeholder: "0", text: $variable)
                    }
                    SettingRow("Colchón mínimo", note: "Si tu saldo proyectado baja de aquí, te avisamos.") {
                        MiniField(placeholder: "0", text: $cushion)
                    }
                }

                SCard {
                    LinkRow(symbol: "slider.horizontal.3", title: "Cargar perfil de demostración", color: Brand.green, first: true) { showDemos = true }
                    LinkRow(symbol: nil, title: "Borrar datos", color: Brand.lossText) { wipe() }
                    LinkRow(symbol: nil, title: "Borrar datos y regresar a pantalla inicial", color: Brand.lossText) { wipe() }
                }

                SCard {
                    LinkRow(symbol: "gift", title: "Novedades", color: Brand.green, first: true,
                            trailing: AnyView(BetaPill(label: "B E T A  4"))) { model.showNews = true }
                }
                SCard {
                    LinkRow(symbol: "star", title: "Danos tu opinión", color: Brand.green, first: true) { model.feedbackManual = true; model.showFeedback = true }
                }
                SCard {
                    LinkRow(symbol: "checkmark.shield", title: "Transparencia", color: Brand.green, first: true) { openURL(Prefs.transparencyURL) }
                }

                if let message {
                    Text(message).font(.inter(14)).foregroundStyle(.secondary).padding(.bottom, 8)
                }

                Button { model.path.append(.credits) } label: {
                    VStack(spacing: 0) {
                        Text("Estudio 22").font(.inter(18, .heavy)).tracking(-0.5).padding(.bottom, 12)
                        Text("Diseñado por Estudio 22 en Nueva York.").font(.inter(13)).foregroundStyle(.secondary)
                        Text("© Estudio 22 y Leonardo Richarte, 2026.").font(.inter(13)).foregroundStyle(.secondary).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30).padding(.bottom, 8)
                }
                .buttonStyle(.plain)

                Text("Los nombres y logos de bancos, billeteras y servicios son marcas de sus respectivos titulares. Plata los muestra solo para ayudarte a reconocer tus cuentas y suscripciones; no está afiliada, patrocinada ni respaldada por ninguna de estas entidades.")
                    .font(.inter(11.5)).foregroundStyle(.secondary).opacity(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { load() }
        .onChange(of: model.changes) { _, _ in refreshExport() }
        .onDisappear(perform: commitFields)
        .sheet(isPresented: $showDemos) { DemoPickerSheet() }
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
            Text("Lo que tienes ahora se sustituye. Guarda antes un archivo si quieres conservarlo.")
        }
        .confirmationDialog("¿Borrar todos tus datos?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Borrar datos", role: .destructive) { try? model.resetProfile(); load(force: true) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer. Guarda tu archivo de perfil antes si quieres conservarlos.")
        }
    }

    // MARK: piezas

    private func profileCard(_ e: Engine) -> some View {
        let s = e.data["settings"]
        let name = [Engine.text(s?["first"]), Engine.text(s?["last"])].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return Button { model.path.append(.profile) } label: {
            HStack(spacing: 16) {
                AvatarView(size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? "Tu perfil" : name).font(.inter(22, .bold)).tracking(-0.4).lineLimit(1)
                    Text("Preferencias de usuario, monedas y Plata Cloud").font(.inter(14)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var status: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                Text("Guardado").font(.inter(16, .semibold))
            }
            .foregroundStyle(Brand.gainText)
            Text(lastSavedLabel()).font(.inter(13)).foregroundStyle(.secondary).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func lastSavedLabel() -> String {
        guard let d = model.lastSaved else { return "Última vez guardado · nunca" }
        let c = Calendar.current.dateComponents([.weekday, .day, .month, .hour, .minute], from: d)
        var h = c.hour ?? 0
        let ap = h >= 12 ? "p. m." : "a. m."
        h = h % 12 == 0 ? 12 : h % 12
        let wd = Spanish.weekdaysShort[((c.weekday ?? 1) - 1) % 7]
        let mi = String(format: "%02d", c.minute ?? 0)
        return "Última vez guardado · \(wd) \(c.day ?? 1) \(Spanish.monthsShort[((c.month ?? 1) - 1) % 12]), \(h):\(mi) \(ap)"
    }

    private func hiddenAccounts(_ e: Engine) -> [JSONValue] {
        let all = (e.data["accounts"]?.arrayValue ?? []) + (e.data["cards"]?.arrayValue ?? [])
        return all.filter { Engine.flag($0["hid"]) }
    }

    // MARK: campos y archivo

    private func load(force: Bool = false) {
        if loaded && !force { return }
        loaded = true
        let s = model.engine.data["settings"]
        cushion = numText(Engine.number(s?["cushion"]))
        variable = numText(Engine.number(s?["variable_weekly"]))
        refreshExport()
    }

    private func numText(_ n: Double) -> String { n == 0 ? "" : (n == n.rounded() ? String(Int64(n)) : String(n)) }

    private func saveNumber(_ key: String, _ text: String) {
        let t = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let n = t.isEmpty ? 0 : (Double(t) ?? 0)
        model.setSetting(key, .number(max(0, min(999_999_999, n))))
    }

    /// Al salir de la pantalla se guardan los campos que quedaron a medias.
    private func commitFields() {
        saveNumber("cushion", cushion)
        saveNumber("variable_weekly", variable)
    }

    private func refreshExport() { exportURL = try? model.exportFile() }

    private func wipe() {
        if model.isDemo { try? model.exitDemo() } else { confirmWipe = true }
    }

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

/// «Perfil» de la web (`profileHTML`): nombre, género, hemisferio y monedas.
struct ProfileSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var first = ""
    @State private var last = ""
    @State private var nick = ""
    @State private var fxText = ""
    @State private var loaded = false

    var body: some View {
        let e = model.engine
        let s = e.data["settings"]
        let gender = Engine.text(s?["gender"]).isEmpty ? "n" : Engine.text(s?["gender"])
        let hemi = Engine.text(s?["hemi"])
        let score = s?["insights"] != .bool(false) && s?["score"] != .bool(false)
        let f = model.fmt
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: "Perfil", title: "Editar perfil")
                PhotoRow()
                SCard {
                    SettingRow("Nombre", first: true) { MiniField(placeholder: "", text: $first, width: 190, numeric: false) }
                    SettingRow("Apellido") { MiniField(placeholder: "", text: $last, width: 190, numeric: false) }
                    SettingRow("Apodo") { MiniField(placeholder: "Opcional", text: $nick, width: 190, numeric: false) }
                    SettingRow("Género") {
                        Picker("Género", selection: Binding(get: { gender }, set: { model.setSetting("gender", .string($0)) })) {
                            Text("Neutro").tag("n"); Text("Masculino").tag("m"); Text("Femenino").tag("f")
                        }
                        .labelsHidden().tint(.primary)
                    }
                }
                if score {
                    SCard {
                        SettingRow("Mostrar puntuaciones", first: true) {
                            Toggle("", isOn: Binding(get: { s?["showGrades"] != .bool(false) }, set: { model.setSetting("showGrades", .bool($0)) }))
                                .labelsHidden().tint(Brand.accent)
                        }
                    }
                    SettingsNote(text: "Muestra tus puntajes históricos bajo tu foto.")
                }
                LanguageCard(editable: true)
                ThemeCard()
                SCard {
                    SettingRow("Hemisferio", first: true) {
                        Picker("Hemisferio", selection: Binding(get: { hemi }, set: { model.setSetting("hemi", .string($0)) })) {
                            Text("Automático").tag(""); Text("Norte").tag("n"); Text("Sur").tag("s")
                        }
                        .labelsHidden().tint(.primary)
                    }
                }
                SettingsNote(text: "Define la estación de tu aviso mensual.")
                TutorialCard()

                SCard {
                    SettingRow("Moneda principal", note: LocalizedStringKey(e.primaryCurrency), first: true) {
                        Text("\(f.symbol(e.primaryCurrency).trimmingCharacters(in: .whitespaces)) \(e.primaryCurrency)").font(.inter(17)).foregroundStyle(.secondary)
                    }
                    SettingRow("Segunda moneda", note: e.secondaryCurrency.isEmpty ? "Opcional" : LocalizedStringKey(e.secondaryCurrency)) {
                        Text(e.secondaryCurrency.isEmpty ? "Ninguna" : "\(f.symbol(e.secondaryCurrency).trimmingCharacters(in: .whitespaces)) \(e.secondaryCurrency)").font(.inter(17)).foregroundStyle(.secondary)
                    }
                    if !e.secondaryCurrency.isEmpty {
                        SettingRow(LocalizedStringKey("1 \(e.primaryCurrency) en \(e.secondaryCurrency)")) { MiniField(placeholder: "", text: $fxText) }
                    }
                }
                SettingsNote(text: "Puedes usar hasta 2 monedas a la vez. El tipo de cambio es tuyo: edítalo cuando cambie. Cambiar de moneda llega en una próxima versión de la app.")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: load)
        .onDisappear(perform: commit)
    }

    private func load() {
        if loaded { return }
        loaded = true
        let s = model.engine.data["settings"]
        first = Engine.text(s?["first"]); last = Engine.text(s?["last"]); nick = Engine.text(s?["nick"])
        let fx = Engine.number(s?["fx"])
        fxText = fx == 0 ? "" : (fx == fx.rounded() ? String(Int64(fx)) : String(fx))
    }

    private func commit() {
        model.setSetting("first", .string(first.trimmingCharacters(in: .whitespaces)))
        model.setSetting("last", .string(last.trimmingCharacters(in: .whitespaces)))
        model.setSetting("nick", .string(nick.trimmingCharacters(in: .whitespaces)))
        let t = fxText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if !model.engine.secondaryCurrency.isEmpty, let n = Double(t), n > 0 { model.setSetting("fx", .number(n)) }
    }
}
