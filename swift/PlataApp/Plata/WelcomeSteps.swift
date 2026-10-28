import SwiftUI
import PhotosUI
import PlataCore

// MARK: - Piezas de los formularios de la bienvenida

/// Campo con la etiqueta pequeña arriba (`.srow` con `.slabel` y `.sinput`).
struct WField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.inter(13)).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .font(.inter(17)).keyboardType(keyboard)
                .autocorrectionDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

/// Fecha con la etiqueta pequeña arriba; guarda el texto `AAAA-MM-DD`.
struct WDate: View {
    let label: String
    @Binding var iso: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.inter(13)).foregroundStyle(.secondary)
            DatePicker("", selection: Binding(
                get: { LocalDate(iso: iso)?.date() ?? Date() },
                set: { iso = LocalDate.today(now: $0).iso }
            ), displayedComponents: .date)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

/// Título y subtítulo de cada paso (`h1` de 32 pt y `.wsub`).
struct WTitle: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.inter(32, .bold)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
            if let sub { Text(sub).font(.inter(16)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8).padding(.bottom, 18)
    }
}

private func wSegmented<V: Hashable>(_ items: [(V, String)], _ sel: Binding<V>) -> some View {
    PillSegmented(items: items.map { ($0.0, ($0.1)) }, selection: sel).padding(.bottom, 12)
}

private let otherCurrencies: [String] = Currencies.table.keys.filter { !wCurGrid.contains($0) }.sorted()
let wCurGrid = ["USD", "EUR", "JPY", "GBP", "CAD", "BAM", "PEN", "MXN", "ARS", "BRL", "CLP", "COP", "UYU", "PYG", "BOB", "VES", "CRC", "GTQ", "HNL", "NIO", "DOP", "CUP"]
private let curSections: [(String, [String])] = [
    ("Américas", ["CAD", "PEN", "MXN", "ARS", "BRL", "CLP", "COP", "UYU", "PYG", "BOB", "VES", "CRC", "GTQ", "HNL", "NIO", "DOP", "CUP"]),
    ("Europa", ["GBP", "BAM"]), ("Asia", ["JPY"]),
]

// MARK: - Un paso

struct WelcomeStepView: View {
    let sid: String
    @Binding var w: WelcomeAnswers
    @AppStorage(Prefs.themeKey) private var theme = "auto"
    @State private var gradeSel = "B"
    @State private var customOpen = false
    @State private var fxText = ""
    @State private var pickItem: PhotosPickerItem?
    @State private var cropReq: PhotoRequest?
    @State private var photoImage: UIImage?

    struct PhotoRequest: Identifiable { let id = UUID(); let image: UIImage }

    private var sym: String { Money.symbol(w.accCur.isEmpty ? (w.cur.first ?? "USD") : w.accCur, custom: w.custom).trimmingCharacters(in: .whitespaces) }

    var body: some View {
        switch sid {
        case "name": name
        case "ins": insights
        case "cur": currency
        case "acc": account
        case "inc": income
        case "fixed": fixed
        case "budget": budget
        case "subs": subs
        case "debt": debt
        case "goal": goal
        case "look": look
        default: EmptyView()
        }
    }

    private func bind(_ kp: WritableKeyPath<WelcomeAnswers, String>) -> Binding<String> {
        Binding(get: { w[keyPath: kp] }, set: { w[keyPath: kp] = $0 })
    }

    // MARK: nombre

    private var name: some View {
        VStack(spacing: 0) {
            WTitle(title: "¿Cómo te llamas?", sub: "Opcional. Plata lo usará para saludarte; pero luego puedes cambiarlo en tu perfil.")
            photoBlock
            SCard {
                HStack(spacing: 0) {
                    WField(label: "Nombre", text: bind(\.first))
                    Divider().padding(.vertical, 6)
                    WField(label: "Apellido", text: bind(\.last)).padding(.leading, 14)
                }
                RowDivider()
                WField(label: "Apodo", text: bind(\.nick), placeholder: "Cómo quieres que te llamemos")
            }
            Text("Género (para dirigirnos a ti correctamente)").font(.inter(16)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12).padding(.bottom, 8)
            PillSegmented(items: [("m", "Masculino"), ("f", "Femenino"), ("n", "Neutro")], selection: bind(\.gender))
            Text(Spanish.genderExample(w.gender, nick: w.nick.isEmpty ? w.first : w.nick))
                .font(.inter(13)).italic().foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.top, 8)
        }
    }

    private var photoBlock: some View {
        VStack(spacing: 2) {
            PhotosPicker(selection: $pickItem, matching: .images) {
                Group {
                    if let img = photoImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(Color(.systemGray3))
                    }
                }
                .frame(width: 60, height: 60).clipShape(Circle())
            }
            HStack(spacing: 18) {
                PhotosPicker(selection: $pickItem, matching: .images) {
                    Text(photoImage == nil ? "Añadir foto (opcional)" : "Cambiar foto").font(.inter(15)).foregroundStyle(Brand.accent)
                }
                if photoImage != nil {
                    Button("Quitar") { photoImage = nil; w.photo = [:] }.font(.inter(15)).foregroundStyle(Brand.lossText)
                }
            }
            .frame(minHeight: 30)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 12)
        .onChange(of: pickItem) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    cropReq = PhotoRequest(image: PhotoCodec.fitted(img))
                }
                pickItem = nil
            }
        }
        .sheet(item: $cropReq) { req in
            CropEditor(image: req.image, crop: nil) { photo, crop in
                if let p = PhotoCodec.dataURL(photo, quality: 0.82), let s = PhotoCodec.dataURL(req.image, quality: 0.85) {
                    photoImage = photo
                    w.photo = ["photo": .string(p), "photoSrc": .string(s),
                               "photoCrop": .object(["x": .number(crop.x), "y": .number(crop.y), "z": .number(crop.z)])]
                }
            }
        }
    }

    // MARK: insights

    private var insights: some View {
        VStack(spacing: 0) {
            WTitle(title: "Insights y half‑time", sub: "Cada mes comparamos tus movimientos con los del anterior y te damos una evaluación de la F a la S, junto con consejos sobre tu presupuesto, tus metas de ahorro y tus deudas. Puedes cambiarlo después en Ajustes.")
            gradesCard
            SCard {
                SettingRow("Activar Insights y half‑time", first: true) {
                    Toggle("", isOn: $w.ins).labelsHidden().tint(Brand.accent)
                }
                SettingRow("Mostrar puntuación") {
                    Toggle("", isOn: Binding(get: { w.ins && w.score }, set: { w.score = $0 })).labelsHidden().tint(Brand.accent).disabled(!w.ins)
                }
            }
        }
    }

    private var gradesCard: some View {
        let list: [(String, String)] = [("S", "Perfecto"), ("A", "Muy bueno"), ("B", "Bueno"), ("C", "Mediocre"), ("D", "Deficiente"), ("F", "Muy malo")]
        let streak: String = ["S", "A"].contains(gradeSel) ? "Misma letra 2 meses seguidos y sube a letra+ dorada."
            : (["B", "C"].contains(gradeSel) ? "Misma letra 2 meses seguidos y sube a letra+ platino." : "Misma letra 2 meses seguidos y baja a letra- más roja.")
        return SCard {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 2) {
                    ForEach(list, id: \.0) { g in
                        Button { gradeSel = g.0 } label: {
                            VStack(spacing: 6) {
                                GradeTile(letter: g.0, size: 38).opacity(g.0 == gradeSel ? 1 : 0.55)
                                Text(g.1).font(.inter(11, .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                HStack(spacing: 12) {
                    GradeTile(letter: gradeSel, size: 38)
                    Text(streak).font(.inter(14)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack(spacing: 12) {
                    GradeTile(letter: "B", size: 38).opacity(0.4)
                    Text("Half‑time: el día 15 ves cómo va tu nota. Al cerrar el mes recibes la final.").font(.inter(14)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: moneda

    private func tapCurrency(_ c: String) {
        if let i = w.cur.firstIndex(of: c) {
            if w.cur.count > 1 { w.cur.remove(at: i) }
        } else if w.cur.count < 2 {
            w.cur.append(c)
        }
        w.fx = 0
        if !w.cur.contains(w.accCur) { w.accCur = w.cur.first ?? "USD" }
        syncFx()
    }

    private func syncFx() {
        if w.cur.count > 1 {
            if w.fx <= 0 { w.fx = Onboarding.fxDefault(w.cur[0], w.cur[1]) }
            fxText = Self.plain(w.fx)
        }
    }

    private static func plain(_ v: Double) -> String { v == v.rounded() ? String(Int64(v)) : String(v) }

    private func setCustom(_ raw: String) {
        let c = Onboarding.normCustom(raw)
        let old = w.custom
        if c == old { return }
        let i = w.cur.firstIndex(of: old)
        w.custom = c
        if !old.isEmpty, let i {
            if !c.isEmpty { w.cur[i] = c } else if w.cur.count > 1 { w.cur.remove(at: i) }
        }
        if old.isEmpty, !c.isEmpty, w.cur.count < 2, !w.cur.contains(c) { w.cur.append(c) }
        if w.accCur == old { w.accCur = w.cur.first ?? "USD" }
        w.fx = 0
    }

    private func ccyTile(_ c: String) -> some View {
        let i = w.cur.firstIndex(of: c)
        let one = w.cur.count < 2
        let disabled = i == nil && !one
        return Button { tapCurrency(c) } label: {
            VStack(spacing: 1) {
                Text(c).font(.inter(16, .bold))
                Text(Money.symbol(c, custom: w.custom).trimmingCharacters(in: .whitespaces)).font(.inter(13)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(i != nil ? Brand.accent : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if let i, w.cur.count > 1 {
                    Text("\(i + 1)").font(.inter(12, .bold)).foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20).background(Brand.accent, in: Circle()).offset(x: 4, y: -6)
                }
            }
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain).disabled(disabled)
    }

    private func ccySection(_ title: String, _ list: [String], extra: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.inter(13, .semibold)).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.top, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(list, id: \.self) { ccyTile($0) }
                if extra {
                    Button { customOpen.toggle() } label: {
                        VStack(spacing: 1) {
                            Text("+").font(.inter(16, .bold)); Text("Otros").font(.inter(13)).foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var currency: some View {
        let tz = Onboarding.currency(forTimeZone: TimeZone.current.identifier)
        var rec = ["USD", "EUR"]
        if let tz, !rec.contains(tz) { rec.append(tz) }
        var shown = rec
        var sections: [(String, [String])] = []
        for s in curSections {
            let l = s.1.filter { !shown.contains($0) }
            shown += l
            if !l.isEmpty { sections.append((s.0, l)) }
        }
        let others = w.cur.filter { !shown.contains($0) && !wCurGrid.contains($0) && $0 != w.custom } + (w.custom.isEmpty ? [] : [w.custom])
        let one = w.cur.count < 2
        return VStack(spacing: 0) {
            WTitle(title: "¿Qué moneda usas?", sub: "Elige hasta 2 monedas. Puedes cambiarlo después en Ajustes.")
            ccySection("Recomendado", rec)
            ForEach(sections, id: \.0) { ccySection($0.0, $0.1) }
            ccySection("Otros", others, extra: true)
            if customOpen || !w.custom.isEmpty { customCard }
            Text(one ? "Principal: \(Currencies.table[w.cur.first ?? "USD"]?.name ?? (w.cur.first ?? ""))."
                     : "Principal: \(w.cur[0]) · Segunda: \(w.cur[1])")
                .font(.inter(14)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.bottom, 12)
            if !one {
                SCard { WField(label: "1 \(w.cur[0]) en \(w.cur[1])", text: Binding(get: { fxText }, set: { fxText = $0; w.fx = Double($0.replacingOccurrences(of: ",", with: ".")) ?? w.fx }), keyboard: .decimalPad) }
                Button("Usar \(w.cur[1]) como principal") {
                    w.cur.reverse(); w.fx = w.fx > 0 ? Double(String(format: "%.4g", 1 / w.fx)) ?? 0 : 0
                    w.accCur = w.cur[0]; syncFx()
                }
                .buttonStyle(WGhostStyle()).padding(.top, 0)
            }
            if w.cur.contains("PEN") {
                Text("¡Que viva el Perú ca****!").font(.inter(13)).italic().foregroundStyle(.tertiary).padding(.top, 14)
            }
        }
        .onAppear { if w.cur.isEmpty { w.cur = ["USD"] }; syncFx() }
    }

    private var customCard: some View {
        SCard {
            VStack(alignment: .leading, spacing: 1) {
                Text("Otras monedas del mundo").font(.inter(13)).foregroundStyle(.secondary)
                Picker("Moneda", selection: Binding(get: { "" }, set: { if !$0.isEmpty { tapCurrency($0) } })) {
                    Text("Elige una moneda…").tag("")
                    ForEach(otherCurrencies, id: \.self) { Text("\($0) · \(Currencies.table[$0]?.name ?? "")").tag($0) }
                }
                .labelsHidden().tint(.primary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            RowDivider()
            WField(label: "¿No está? Escribe tu propio código (hasta 3 caracteres)",
                   text: Binding(get: { w.custom }, set: { setCustom($0) }))
        }
    }

    // MARK: cuenta

    private var account: some View {
        VStack(spacing: 0) {
            WTitle(title: "Tu primera cuenta", sub: "Donde guardas o recibes tu dinero. Podrás añadir más.")
            wSegmented([("checking", "Corriente"), ("savings", "Ahorros"), ("cash", "Efectivo")], bind(\.accType))
            if w.cur.count > 1 {
                wSegmented(w.cur.map { ($0, "\($0) (\(Money.symbol($0, custom: w.custom).trimmingCharacters(in: .whitespaces)))") }, Binding(get: { w.accCur.isEmpty ? w.cur[0] : w.accCur }, set: { w.accCur = $0 }))
            }
            SCard {
                WField(label: "Nombre", text: bind(\.accName))
                RowDivider()
                WField(label: "Saldo actual (\(sym))", text: bind(\.bal), placeholder: "0.00", keyboard: .decimalPad)
            }
        }
        .onAppear { if w.accCur.isEmpty || !w.cur.contains(w.accCur) { w.accCur = w.cur.first ?? "USD" } }
    }

    // MARK: ingresos

    private func qDays(_ a: Binding<String>, _ b: Binding<String>) -> some View {
        Group {
            RowDivider(); WField(label: "Día del primer pago", text: a, placeholder: "15", keyboard: .numberPad)
            RowDivider(); WField(label: "Día del segundo pago", text: b, placeholder: "30", keyboard: .numberPad)
        }
    }

    private var income: some View {
        VStack(spacing: 0) {
            WTitle(title: "¿Cuánto ganas?", sub: w.incKind == "j" ? "Opcional. Plata calcula tu pago neto y lo prevé en tus ingresos." : "Opcional. Así Plata prevé tus próximos ingresos.")
            wSegmented([("i", "Ingreso"), ("j", "Trabajo")], bind(\.incKind))
            if w.incKind == "j" { job } else { plainIncome }
        }
    }

    private var plainIncome: some View {
        VStack(spacing: 0) {
            wSegmented([("m", "Mensual"), ("q", "Quincenal"), ("14", "14 días"), ("7", "Semanal")], bind(\.incRep))
            SCard {
                WField(label: "Nombre", text: bind(\.incName))
                RowDivider()
                WField(label: "Monto (\(sym))", text: bind(\.incAmt), placeholder: "0.00", keyboard: .decimalPad)
                if w.incRep == "q" { qDays(bind(\.incQ1), bind(\.incQ2)) } else { RowDivider(); WDate(label: "Próxima fecha", iso: bind(\.incDate)) }
            }
        }
    }

    private var job: some View {
        let modes = Onboarding.jobModes(w.cur)
        let md = Onboarding.jobMode(w)
        let fq = w.jFreq.isEmpty ? (md == "s" ? "m" : "b") : w.jFreq
        return VStack(spacing: 0) {
            if modes.count > 1 { wSegmented(modes, Binding(get: { md }, set: { w.jMode = $0 })) }
            wSegmented([("w", "Semanal"), ("b", "14 días"), ("q", "Quincenal"), ("m", "Mensual")], Binding(get: { fq }, set: { w.jFreq = $0 }))
            SCard {
                WField(label: "Nombre del trabajo", text: bind(\.jName))
                RowDivider()
                WField(label: (md == "s" ? "Ingreso mensual estimado (" : "Pago por hora (") + sym + ")", text: bind(\.jRate), placeholder: "0.00", keyboard: .decimalPad)
                if md != "s" {
                    RowDivider(); WField(label: "Horas por semana", text: bind(\.jHours), placeholder: "40", keyboard: .decimalPad)
                    RowDivider(); WField(label: "Impuestos retenidos (%)", text: bind(\.jTax), placeholder: "15", keyboard: .decimalPad)
                }
                if fq == "q" { qDays(bind(\.jQ1), bind(\.jQ2)) } else { RowDivider(); WDate(label: "Primer pago", iso: bind(\.jDate)) }
            }
        }
    }

    // MARK: gastos fijos, presupuesto, suscripciones, deuda, meta

    private var fixed: some View {
        VStack(spacing: 0) {
            WTitle(title: "¿Tienes gastos fijos?", sub: "Renta, servicios… Opcional. Plata los suma a tu proyección; podrás añadir más.")
            wSegmented([("m", "Mensual"), ("q", "Quincenal"), ("14", "14 días"), ("7", "Semanal")], bind(\.fxRep))
            SCard {
                WField(label: "Nombre", text: bind(\.fxName))
                RowDivider()
                WField(label: "Monto (\(sym))", text: bind(\.fxAmt), placeholder: "0.00", keyboard: .decimalPad)
                if w.fxRep == "q" { qDays(bind(\.fxQ1), bind(\.fxQ2)) } else { RowDivider(); WDate(label: "Próximo pago", iso: bind(\.fxDate)) }
            }
        }
    }

    private var budget: some View {
        let cats = Onboarding.budgetCategories
        return VStack(spacing: 0) {
            WTitle(title: "Tu presupuesto", sub: "Cuánto quieres gastar al mes en cada categoría. Opcional; puedes dejarlo en blanco y definirlo después.")
            SCard {
                ForEach(Array(cats.enumerated()), id: \.offset) { i, c in
                    if i > 0 { RowDivider() }
                    WField(label: "\(c) (\(sym))", text: Binding(get: { w.bud[c] ?? "" }, set: { w.bud[c] = $0 }), placeholder: "0", keyboard: .decimalPad)
                }
            }
        }
    }

    private var subs: some View {
        VStack(spacing: 0) {
            WTitle(title: "Servicios y suscripciones", sub: "Netflix, Spotify, gimnasio… Opcional. Añade una ahora y las demás después.")
            SCard {
                WField(label: "Nombre", text: bind(\.subName))
                RowDivider()
                WField(label: "Monto por mes (\(sym))", text: bind(\.subAmt), placeholder: "0.00", keyboard: .decimalPad)
                RowDivider()
                WField(label: "Día de cobro", text: bind(\.subDay), keyboard: .numberPad)
            }
        }
    }

    private var debt: some View {
        VStack(spacing: 0) {
            WTitle(title: "Tarjetas y préstamos", sub: "Opcional. Añade una; Plata calcula intereses y cuándo quedarías libre de deuda.")
            wSegmented([("card", "Tarjeta"), ("loan", "Préstamo")], bind(\.dbKind))
            SCard {
                WField(label: "Nombre", text: bind(\.dbName))
                RowDivider()
                WField(label: "Saldo adeudado (\(sym))", text: bind(\.dbBal), placeholder: "0.00", keyboard: .decimalPad)
                if w.dbKind == "card" { RowDivider(); WField(label: "Límite de la tarjeta (\(sym))", text: bind(\.dbLim), placeholder: "0.00", keyboard: .decimalPad) }
                RowDivider()
                WField(label: "Interés anual (%)", text: bind(\.dbApr), placeholder: "20", keyboard: .decimalPad)
                RowDivider()
                WField(label: "Pago mensual (\(sym))", text: bind(\.dbPay), placeholder: "0.00", keyboard: .decimalPad)
                RowDivider()
                WField(label: "Día de pago", text: bind(\.dbDay), keyboard: .numberPad)
            }
        }
    }

    private var goal: some View {
        VStack(spacing: 0) {
            WTitle(title: "Una meta de ahorro", sub: "Opcional. Por ejemplo, un fondo de emergencias o un viaje.")
            SCard {
                WField(label: "Nombre", text: bind(\.gName))
                RowDivider()
                WField(label: "Meta (\(sym))", text: bind(\.gGoal), placeholder: "0.00", keyboard: .decimalPad)
                RowDivider()
                WField(label: "Aporte mensual (\(sym))", text: bind(\.gMon), placeholder: "0.00", keyboard: .decimalPad)
            }
        }
    }

    // MARK: apariencia

    private var look: some View {
        VStack(spacing: 0) {
            WTitle(title: "¿Cómo lo prefieres?", sub: "Elige la apariencia de Plata. Auto sigue la del sistema. Puedes cambiarla después en tu perfil.")
            PillSegmented(items: [("auto", "Auto"), ("light", "Claro"), ("dark", "Oscuro")], selection: $theme).padding(.top, 0)
            LookPreview()
        }
    }
}

struct WGhostStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(18, .semibold)).foregroundStyle(.primary)
            .frame(maxWidth: .infinity).frame(height: 54)
            .overlay(Capsule().stroke(Color.primary.opacity(0.28), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .padding(.top, 10)
    }
}

/// «Vista previa» del paso de apariencia (`lookPreviewHTML`): un perfil de demostración al azar.
struct LookPreview: View {
    @State private var info: (name: String, total: String, rows: [(String, String, String, Bool)])?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Vista previa").font(.inter(16)).foregroundStyle(.secondary).padding(.top, 22).padding(.bottom, 8)
            if let info {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: Tr.f("Hola, {0}", info.name)).font(.inter(22, .bold)).tracking(-0.4).padding(.horizontal, 2).padding(.bottom, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disponible").font(.inter(13)).foregroundStyle(.secondary)
                        Text(info.total).font(.inter(28, .bold)).tracking(-0.6).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(spacing: 0) {
                        ForEach(Array(info.rows.enumerated()), id: \.offset) { i, r in
                            if i > 0 { RowDivider() }
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(r.0).font(.inter(15)); Text(r.1).font(.inter(12)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(r.2).font(.inter(15, .bold)).foregroundStyle(r.3 ? Brand.gainText : Color.primary).monospacedDigit()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                HStack(alignment: .top, spacing: 8) {
                    Text("i").font(.inter(11, .bold)).foregroundStyle(.secondary).frame(width: 16, height: 16).overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                    Text("Este perfil está disponible como demostración también.").font(.inter(12)).foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            }
        }
        .task { if info == nil { info = Self.load() } }
    }

    private static func load() -> (name: String, total: String, rows: [(String, String, String, Bool)])? {
        guard let id = ["brenda", "shawn", "andrea"].randomElement(),
              let url = Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let prof = try? DemoProfile.load(data, today: LocalDate.today()) else { return nil }
        let e = Engine(profile: prof, today: LocalDate.today())
        let cur = e.primaryCurrency
        let f = Fmt(currency: cur, custom: e.customCurrency)
        let total = e.allAccounts.filter { Engine.text($0["cur"]) == cur && ["checking", "cash"].contains(Engine.text($0["type"])) }
            .reduce(0.0) { $0 + Engine.number($1["balance"]) }
        let todayIso = LocalDate.today().iso
        let tx = e.allTransactions.filter { Engine.text($0["date"]) <= todayIso }.suffix(3).reversed()
        let rows = tx.map { t -> (String, String, String, Bool) in
            let a = Engine.number(t["amount"])
            return (Engine.text(t["note"]), Engine.text(t["category"]), (a > 0 ? "+" : "") + f.exact(a), a > 0)
        }
        return (Engine.text(prof.settings["first"]), f.exact(total), rows)
    }
}
