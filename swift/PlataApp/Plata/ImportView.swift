import SwiftUI
import UniformTypeIdentifiers
import PlataCore

/// «Importar datos de banco» (la pasarela de importación de la web, `imp*`): elegir el archivo, revisar lo que Nazca leyó y confirmar.
/// Todo se lee en el dispositivo. Hoy lee CSV; los estados de cuenta en PDF y los reportes en Excel llegan después.
struct ImportFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Step { case start, how, country, banks, bank, busy, review, done }

    struct Notice: Equatable { var title: String; var message: String }

    @State private var step: Step = .start
    @State private var origin: Step = .start
    @State private var reviews: [ImportReview] = []
    @State private var idx = 0
    @State private var notice: Notice?
    @State private var applied: ImportReview.Applied?
    @State private var picking = false
    @State private var seen = Set<String>()
    @State private var bank: String?
    @State private var country = "PE"

    private var head: (String, String) {
        switch step {
        case .start: return ("Importar", "Datos de banco")
        case .how: return ("Importar archivo", "Cómo funciona")
        case .country: return ("Datos de banco", "Tu país")
        case .banks: return (Nazca.bankCatalog.first { $0.id == country }?.name ?? "Perú", "Tu banco")
        case .bank: return (Nazca.countryName(bank ?? ""), Nazca.bankShort(bank))
        case .busy: return ("Datos de banco", "Leyendo…")
        case .done: return ("Listo", "Importado")
        case .review:
            let label = reviews.indices.contains(idx) ? reviews[idx].source?.label ?? "" : ""
            return (label.isEmpty ? "Archivo CSV" : label, "Revisar")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    PageHead(eyebrow: head.0, title: head.1)
                    if let notice { NoticeCard(notice: notice) }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .busy && step != .done {
                        Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)) }
                            .accessibilityLabel("Regresar")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { if step == .review && reviews.indices.contains(idx) { bar } }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: Self.types, allowsMultipleSelection: true) { handle($0) }
        .interactiveDismissDisabled(step == .busy)
        .tint(Brand.accent)
    }

    private static let types: [UTType] = [.commaSeparatedText, .tabSeparatedText, .plainText, .text, UTType(filenameExtension: "csv"), UTType(filenameExtension: "tsv"), UTType(filenameExtension: "xlsx")].compactMap { $0 }

    // MARK: pantallas

    @ViewBuilder private var content: some View {
        switch step {
        case .start: startBody
        case .how: howBody
        case .country: countryBody
        case .banks: banksBody
        case .bank: bankBody
        case .busy: busyBody
        case .review: reviewBody
        case .done: doneBody
        }
    }

    private var startBody: some View {
        VStack(spacing: 0) {
            Text("Trae tus movimientos desde tu banco, sin conectar tus cuentas.")
                .font(.inter(16)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.bottom, 14)
            SCard {
                GoRow(symbol: "folder", title: "Importar archivo",
                      sub: "Importa un archivo CSV o un estado de cuenta de tu banco. Plata usará Nazca para interpretarlo.") { bank = nil; pick(from: .start) }
                Button { step = .how; notice = nil } label: {
                    Text("Ver cómo funciona…").font(.inter(17)).foregroundStyle(Brand.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 38).padding(.bottom, 12)
                }
                .buttonStyle(.plain)
                GoRow(symbol: "building.columns", title: "Elegir banco",
                      sub: "Revisa una lista de bancos donde Nazca tiene funciones de interpretación avanzada.") { step = .country; notice = nil }
            }
            privacyNote
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "checkmark.shield").font(.system(size: 13)).padding(.top, 1)
            Text("Todo se lee en este dispositivo. Plata no se conecta a tu banco ni te pide las claves de tu banca por internet.")
        }
        .font(.inter(13)).foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14).padding(.bottom, 14)
    }

    private var howBody: some View {
        VStack(spacing: 0) {
            SCard {
                HowStep(n: 1, title: "Descarga el archivo", text: "En la banca por internet de tu banco busca Descargar o Exportar movimientos y elige CSV, o descarga tu estado de cuenta.")
                HowStep(n: 2, title: "Elígelo aquí", text: "Plata lo lee en tu dispositivo con Nazca. No se sube a ningún servidor, salvo que tú decidas mandarlo.")
                HowStep(n: 3, title: "Revisa la lista", text: "Nazca reconoce el banco y detecta solo las fechas, los montos y la moneda, y marca los movimientos repetidos.")
                HowStep(n: 4, title: "Importa", text: "Eliges qué hacer con el saldo y, si algo sale mal, puedes deshacerlo.")
            }
            Button { bank = nil; pick(from: .how) } label: { Text("Elegir archivo") }
                .buttonStyle(PrimaryPillStyle())
                .padding(.top, 8)
        }
    }

    private var countryBody: some View {
        VStack(spacing: 0) {
            SCard {
                ForEach(Array(Nazca.bankCatalog.enumerated()), id: \.element.id) { k, c in
                    if k > 0 { RowDivider() }
                    GoRow(symbol: "globe", title: c.name, sub: nil, verbatimTitle: true) { country = c.id; step = .banks; notice = nil }
                }
            }
            Text("Más países, pronto.").font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 14).padding(.vertical, 14)
        }
    }

    private var banksBody: some View {
        let c = Nazca.bankCatalog.first { $0.id == country } ?? Nazca.bankCatalog[0]
        return VStack(spacing: 0) {
            SCard {
                ForEach(Array(c.banks.enumerated()), id: \.element.id) { k, b in
                    if k > 0 { RowDivider() }
                    let on = b.active && Nazca.ready.contains(b.id)
                    Button { bank = b.id; step = .bank; notice = nil } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.columns").font(.system(size: 18)).foregroundStyle(.secondary)
                                .frame(width: 38, height: 38).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(verbatim: b.name).font(.inter(16))
                                Text(verbatim: b.hq).font(.inter(13.5)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if on { Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(.tertiary) }
                            else { Text("No disponible").font(.inter(14)).foregroundStyle(.secondary) }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!on)
                    .opacity(on ? 1 : 0.55)
                }
            }
            VStack(spacing: 0) {
                Text("¿Quieres que añadamos el banco que usas? Manda un correo a") + Text(verbatim: " devs@plataapp.net ").foregroundStyle(Brand.green)
                    + Text("para aportar al entrenamiento de Nazca, nuestro motor de reconocimiento de estados de cuenta.")
            }
            .font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 14).padding(.vertical, 14)
        }
    }

    private var bankBody: some View {
        let id = bank ?? ""
        let steps = Nazca.bankSteps[id]
        return VStack(spacing: 0) {
            if let steps {
                SCard {
                    ForEach(Array(steps.enumerated()), id: \.offset) { k, t in
                        HStack(alignment: .top, spacing: 14) {
                            Text(verbatim: "\(k + 1)").font(.inter(13, .bold)).foregroundStyle(.white)
                                .frame(width: 24, height: 24).background(Brand.accent, in: Circle())
                            Text(t).font(.inter(17)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                    }
                }
            } else {
                Text("Descarga tu estado de cuenta de ahorros desde Interbank APP o la banca por internet de Interbank.")
                    .font(.inter(16)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.bottom, 14)
            }
            Button { pick(from: .bank) } label: { Text(id == "yape" ? "Subir reporte de movimientos" : "Subir estado de cuenta") }
                .buttonStyle(PrimaryPillStyle())
                .padding(.top, 8)
        }
    }

    private var busyBody: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).padding(.top, 40)
            Text("Nazca está leyendo tu estado de cuenta en este dispositivo.")
                .font(.inter(16)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var reviewBody: some View {
        if reviews.indices.contains(idx) {
            VStack(spacing: 0) {
                if reviews.count > 1 { strip }
                ImportReviewBody(review: $reviews[idx], multi: reviews.count > 1, onRemove: removeCurrent)
                    .id(idx)
            }
        }
    }

    private var strip: some View {
        HStack(spacing: 9) {
            ForEach(reviews.indices, id: \.self) { k in
                Button { idx = k } label: {
                    Circle().fill(k == idx ? Brand.accent : Color(.tertiarySystemFill)).frame(width: 9, height: 9)
                        .scaleEffect(k == idx ? 1.25 : 1)
                        .frame(width: 22, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(k + 1)")
            }
            Text(verbatim: "\(idx + 1) / \(reviews.count)").font(.inter(13)).foregroundStyle(.secondary).monospacedDigit().padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    private var bar: some View {
        let total = reviews.reduce(0) { $0 + $1.enabled.count }
        return VStack(spacing: 10) {
            Button {
                importAll()
            } label: {
                Text(verbatim: Tr.t("Importar") + " " + Tr.t(Spanish.plural(total, "movimiento", "movimientos")) + (reviews.count > 1 ? " (\(reviews.count))" : ""))
            }
            .buttonStyle(PrimaryPillStyle())
            .disabled(total == 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: { Text("Cancelar") }.buttonStyle(SecondaryPillStyle())
                Button { more() } label: {
                    Label { Text("Cargar más") + Text(verbatim: " (\(reviews.count)/\(ImportReview.maxFiles))") } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(SecondaryPillStyle())
                .opacity(reviews.count >= ImportReview.maxFiles ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        .background(.bar)
    }

    private var doneBody: some View {
        let f = model.fmt
        return VStack(spacing: 0) {
            Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                .frame(width: 72, height: 72).background(Brand.accent, in: Circle())
                .shadow(color: Brand.accent.opacity(0.5), radius: 14, y: 8)
                .padding(.top, 4).padding(.bottom, 16)
            ForEach(Array((applied?.dones ?? []).enumerated()), id: \.offset) { _, d in
                SCard {
                    DoneRow(label: "Movimientos") { Text(verbatim: "\(d.n)").font(.inter(17, .bold)) }
                    DoneRow(label: "Cuenta") { Text(verbatim: d.account).font(.inter(17)).multilineTextAlignment(.trailing) }
                    DoneRow(label: d.credit ? "Deuda" : "Saldo") { Text(verbatim: f.exact(d.balance, d.cur)).font(.inter(17, .bold)) }
                }
            }
            if applied?.dones.contains(where: \.created) == true {
                Text("Creamos la cuenta nueva con el saldo de tu estado de cuenta.").font(.inter(13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 14).padding(.bottom, 14)
            }
            Button {
                dismiss()
                model.tab = .resumen
                if model.path.last != .movimientos { model.path.append(.movimientos) }
            } label: { Text("Ver movimientos") }
                .buttonStyle(PrimaryPillStyle())
                .padding(.top, 4)
            Button { reviews = []; applied = nil; notice = nil; seen = []; step = .start } label: {
                Text("Cargar más").font(.inter(17)).foregroundStyle(Brand.green).frame(maxWidth: .infinity, minHeight: 44)
            }
            Button { undo() } label: {
                Text("Deshacer importación").font(.inter(17)).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    // MARK: acciones

    private func back() {
        notice = nil
        switch step {
        case .start: dismiss()
        case .how, .country: step = .start
        case .banks: step = .country
        case .bank: step = .banks
        case .review: reviews = []; seen = []; step = origin
        default: break
        }
    }

    private func pick(from: Step) {
        origin = from
        notice = nil
        picking = true
    }

    private func more() {
        if reviews.count >= ImportReview.maxFiles {
            notice = Notice(title: Tr.t("Se revisan 3 archivos a la vez"), message: Tr.t("Importa o quita uno y usa «Cargar más»."))
            return
        }
        picking = true
    }

    private func removeCurrent() {
        guard reviews.count > 1 else { return }
        notice = nil
        reviews.remove(at: idx)
        idx = min(idx, reviews.count - 1)
    }

    private func importAll() {
        var parts: [ImportReview.Applied.Part] = [], dones: [ImportReview.Applied.Done] = []
        for r in reviews {
            if let a = model.importApply(r) { parts += a.parts; dones += a.dones }
        }
        guard !parts.isEmpty else { return }
        applied = ImportReview.Applied(parts: parts, dones: dones)
        notice = nil
        step = .done
    }

    private func undo() {
        if let applied { model.importUndo(applied) }
        applied = nil
        dismiss()
    }

    // MARK: lectura de archivos

    private struct Picked { var name: String; var size: Int; var data: Data? }

    private func handle(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        let adding = step == .review && !reviews.isEmpty
        var files: [Picked] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let data = size <= Nazca.maxBytes ? try? Data(contentsOf: url) : nil
            files.append(Picked(name: url.lastPathComponent, size: size, data: data))
        }
        notice = nil
        if !adding { step = .busy }
        Task { await ingest(files, adding: adding) }
    }

    private enum Outcome { case review(ImportReview), fail(String, String), empty }
    private struct Parsed: Sendable { var analysis: Nazca.Analysis; var items: [Nazca.Item]; var unreadable: Int }

    @MainActor private func ingest(_ files: [Picked], adding: Bool) async {
        await Task.yield()
        var list = adding ? reviews : []
        var fails: [(name: String, title: String, message: String)] = [], over: [String] = [], dupes: [String] = [], empty: [String] = []
        var last = -1
        for f in files {
            let sig = f.name + "|" + String(f.size)
            if seen.contains(sig) { dupes.append(String(f.name.prefix(60))); continue }
            let outcome = await read(f)
            switch outcome {
            case .review(let r):
                if let j = list.firstIndex(where: { $0.isSame(as: r) }) {
                    list[j].merge(r, engine: model.engine); last = j; seen.insert(sig)
                } else if list.count >= ImportReview.maxFiles { over.append(String(f.name.prefix(60))) }
                else { list.append(r); last = list.count - 1; seen.insert(sig) }
            case .fail(let t, let m): fails.append((String(f.name.prefix(60)), t, m))
            case .empty: empty.append(String(f.name.prefix(60)))
            }
        }
        if list.isEmpty {
            step = adding ? .review : origin
            if let f = fails.first, fails.count == 1 || empty.isEmpty { notice = Notice(title: f.title, message: f.message) }
            else if !empty.isEmpty {
                notice = Notice(title: empty.count == 1 ? Tr.t("Estado de cuenta sin movimientos") : Tr.f("{0} estados de cuenta sin movimientos", String(empty.count)),
                                message: String(empty.joined(separator: " · ").prefix(200)))
            } else { notice = Notice(title: Tr.t("Nazca no pudo leer esos archivos"), message: Tr.t("Revisa que sean los archivos que descargaste de tu banco.")) }
            return
        }
        reviews = list
        idx = adding && last >= 0 ? last : 0
        step = .review
        let bad = fails.count
        if bad == 0 && over.isEmpty && !empty.isEmpty {
            notice = Notice(title: empty.count == 1 ? Tr.t("Un archivo sin movimientos") : Tr.f("{0} archivos sin movimientos", String(empty.count)),
                            message: String(empty.joined(separator: " · ").prefix(220)))
        } else if !over.isEmpty {
            notice = Notice(title: Tr.t("Se revisan 3 archivos a la vez"), message: Tr.t("Los demás quedaron sin cargar. Importa o quita uno y usa «Cargar más»."))
        } else if bad > 0 {
            notice = Notice(title: bad == 1 ? Tr.t("Un archivo no se pudo leer") : Tr.f("{0} archivos no se pudieron leer", String(bad)),
                            message: String(fails.map { $0.name + ": " + $0.title }.joined(separator: " · ").prefix(300)))
        } else if !dupes.isEmpty {
            notice = Notice(title: dupes.count == 1 ? Tr.t("Un archivo ya estaba cargado") : Tr.f("{0} archivos ya estaban cargados", String(dupes.count)),
                            message: String(dupes.joined(separator: " · ").prefix(200)))
        }
    }

    @MainActor private func read(_ f: Picked) async -> Outcome {
        let isXlsx = f.name.lowercased().hasSuffix(".xlsx")
        guard let data = f.data else {
            return isXlsx ? .fail(Tr.t("El archivo es muy grande"), Tr.t("El máximo es 5 MB."))
                : .fail(Tr.t("El archivo es muy grande"), Tr.t("El máximo es 5 MB. Descarga un periodo más corto desde tu banca por internet."))
        }
        let head = String(data: data.prefix(5), encoding: .isoLatin1) ?? ""
        if head == "%PDF-" || f.name.lowercased().hasSuffix(".pdf") {
            return .fail(Tr.t("Nazca todavía no lee PDF en esta versión"), Tr.t("Por ahora puedes importar el CSV de tu banco."))
        }
        if head.hasPrefix("PK") || isXlsx { return await readExcel(f, data) }
        let parsed: Parsed? = await Task.detached(priority: .userInitiated) {
            guard let a = try? Nazca.analyze(Nazca.decode(data)) else { return nil }
            let x = Nazca.extract(a)
            return Parsed(analysis: a, items: x.items, unreadable: x.skipped.unreadable)
        }.value
        guard let parsed else {
            return .fail(Tr.t("Nazca no pudo leer ese archivo"), Tr.t("Revisa que sea el archivo CSV que descargaste de tu banca por internet."))
        }
        // un CSV con columnas propias de un banco que Nazca conoce se revisa igual que su estado de cuenta
        let a = parsed.analysis
        if let sig = Nazca.detectCsv(a.headers), !parsed.items.isEmpty {
            let items = parsed.items.enumerated().map { i, it in Nazca.Item(line: i + 1, date: it.date, desc: it.desc, amount: sig.flip ? -it.amount : it.amount, cur: it.cur) }
            var res = Nazca.StatementResult(bank: sig.bank, kind: sig.kind, label: sig.label, cur: sig.cur, items: items)
            res.unreadable = parsed.unreadable
            if let r = ImportReview(name: f.name, statement: res, engine: model.engine) { return .review(r) }
        }
        guard let r = ImportReview(name: f.name, analysis: a, engine: model.engine, preferredAccount: nil, guess: Self.nameGuess(f.name)) else {
            return .empty
        }
        return .review(r)
    }

    /// Excel (.xlsx): hoy el reporte de movimientos de Yape. Se abre en el dispositivo y se revisa igual que un estado de cuenta.
    @MainActor private func readExcel(_ f: Picked, _ data: Data) async -> Outcome {
        let rows: [[String]]? = await Task.detached(priority: .userInitiated) { try? NazcaXLSX.read(data) }.value
        guard let rows else {
            return .fail(Tr.t("Nazca no pudo leer ese archivo"), Tr.t("Revisa que sea el reporte de movimientos en Excel que descargaste."))
        }
        guard NazcaYape.detect(rows) else {
            return .fail(Tr.t(bank == "yape" ? "Este archivo no parece de Yape" : "Nazca todavía no reconoce este archivo"),
                         Tr.t("Por ahora Nazca lee el reporte de movimientos en Excel que descargas desde Yape. Revisa que sea ese archivo."))
        }
        guard let res = NazcaYape.read(rows) else {
            return .fail(Tr.t("Nazca no pudo leer el reporte"), Tr.t("No encontramos las columnas del reporte de movimientos de Yape."))
        }
        if res.items.isEmpty {
            return .fail(Tr.t("Nazca no encontró movimientos"), Tr.t("No hallamos movimientos en el archivo. Revisa que sea el reporte de movimientos de Yape."))
        }
        guard let r = ImportReview(name: f.name, statement: res, engine: model.engine) else { return .empty }
        return .review(r)
    }

    /// Un nombre legible a partir del archivo («estado_bcp_octubre.csv» → «estado bcp octubre»).
    static func nameGuess(_ file: String) -> String {
        var s = (file as NSString).deletingPathExtension
        s = s.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        s = s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return String(s.prefix(40))
    }
}

// MARK: - Piezas

private struct NoticeCard: View {
    let notice: ImportFlowView.Notice
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "questionmark.circle.fill").font(.system(size: 26)).foregroundStyle(Color(hex: "#8E8E93")).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.inter(17, .semibold))
                Text(notice.message).font(.inter(14)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct GoRow: View {
    let symbol: String
    let title: String
    let sub: String?
    var verbatimTitle = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Brand.accent).frame(width: 26)
                VStack(alignment: .leading, spacing: 0) {
                    if verbatimTitle { Text(verbatim: title).font(.inter(16)) } else { Text(title).font(.inter(16)) }
                    if let sub { Text(sub).font(.inter(13.5)).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HowStep: View {
    let n: Int
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(n)").font(.inter(13, .bold)).foregroundStyle(.white)
                .frame(width: 24, height: 24).background(Brand.accent, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.inter(17))
                Text(text).font(.inter(14)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

private struct DoneRow<Trailing: View>: View {
    let label: String
    let trailing: Trailing
    init(label: String, @ViewBuilder trailing: () -> Trailing) { self.label = label; self.trailing = trailing() }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.inter(17))
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 11)
    }
}

// MARK: - La revisión

struct ImportReviewBody: View {
    @Environment(AppModel.self) private var model
    @Binding var review: ImportReview
    let multi: Bool
    let onRemove: () -> Void

    @State private var filter = "all"
    @State private var filterOpen = false
    @State private var page = 0
    @State private var colsOpen = false
    @State private var rateText = ""
    @FocusState private var rateFocus: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let proj = review.projected(e)
        let credit = proj?.credit ?? false
        VStack(spacing: 0) {
            profileCard(e)
            footNote
            summary
            if let src = review.source { statementAccountCard(e, src) } else { accountCard(e) }
            if !review.foreignCurrency.isEmpty { fxCard(e, f) }
            balanceCard(e, f, proj, credit)
            if !review.isStatement { columnsCard }
            listSection(f)
            if review.analysis.truncated {
                Text("El archivo tiene más de 5000 filas: se leyeron las primeras 5000.")
                    .font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 10).padding(.bottom, 10)
            }
            if multi {
                Button(action: onRemove) {
                    Label("Quitar este archivo", systemImage: "trash").font(.inter(17)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: arriba

    private func profileCard(_ e: Engine) -> some View {
        let dates = review.rows.map(\.date).sorted()
        let span: String = {
            guard let a = dates.first.flatMap({ LocalDate(iso: $0) }), let b = dates.last.flatMap({ LocalDate(iso: $0) }) else { return "" }
            return Tr.t("Del " + Spanish.dateShort(a) + " al " + Spanish.dateShort(b))
        }()
        let src = review.source
        let bank = src?.bank
        let title: String = bank.map { Nazca.bankShort($0) } ?? ((src?.label).flatMap { $0.isEmpty ? nil : $0 } ?? (review.guess.isEmpty ? Tr.t("Archivo CSV") : review.guess))
        let ci = src?.cardInfo
        let due = ci?.dueDate.flatMap { LocalDate(iso: $0) }
        return SCard {
            HStack(spacing: 14) {
                Image(systemName: bank != nil ? "building.columns" : "doc.text").font(.system(size: 30)).foregroundStyle(Color.primary.opacity(0.46)).frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(verbatim: title).font(.inter(19, .bold))
                        if bank != nil {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 18)).foregroundStyle(Brand.accent)
                                .accessibilityLabel("Banco verificado")
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Label { Text(verbatim: Tr.t(Spanish.plural(review.rows.count, "movimiento", "movimientos"))) } icon: { Image(systemName: "arrow.left.arrow.right") }
                        if !span.isEmpty { Label { Text(verbatim: span) } icon: { Image(systemName: "calendar") } }
                        if let due {
                            Label { Text("Pagar antes del") + Text(verbatim: " " + Spanish.dateShort(due)) } icon: { Image(systemName: "calendar.badge.clock") }
                        }
                        if let apr = ci?.apr {
                            Label { Text(verbatim: Self.num(apr) + " %") + Text(" de tasa anual") } icon: { Image(systemName: "percent") }
                        }
                    }
                    .font(.inter(14.5)).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                    Text(verbatim: review.names.count > 1 ? review.names.joined(separator: " · ") : review.name)
                        .font(.inter(12.5)).foregroundStyle(.tertiary).lineLimit(2).truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            if let ck = src?.check, let ok = ck.ok { checkView(ck, ok) }
        }
    }

    private static func num(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(x) }

    /// «Cuadra con tu estado de cuenta»: Nazca comprobó que los movimientos suman los totales y el saldo final del banco.
    private func checkView(_ ck: Nazca.StatementResult.Check, _ ok: Bool) -> some View {
        let many = ck.n > 1
        let flagged = flaggedNames
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.shield" : "exclamationmark.triangle").font(.system(size: 22))
                .foregroundStyle(ok ? Brand.gainText : Brand.warnText).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                if ok {
                    Text(many ? "Cuadran los estados de cuenta" : "Cuadra con tu estado de cuenta").font(.inter(16, .semibold))
                    Text(many ? "Nazca comprobó que los movimientos de cada estado suman sus totales y su saldo final."
                         : "Nazca comprobó que los movimientos suman los totales y el saldo final de tu banco.").font(.inter(14)).foregroundStyle(.secondary)
                } else {
                    Text(many ? "No cuadra alguno de los estados de cuenta" : "No cuadra con tu estado de cuenta").font(.inter(16, .semibold))
                    Text(many ? "Nazca leyó los movimientos, pero en algún estado no suman los totales de tu banco. Revisa cada uno antes de importar."
                         : "Nazca leyó los movimientos, pero no suman los totales de tu banco. Revisa la lista antes de importar.").font(.inter(14)).foregroundStyle(.secondary)
                    if !flagged.bad.isEmpty { (Text("No cuadra:") + Text(verbatim: " " + flagged.bad)).font(.inter(14)).foregroundStyle(.secondary).padding(.top, 4) }
                    if !flagged.unread.isEmpty { (Text("Con filas sin leer:") + Text(verbatim: " " + flagged.unread)).font(.inter(14)).foregroundStyle(.secondary) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background((ok ? Brand.accent : Brand.warn).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 12)
    }

    /// Con varios archivos unidos, nombra cuáles no cuadran y cuáles tuvieron filas sin leer.
    private var flaggedNames: (bad: String, unread: String) {
        guard review.names.count > 1, let src = review.source else { return ("", "") }
        func pick(_ f: (Int) -> Bool) -> String { review.names.indices.filter(f).map { review.names[$0] }.joined(separator: ", ") }
        let bad = src.checks.count == review.names.count ? pick { src.checks[$0]?.ok == false } : ""
        let unr = review.unr.flatMap { $0.count == review.names.count ? $0 : nil }.map { u in pick { u[$0] > 0 } } ?? ""
        return (bad, unr)
    }

    private var footNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text").font(.system(size: 13)).padding(.top, 1)
            Text("Se leyó el archivo de forma local.")
            Spacer(minLength: 0)
        }
        .font(.inter(13)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 12)
    }

    @ViewBuilder private var summary: some View {
        let chips = summaryChips
        if !chips.isEmpty {
            FlowChips(items: chips).padding(.bottom, 12)
        }
    }

    private var summaryChips: [String] {
        var out: [String] = []
        func chip(_ n: Int, _ one: String, _ many: String) { if n > 0 { out.append(Tr.t(Spanish.plural(n, one, many))) } }
        chip(review.count(.exact) + review.count(.near), "repetido", "repetidos")
        chip(review.count(.cur) + review.count(.fxc) + review.count(.fxs), "de otra moneda", "de otra moneda")
        chip(review.count(.future), "con fecha futura", "con fecha futura")
        chip(review.unreadable, "fila no se pudo leer", "filas no se pudieron leer")
        chip(review.names.count > 1 ? review.names.count : 0, "archivo unido", "archivos unidos")
        chip(review.mdup, "fila repetida entre archivos omitida", "filas repetidas entre archivos omitidas")
        return out
    }

    // MARK: cuenta

    private func accountChoices(_ e: Engine) -> [(id: String, label: String)] {
        (e.allAccounts + e.allCards).map { (Engine.identifier($0["id"]), Engine.text($0["name"]) + ImportReview.l4($0)) }
    }

    private func accountCard(_ e: Engine) -> some View {
        let choices = accountChoices(e)
        let current = choices.first { $0.id == review.account }?.label ?? ""
        return SCard {
            HStack(spacing: 12) {
                Image(systemName: "creditcard").font(.system(size: 19)).foregroundStyle(Brand.gainText).frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Cuenta").font(.inter(13)).foregroundStyle(.secondary)
                    Menu {
                        ForEach(choices, id: \.id) { c in
                            Button { review.chooseAccount(c.id, engine: model.engine) } label: {
                                if c.id == review.account { Label { Text(verbatim: c.label) } icon: { Image(systemName: "checkmark") } } else { Text(verbatim: c.label) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: current).font(.inter(17)).foregroundStyle(.primary).lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            RowDivider()
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Invertir ingresos y gastos").font(.inter(17))
                    Text("Actívalo si en tu archivo los gastos aparecen como ingresos, y al revés.").font(.inter(14)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                Toggle("", isOn: Binding(get: { review.flip ?? false }, set: { review.setFlip($0, engine: model.engine) })).labelsHidden().tint(Brand.accent)
            }
            .padding(.vertical, 10)
        }
    }

    /// Para un estado de cuenta: crear la cuenta nueva o fusionar con una que ya existe.
    private func statementAccountCard(_ e: Engine, _ src: ImportReview.Source) -> some View {
        let isNew = review.account == ImportReview.newId
        let merge = review.mergeTarget(e)
        let accounts = e.allAccounts
        let cards = src.card ? e.allCards.filter { Engine.text($0["kind"]) == "card" } : []
        return SCard {
            Text("Cuenta").font(.inter(13)).foregroundStyle(.secondary).padding(.top, 10).padding(.bottom, 2)
            OptionRow(title: "Crear cuenta nueva", subVerbatim: Engine.text(src.newAcc["name"]) + ImportReview.l4(src.newAcc), on: isNew) {
                review.chooseAccount(ImportReview.newId, engine: model.engine)
            }
            if let merge {
                RowDivider()
                OptionRow(title: "Fusionar con otra cuenta", sub: "Suma estos movimientos a una que ya tienes.", on: !isNew) {
                    review.chooseAccount(merge, engine: model.engine)
                }
                if !isNew {
                    Picker("Cuenta", selection: Binding(get: { review.account }, set: { review.chooseAccount($0, engine: model.engine) })) {
                        Section("Débito") {
                            ForEach(Array(accounts.enumerated()), id: \.offset) { _, o in
                                Text(verbatim: Engine.text(o["name"]) + ImportReview.l4(o) + " · " + Engine.text(o["cur"])).tag(Engine.identifier(o["id"]))
                            }
                        }
                        if !cards.isEmpty {
                            Section("Crédito") {
                                ForEach(Array(cards.enumerated()), id: \.offset) { _, o in
                                    Text(verbatim: Engine.text(o["name"]) + ImportReview.l4(o) + " · " + Engine.text(o["cur"])).tag(Engine.identifier(o["id"]))
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 34).padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: otra moneda

    private func fxCard(_ e: Engine, _ f: Fmt) -> some View {
        let F = review.foreignCurrency
        let n = review.rows.filter { $0.cur == F }.count
        let accCur = review.accountCurrency(e)
        let splitOk = ImportReview.splitAllowed(F, e)
        let pool = review.fxPool(e)
        let mode = review.fxMode ?? .skip
        return SCard {
            (Text("Movimientos en otra moneda") + Text(verbatim: " (\(n) · \(f.symbol(F).trimmingCharacters(in: .whitespaces)))"))
                .font(.inter(13)).foregroundStyle(.secondary).padding(.top, 10).padding(.bottom, 2)
            OptionRow(title: "No importarlos", sub: "Se dejan fuera de la importación.", on: mode == .skip) { review.setFxMode(.skip, engine: model.engine) }
            RowDivider()
            OptionRow(title: "Convertirlos a la moneda de la cuenta", sub: "Se importan en la cuenta con un tipo de cambio.", on: mode == .convert) { review.setFxMode(.convert, engine: model.engine) }
            if mode == .convert {
                HStack(spacing: 8) {
                    Text(verbatim: "1 \(f.symbol(F).trimmingCharacters(in: .whitespaces)) =")
                    TextField("0", text: $rateText)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($rateFocus)
                        .frame(maxWidth: 110).textFieldStyle(.roundedBorder)
                        .onChange(of: rateText) { _, v in
                            if let r = Double(v.replacingOccurrences(of: ",", with: ".")), r > 0 { review.setFxRate(r, engine: model.engine) }
                        }
                    Text(verbatim: f.symbol(accCur).trimmingCharacters(in: .whitespaces))
                }
                .font(.inter(17)).padding(.leading, 34).padding(.bottom, 12)
                .onAppear { rateText = Self.trimmed(review.fxRate) }
            }
            RowDivider()
            OptionRow(title: "Mandarlos a una cuenta aparte",
                      sub: splitOk ? "Entran a una cuenta en esa moneda." : "Ya usas dos monedas en Plata; no se puede abrir otra.",
                      on: mode == .split, disabled: !splitOk) { review.setFxMode(.split, engine: model.engine) }
            if mode == .split {
                VStack(spacing: 0) {
                    OptionRow(title: "Crear cuenta nueva", sub: nil, on: review.fxAccount.isEmpty) { review.setFxAccount("", engine: model.engine) }
                    if !pool.isEmpty {
                        OptionRow(title: "Fusionar con otra cuenta", sub: "Suma estos movimientos a una que ya tienes.", on: !review.fxAccount.isEmpty) {
                            review.setFxAccount(Engine.identifier(pool[0]["id"]), engine: model.engine)
                        }
                        if !review.fxAccount.isEmpty {
                            Picker("Cuenta", selection: Binding(get: { review.fxAccount }, set: { review.setFxAccount($0, engine: model.engine) })) {
                                ForEach(Array(pool.enumerated()), id: \.offset) { _, o in
                                    Text(verbatim: Engine.text(o["name"]) + ImportReview.l4(o) + " · " + Engine.text(o["cur"])).tag(Engine.identifier(o["id"]))
                                }
                            }
                            .pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                        }
                    }
                    if F != e.primaryCurrency && F != e.secondaryCurrency {
                        Text("Se activará esa moneda como segunda moneda de Plata.").font(.inter(13)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).padding(.bottom, 8)
                    }
                }
                .padding(.leading, 34)
            }
        }
    }

    private static func trimmed(_ x: Double) -> String {
        var s = String(format: "%.4f", x)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: saldo

    private func balanceCard(_ e: Engine, _ f: Fmt, _ proj: (net: Double, before: Double, after: Double, cur: String, credit: Bool)?, _ credit: Bool) -> some View {
        let cur = proj?.cur ?? e.primaryCurrency
        let st = review.statement(e)
        let mode = review.balanceMode ?? .adjust
        return SCard {
            Text(credit ? "Deuda de la tarjeta" : "Saldo de la cuenta").font(.inter(13)).foregroundStyle(.secondary).padding(.top, 10).padding(.bottom, 2)
            OptionRow(title: credit ? "Sumar a la deuda" : "Sumar al saldo", subVerbatim: proj.map { f.exact($0.before, cur) + " → " + f.exact($0.after, cur) } ?? "",
                      on: mode == .adjust) { review.balanceMode = .adjust }
            RowDivider()
            OptionRow(title: credit ? "No cambiar la deuda" : "No cambiar el saldo",
                      sub: credit ? "Si tu deuda en Plata ya incluye estos movimientos." : "Si tu saldo en Plata ya incluye estos movimientos.",
                      on: mode == .keep) { review.balanceMode = .keep }
            if let st {
                RowDivider()
                OptionRow(title: "Usar el saldo del archivo",
                          subVerbatim: Tr.t(f.exact(st.balance, cur) + " al " + (LocalDate(iso: st.date).map { Spanish.dateShort($0) } ?? st.date)),
                          on: mode == .stmt) { review.balanceMode = .stmt }
            }
        }
    }

    // MARK: columnas

    private var columnsCard: some View {
        let hs = review.analysis.headers
        let ncol = max(review.analysis.width, hs.count)
        let cols = review.columns
        return DisclosureGroup(isExpanded: $colsOpen) {
            Text("Las detectamos solas. Cámbialas si algo no cuadra.").font(.inter(13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
            ForEach([("date", "Fecha"), ("desc", "Descripción"), ("amount", "Monto"), ("debit", "Cargo"), ("credit", "Abono")], id: \.0) { role, label in
                HStack {
                    Text(label).font(.inter(17))
                    Spacer(minLength: 10)
                    Picker(label, selection: Binding(get: { cols[role] }, set: { review.setColumn(role, $0, engine: model.engine) })) {
                        Text(verbatim: "—").tag(-1)
                        ForEach(0..<ncol, id: \.self) { j in
                            Text(verbatim: j < hs.count && !hs[j].isEmpty ? hs[j] : "#\(j + 1)").tag(j)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
                .padding(.vertical, 2)
            }
        } label: {
            Text("Columnas del archivo").font(.inter(17))
        }
        .tint(.secondary)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 6).padding(.bottom, 14)
    }

    // MARK: la lista

    private struct FilterDef { var key: String; var label: String; var verbatim: Bool; var test: (ImportReview.Row) -> Bool }

    private func filterDefs(_ e: Engine) -> [FilterDef] {
        let rows = review.rows
        var d = [FilterDef(key: "all", label: "Todos", verbatim: false, test: { _ in true })]
        if rows.contains(where: { $0.amount < 0 }) { d.append(FilterDef(key: "out", label: "Gastos", verbatim: false, test: { $0.amount < 0 })) }
        if rows.contains(where: { $0.amount > 0 }) { d.append(FilterDef(key: "in", label: "Ingresos", verbatim: false, test: { $0.amount > 0 })) }
        if rows.contains(where: { $0.why == .exact || $0.why == .near }) { d.append(FilterDef(key: "dup", label: "Repetidos", verbatim: false, test: { $0.why == .exact || $0.why == .near })) }
        for c in e.categoryNames where rows.contains(where: { $0.amount < 0 && $0.cat == c }) {
            d.append(FilterDef(key: "c:" + c, label: c, verbatim: true, test: { $0.amount < 0 && $0.cat == c }))
        }
        return d
    }

    private func listSection(_ f: Fmt) -> some View {
        let e = model.engine
        let defs = filterDefs(e)
        let cur = defs.first { $0.key == filter } ?? defs[0]
        let frows = review.rows.filter(cur.test).sorted { $0.date != $1.date ? $0.date < $1.date : $0.i < $1.i }
        let fon = frows.filter(\.on).count
        let fsel = frows.filter { $0.why != .future && $0.why != .cur }
        let pages = max(1, Int((Double(frows.count) / Double(ImportReview.perPage)).rounded(.up)))
        let p = min(max(page, 0), pages - 1)
        let shown = Array(frows.dropFirst(p * ImportReview.perPage).prefix(ImportReview.perPage))
        let names = e.categoryNames
        return VStack(spacing: 0) {
            if defs.count > 2 { filterBar(defs, cur, frows.count, fsel, fon) }
            if frows.isEmpty {
                Text("Con estas columnas no se lee ningún movimiento.").font(.inter(15)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(16)
            } else {
                SCard {
                    ForEach(Array(shown.enumerated()), id: \.element.i) { k, r in
                        if k > 0 { RowDivider() }
                        ImportRowView(row: r, names: names, fmt: f,
                                      onToggle: { review.toggle(r.i) },
                                      onCategory: { review.setCategory(r.i, $0) })
                    }
                }
            }
            if pages > 1 { pager(p, pages, frows.count) }
        }
    }

    private func filterBar(_ defs: [FilterDef], _ cur: FilterDef, _ count: Int, _ fsel: [ImportReview.Row], _ fon: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if cur.key != "all" {
                    (cur.verbatim ? Text(verbatim: cur.label) : Text(cur.label)) + Text(verbatim: " · \(count)")
                }
                Spacer(minLength: 0)
                Button { withAnimation(.easeOut(duration: 0.2)) { filterOpen.toggle() } } label: {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(cur.key != "all" ? Brand.accent : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                        .overlay(Circle().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filtrar")
            }
            .font(.inter(15, .semibold))
            if filterOpen {
                FlowLayout(spacing: 8) {
                    ForEach(defs, id: \.key) { d in
                        Button { filter = d.key; page = 0 } label: {
                            HStack(spacing: 6) {
                                (d.verbatim ? Text(verbatim: d.label) : Text(d.label))
                                Text(verbatim: "\(review.rows.filter(d.test).count)").foregroundStyle(.secondary)
                            }
                            .font(.inter(14.5, .medium))
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(d.key == cur.key ? Brand.accent.opacity(0.18) : Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if cur.key != "all" && !fsel.isEmpty {
                Button {
                    review.setOn(fsel.map(\.i), fon != fsel.count)
                } label: {
                    (Text(fon == fsel.count ? "Desmarcar estos" : "Marcar estos") + Text(verbatim: " (\(fsel.count))"))
                        .font(.inter(17)).foregroundStyle(Brand.green)
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func pager(_ p: Int, _ pages: Int, _ total: Int) -> some View {
        HStack(spacing: 16) {
            Button { page = max(0, p - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(p == 0).accessibilityLabel("Anterior")
            Text(verbatim: "\(p * ImportReview.perPage + 1)–\(min(total, (p + 1) * ImportReview.perPage)) / \(total)").font(.inter(14)).monospacedDigit()
            Button { page = min(pages - 1, p + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(p >= pages - 1).accessibilityLabel("Siguiente")
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }
}

/// Una opción con círculo de selección (`.imopt`).
private struct OptionRow: View {
    let title: String
    var sub: String? = nil
    var subVerbatim: String? = nil
    let on: Bool
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(on ? Brand.accent : Color(.tertiaryLabel), lineWidth: on ? 7 : 2)
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.inter(17))
                    if let sub { Text(sub).font(.inter(14)).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                    if let subVerbatim, !subVerbatim.isEmpty { Text(verbatim: subVerbatim).font(.inter(14)).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Una fila de la lista de movimientos leídos.
private struct ImportRowView: View {
    let row: ImportReview.Row
    let names: [String]
    let fmt: Fmt
    let onToggle: () -> Void
    let onCategory: (String) -> Void

    private var why: String {
        switch row.why {
        case .exact: return "Ya importado"
        case .near: return "Parece repetido"
        case .cur: return "Otra moneda"
        case .future: return "Fecha futura"
        case .fxc: return "Convertido"
        case .fxs: return "Otra cuenta"
        case .none: return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle().strokeBorder(row.on ? Brand.accent : Color(.tertiaryLabel), lineWidth: 2)
                    if row.on { Circle().fill(Brand.accent); Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 24, height: 24)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Importar este movimiento")
            .accessibilityAddTraits(row.on ? .isSelected : [])

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: row.desc.isEmpty ? "—" : row.desc).font(.inter(15, .semibold)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(LocalDate(iso: row.date).map { Spanish.dateShort($0) } ?? row.date)
                    if !why.isEmpty { Text(verbatim: "·"); Text(why).foregroundStyle(Brand.warnText).fontWeight(.semibold) }
                    if let o = row.orig { Text(verbatim: "· " + fmt.exact(abs(o.amount), o.cur)) }
                }
                .font(.inter(12.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: fmt.signed(row.amount, row.dc)).font(.inter(15, .semibold))
                    .foregroundStyle(row.amount > 0 ? Brand.gainText : Color.primary)
                if row.amount > 0 {
                    Text(verbatim: row.cat).font(.inter(12.5)).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Menu {
                        ForEach(names, id: \.self) { n in
                            Button { onCategory(n) } label: {
                                if n == row.cat { Label { Text(verbatim: n) } icon: { Image(systemName: "checkmark") } } else { Text(verbatim: n) }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(verbatim: row.cat).lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold))
                        }
                        .font(.inter(12.5)).foregroundStyle(.primary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(maxWidth: 140, alignment: .trailing)
                    }
                    .accessibilityLabel("Categoría")
                }
            }
        }
        .opacity(row.on ? 1 : 0.55)
        .padding(.vertical, 6)
    }
}

/// Fichas pequeñas que se acomodan en varias líneas (`.imsum`).
private struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 6, alignment: .center) {
            ForEach(items, id: \.self) { t in
                Text(verbatim: t).font(.inter(12.5, .semibold)).foregroundStyle(Brand.warnText)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Brand.warn.opacity(0.16), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Acomoda los hijos de izquierda a derecha y salta de línea cuando no caben.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        let rows = arrange(subviews, width: w)
        let h = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            if alignment == .center { x += (bounds.width - row.width) / 2 }
            for k in row.items {
                let s = subviews[k].sizeThatFits(.unspecified)
                subviews[k].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Line { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var lines: [Line] = [Line()]
        for k in subviews.indices {
            let s = subviews[k].sizeThatFits(.unspecified)
            let add = (lines[lines.count - 1].items.isEmpty ? 0 : spacing) + s.width
            if lines[lines.count - 1].width + add > width && !lines[lines.count - 1].items.isEmpty { lines.append(Line()) }
            let gap = lines[lines.count - 1].items.isEmpty ? 0 : spacing
            lines[lines.count - 1].items.append(k)
            lines[lines.count - 1].width += gap + s.width
            lines[lines.count - 1].height = max(lines[lines.count - 1].height, s.height)
        }
        return lines
    }
}
