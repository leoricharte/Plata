import SwiftUI
import PlataCore

/// Preferencias del dispositivo (la web las guarda en `localStorage`, no en el perfil): apariencia e idioma.
enum Prefs {
    static let themeKey = "plata.theme", langKey = "plata.lang"
    static let newsKey = "plata.news", newsId = "b4-461"
    static let fbKey = "plata.fb"
    static let formURL = URL(string: "https://forms.gle/FAt51YAz6k7JPQcC7")!
    static let changelogURL = URL(string: "https://github.com/leoricharte/Plata/blob/main/CHANGELOG.md#beta-4")!
    static let transparencyURL = URL(string: "https://plataapp.net/transparencia.html#analisis")!

    static func scheme(_ t: String) -> ColorScheme? { t == "light" ? .light : (t == "dark" ? .dark : nil) }
    static func locale(_ l: String) -> Locale { l == "auto" ? .autoupdatingCurrent : Locale(identifier: l) }

    static var newsSeen: Bool { UserDefaults.standard.string(forKey: newsKey) == newsId }
    static func markNewsSeen() { UserDefaults.standard.set(newsId, forKey: newsKey) }

    static func fb() -> [String: Double] { (UserDefaults.standard.dictionary(forKey: fbKey) as? [String: Double]) ?? [:] }
    static func fbSet(_ o: [String: Double]) {
        var cur = fb(); for (k, v) in o { cur[k] = v }
        UserDefaults.standard.set(cur, forKey: fbKey)
    }
}

// MARK: - Idioma · Apariencia · Tutorial

private let langChoices: [(String, String)] = [("auto", "Automático"), ("es", "Español"), ("en", "English")]

/// El nombre de un idioma: «Automático» se traduce; «Español» y «English» se muestran siempre en su propio idioma.
@ViewBuilder private func langName(_ code: String) -> some View {
    if code == "auto" { Text("Automático") } else { Text(verbatim: code == "es" ? "Español" : "English") }
}

/// Tarjeta «Idioma». En modo lectura es un valor; al editar, un selector.
struct LanguageCard: View {
    @AppStorage(Prefs.langKey) private var lang = "auto"
    var editable: Bool

    var body: some View {
        SCard {
            SettingRow("Idioma", first: true) {
                if editable {
                    Picker("Idioma", selection: $lang) {
                        ForEach(langChoices, id: \.0) { langName($0.0).tag($0.0) }
                    }
                    .labelsHidden().tint(.primary)
                } else {
                    langName(langChoices.contains { $0.0 == lang } ? lang : "auto").font(.inter(17)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Tarjeta «Apariencia» (Auto / Claro / Oscuro) de `themeCardHTML`.
struct ThemeCard: View {
    @AppStorage(Prefs.themeKey) private var theme = "auto"

    var body: some View {
        SCard {
            VStack(spacing: 10) {
                HStack { Text("Apariencia").font(.inter(17)); Spacer() }
                PillSegmented(items: [("auto", "Auto"), ("light", "Claro"), ("dark", "Oscuro")], selection: $theme)
            }
            .padding(.vertical, 12)
        }
    }
}

/// Tarjeta «Tutorial» con su nota (`settings.tour`).
struct TutorialCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let on = model.engine.data["settings"]?["tour"]?["on"] == .bool(true)
        SCard {
            SettingRow("Tutorial", first: true) {
                Toggle("", isOn: Binding(
                    get: { on },
                    set: { model.setSetting("tour", .object(["on": .bool($0), "seen": .object([:])])) }
                ))
                .labelsHidden().tint(Brand.accent)
            }
        }
        SettingsNote(text: "Muestra una guía breve la primera vez que tocas cada cosa.")
    }
}

// MARK: - Historia de Plata

private struct HistoryEntry: Identifiable {
    let id = UUID()
    let name: String, date: String, text: String, big: Bool
}

private let historyList: [HistoryEntry] = [
    .init(name: "Beta 4", date: "27 oct 2026", text: "Nazca lee tus estados de cuenta en tu dispositivo, Revisión con sugerencias en tarjetas y detección de recurrentes, historial de cada suscripción e infraestructura blindada.", big: true),
    .init(name: "Beta 3", date: "24 oct 2026", text: "Plata Cloud: sincronización cifrada entre tus dispositivos, por invitación y con el primer mes gratis. Además, notas y rachas con laureles, transferencias entre cuentas, logos automáticos de bancos y servicios, y avisos inteligentes.", big: true),
    .init(name: "Beta 2", date: "20 oct 2026", text: "Plata llega a tu mesa: versión de escritorio y Bentos, además del modo oscuro y nuevas secciones en la web.", big: true),
    .init(name: "Compilación 200", date: "20 oct 2026", text: "Aviso para abrir Plata en el navegador real si la abres desde Instagram u otras apps.", big: false),
    .init(name: "Beta 1 · Lanzamiento público", date: "19 oct 2026", text: "Plata sale a internet con su sitio en plataapp.net.", big: true),
    .init(name: "Compilación 1", date: "17 oct 2026", text: "La primera versión guardada de la app.", big: false),
]

struct HistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHead(title: "Historia de Plata", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: 6) {
                    Text("Lo más destacado, cada 50 compilaciones y en cada beta.")
                        .font(.inter(14)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 8).padding(.bottom, 4)
                    SCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(historyList) { h in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(h.big ? Brand.accent : Color.secondary.opacity(0.5)).frame(width: 10, height: 10).padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(h.name).font(.inter(16, .semibold))
                                        Text(h.date).font(.inter(13)).foregroundStyle(.secondary)
                                        Text(h.text).font(.inter(14)).padding(.top, 4)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.large])
    }
}

// MARK: - Novedades (historias de la Beta 4)

private struct NewsSlide {
    let image: String?, symbol: String, tag: String, title: String, text: String, note: String?
}

private let newsSlides: [NewsSlide] = [
    .init(image: "News_nazca", symbol: "chart.bar.doc.horizontal", tag: "NAZCA", title: "Nazca lee tus estados de cuenta", text: "Sube el PDF o el CSV de tu banco y Nazca lo lee en tu dispositivo, sin servidor. Antes de importar comprueba que los movimientos sumen el saldo del estado.", note: "Por ahora, algunos bancos de Perú y EE. UU."),
    .init(image: nil, symbol: "checkmark.shield", tag: "BLINDAJE", title: "Infraestructura blindada", text: "Reforzamos la seguridad de Plata: la app solo ejecuta su propio código, limpia todo lo que llega de un archivo o de la nube, y el servidor y el panel tienen pruebas de seguridad.", note: nil),
    .init(image: "News_revision", symbol: "doc.text.magnifyingglass", tag: "REVISIÓN", title: "Plata revisa por ti", text: "Encuentra transferencias entre tus cuentas, pagos de tarjeta, repetidos y montos raros, con reglas claras y sin IA. Tú aceptas o descartas cada tarjeta, nada cambia sin tu permiso y puedes deshacer.", note: nil),
    .init(image: "News_recurrentes", symbol: "repeat", tag: "RECURRENTES", title: "Detecta lo que se repite", text: "Reconoce tu sueldo, tus suscripciones y tus gastos fijos sumando todas tus cuentas, y los crea en un toque.", note: nil),
    .init(image: "News_historial", symbol: "clock.arrow.circlepath", tag: "HISTORIAL", title: "La historia de cada suscripción", text: "Mira cuándo empezó, cuándo subió de precio o cambió de cuenta, y si se saltó un mes o hubo un quiebre.", note: nil),
]

/// Historias a pantalla completa (`newsPopup`): barras de progreso de 6,5 s, toque a la izquierda retrocede, a la derecha avanza, mantener pausa.
struct NewsStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var cur = 0
    @State private var progress = 0.0
    @State private var holding = false
    @State private var pressStart: Date?
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    private let total = 6.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                ForEach(0..<newsSlides.count, id: \.self) { k in
                    slide(k, size: geo.size).opacity(k == cur ? 1 : 0).allowsHitTesting(false)
                }
                .animation(.easeInOut(duration: 0.28), value: cur)
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in if pressStart == nil { pressStart = Date(); holding = true } }
                        .onEnded { v in
                            holding = false
                            let quick = Date().timeIntervalSince(pressStart ?? Date()) < 0.35
                            pressStart = nil
                            guard quick else { return }
                            go(v.location.x < geo.size.width * 0.32 ? cur - 1 : cur + 1)
                        })
                VStack(spacing: 0) {
                    bars.padding(.horizontal, 16).padding(.top, 12)
                    HStack {
                        BetaPill(label: "B E T A  4").environment(\.colorScheme, .dark)
                            .background(.white.opacity(0.2), in: Capsule())
                        Spacer()
                        Button { close() } label: {
                            Image(systemName: "xmark").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Cerrar")
                    }
                    .padding(.leading, 16).padding(.trailing, 4).padding(.top, 4)
                    Spacer()
                    if cur == newsSlides.count - 1 { ending.padding(.horizontal, 28).padding(.bottom, 30) }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(tick) { _ in
            guard !holding else { return }
            progress += (1.0 / 30.0) / total
            if progress >= 1 {
                if cur < newsSlides.count - 1 { cur += 1; progress = 0 } else { progress = 1 }
            }
        }
        .onDisappear { Prefs.markNewsSeen() }
        .interactiveDismissDisabled(false)
    }

    private func go(_ k: Int) {
        guard k >= 0, k < newsSlides.count else { if k < 0 { progress = 0 }; return }
        cur = k; progress = 0
    }

    private func close() { Prefs.markNewsSeen(); dismiss() }

    private var background: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#21AF72"), Color(hex: "#219772"), Color(hex: "#21806F"), Color(hex: "#217D6F")],
                           center: UnitPoint(x: 0.45, y: 0.58), startRadius: 0, endRadius: 520)
            LinearGradient(colors: [Color(red: 32/255, green: 105/255, blue: 108/255).opacity(0.9), Color(red: 32/255, green: 105/255, blue: 108/255).opacity(0)],
                           startPoint: UnitPoint(x: 0.9, y: 0), endPoint: UnitPoint(x: 0.3, y: 0.46))
            Image("News_bg").resizable(resizingMode: .tile)
        }
        .ignoresSafeArea()
    }

    private var bars: some View {
        HStack(spacing: 5) {
            ForEach(0..<newsSlides.count, id: \.self) { q in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(.white).frame(width: g.size.width * (q < cur ? 1 : (q == cur ? progress : 0)))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func slide(_ k: Int, size: CGSize) -> some View {
        let s = newsSlides[k]
        let small = size.height < 760
        let head = VStack(alignment: .leading, spacing: 0) {
            Text(s.tag).font(.inter(12, .bold)).tracking(3.1).foregroundStyle(.white.opacity(0.72)).lineLimit(1).padding(.bottom, 10)
            Text(s.title).font(.inter(small ? 30 : 36, .bold)).tracking(-1.2).lineSpacing(-2).foregroundStyle(.white)
                .lineLimit(3).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        let body = VStack(alignment: .leading, spacing: 0) {
            Text(s.text).font(.inter(small ? 16 : 18)).lineSpacing(3).foregroundStyle(.white.opacity(0.93))
                .fixedSize(horizontal: false, vertical: true)
            if let n = s.note { Text(n).font(.inter(12.5)).foregroundStyle(.white.opacity(0.68)).padding(.top, 10) }
            if k == newsSlides.count - 1 { Color.clear.frame(height: 22 + 54 + 14 + 20) }   // sitio para «Aceptar» y el enlace
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tres bandas que nunca se pisan: titular, dibujo (usa el espacio que sobra) y texto; en las historias impares se invierten.
        return VStack(spacing: 18) {
            if k % 2 == 0 { head } else { body }
            GeometryReader { g in art(s, slot: g.size, screen: size).frame(width: g.size.width, height: g.size.height) }
                .frame(maxHeight: .infinity)
            if k % 2 == 0 { body } else { head }
        }
        .padding(.top, 78).padding(.horizontal, 28).padding(.bottom, 30)
    }

    @ViewBuilder
    private func art(_ s: NewsSlide, slot: CGSize, screen: CGSize) -> some View {
        if let img = s.image {
            let h = max(120, min(360, slot.height)), w = min(min(310, screen.width * 0.8), h * 310 / 360)
            Image(img).resizable().scaledToFill()
                .frame(width: w, height: h, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1.5))
                .shadow(color: Color(red: 0, green: 40/255, blue: 25/255).opacity(0.65), radius: 27, y: 26)
                .frame(width: slot.width, height: slot.height)
        } else {
            let side: CGFloat = min(slot.height - 10, screen.height < 760 ? 110 : 150)
            RoundedRectangle(cornerRadius: 44, style: .continuous).fill(.white.opacity(0.14))
                .frame(width: max(60, side), height: max(60, side))
                .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1.5))
                .overlay(Image(systemName: s.symbol).font(.system(size: max(60, side) * 0.56, weight: .regular)).foregroundStyle(.white))
                .shadow(color: Color(red: 0, green: 50/255, blue: 30/255).opacity(0.55), radius: 25, y: 24)
                .frame(width: slot.width, height: slot.height)
        }
    }

    private var ending: some View {
        VStack(spacing: 14) {
            Button { close() } label: {
                Text("Aceptar").font(.inter(17, .bold)).foregroundStyle(Color(hex: "#0E7A4D"))
                    .frame(maxWidth: .infinity).frame(height: 54).background(.white, in: Capsule())
            }
            Button { openURL(Prefs.changelogURL) } label: {
                Text("Revisar novedades").font(.inter(15, .semibold)).foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(.top, 22)
    }
}

// MARK: - Opinión

extension View {
    /// «¿Nos cuentas cómo te va con Plata?» (`feedbackPopup`). `manual`: abierto desde Ajustes (solo «Cerrar»).
    func feedbackAlert(isPresented: Binding<Bool>, manual: Bool) -> some View {
        modifier(FeedbackAlert(isPresented: isPresented, manual: manual))
    }
}

private struct FeedbackAlert: ViewModifier {
    @Binding var isPresented: Bool
    let manual: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("¿Nos cuentas cómo te va con Plata?", isPresented: $isPresented) {
            Button("Continuar al formulario") { Prefs.fbSet(["done": 1]); openURL(Prefs.formURL) }
            if manual {
                Button("Cerrar", role: .cancel) {}
            } else {
                Button("Más tarde") { Prefs.fbSet(["snooze": Date().timeIntervalSince1970 + 5 * 86400]) }
                Button("No, gracias", role: .cancel) { Prefs.fbSet(["done": 1]) }
            }
        } message: {
            Text("Tu opinión nos ayuda a mejorarla. Son unos 3 minutos.\n\nAl continuar, aceptas que la información que envíes en el formulario sí se recopila y autorizas a Estudio 22 y a Plata a usarla para mejorar la app.\n\nEste botón lleva a Google Forms.")
        }
    }
}

/// Cuándo mostrar solos los avisos (`maybeNews` / `maybeFeedback`).
@MainActor
enum Nudges {
    private static var feedbackChecked = false

    static func shouldShowNews(_ model: AppModel) -> Bool { !Prefs.newsSeen && hasData(model) }

    static func shouldShowFeedback(_ model: AppModel) -> Bool {
        guard !feedbackChecked, hasData(model), Prefs.newsSeen else { return false }
        feedbackChecked = true
        let now = Date().timeIntervalSince1970
        let f = Prefs.fb()
        guard let t0 = f["t0"] else { Prefs.fbSet(["t0": now, "n": 1]); return false }
        let n = (f["n"] ?? 0) + 1
        Prefs.fbSet(["n": n])
        if f["done"] == 1 || (f["snooze"] ?? 0) > now { return false }
        return !(now - t0 < 3 * 86400 || n < 5)
    }

    private static func hasData(_ model: AppModel) -> Bool {
        let d = model.engine.data
        let keys = ["transactions", "cards", "savings", "subs", "expected_income", "expected_expense", "planned"]
        if keys.contains(where: { (d[$0]?.arrayValue ?? []).count > 0 }) { return true }
        return (d["budget"]?.objectValue ?? [:]).count > 0
    }
}

// MARK: - Créditos

/// «Créditos» (`creditsHTML`): equipo, recursos, testers y la versión (toca para abrir la Historia de Plata).
struct CreditsView: View {
    @Environment(AppModel.self) private var model
    private let alpha = ["Rodrigo Espinoza", "Mariana Richarte", "Jeny Surichaqui", "Carlos Flores"]
    private let beta = ["Bastián Guajardo", "Sara Rondón"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PageHead(eyebrow: "Plata", title: "Créditos")
                ListCard {
                    role("Leonardo Richarte", "Director creativo, diseño de UI y concepto")
                    RowDivider()
                    role("Claude", "Programación")
                }
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary).opacity(0.7)
                    Text("El uso de IA fue limitado a la programación de la aplicación.").font(.inter(13)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 8)

                SectionHead("Recursos")
                ListCard { role("Remix Icon", "Biblioteca principal de íconos de Plata · remixicon.com") }
                SectionHead("Testers de la alpha")
                testers(alpha)
                SectionHead("Testers de la beta")
                testers(beta)

                Button { model.showHistory = true } label: {
                    VStack(spacing: 2) {
                        Text("Plata · Beta 4")
                        Text("Compilación 464")
                        Text("Móvil")
                    }
                    .font(.inter(13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.top, 22).padding(.bottom, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func role(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.inter(17))
            Text(detail).font(.inter(14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
    }

    private func testers(_ list: [String]) -> some View {
        ListCard {
            if list.isEmpty {
                Text("Pronto").font(.inter(17)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(Array(list.enumerated()), id: \.offset) { i, n in
                    if i > 0 { RowDivider() }
                    Text(n).font(.inter(17)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                }
            }
        }
    }
}
