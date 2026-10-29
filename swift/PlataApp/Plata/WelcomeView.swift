import SwiftUI
import UniformTypeIdentifiers
import PlataCore

/// Dónde se recuerda que ya viste la bienvenida (`finanzas.welcomed` en la web).
enum Welcome {
    static let key = "plata.welcomed"
    static var seen: Bool { UserDefaults.standard.bool(forKey: key) }
    static func mark(_ v: Bool) { UserDefaults.standard.set(v, forKey: key) }
}

/// Bienvenida: portada → (nivel → pasos) → «Tus datos son tuyos» → perfil nuevo (`welcomeHTML` de la web).
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(CloudModel.self) private var cloud

    private enum Page: Equatable { case landing, demo, level, step, privacy, protect }

    @State private var page: Page = .landing
    @State private var w = WelcomeAnswers()
    @State private var step = 0
    @State private var backwards = false
    @State private var onAccept: (() -> Void)?
    @State private var privacyDemo = false
    @State private var importing = false
    @State private var errorText: String?
    @State private var cloudCard = false
    @State private var cloudMode = false
    @State private var checkingCloud = false

    private var steps: [String] { Onboarding.steps(level: w.level) }
    private var key: String { page == .step ? "step-\(step)" : "\(page)" }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                content
                    .id(key)
                    .transition(.asymmetric(
                        insertion: .move(edge: backwards ? .leading : .trailing),
                        removal: .move(edge: backwards ? .trailing : .leading)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .plataBackground()
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { errorText = "No se pudo leer el archivo."; return }
            do { try model.importProfile(data); close() }
            catch MigrationError.legacyFormat { errorText = "Este archivo es de una versión muy antigua de Plata y no se puede abrir aquí." }
            catch { errorText = "Este archivo no parece un perfil de Plata." }
        }
        .sheet(isPresented: $cloudCard) {
            WelcomeCloudCard {
                cloudCard = false
                Task { try? await Task.sleep(for: .milliseconds(350)); cloud.openFlow(.email) }
            } later: { cloudCard = false }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: Binding(get: { cloud.flow != nil }, set: { if !$0 { cloud.flow = nil } })) { CloudFlowHost().interactiveDismissDisabled() }
        .alert("No se pudo abrir", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(errorText ?? "") }
    }

    // MARK: navegación

    private func go(_ p: Page, back: Bool = false) {
        backwards = back
        withAnimation(.easeInOut(duration: 0.4)) { page = p }
    }

    private func goStep(_ n: Int, back: Bool) {
        backwards = back
        withAnimation(.easeInOut(duration: 0.4)) { step = n; page = .step }
    }

    private func goBack() {
        switch page {
        case .demo, .level: go(.landing, back: true)
        case .step: if step > 0 { goStep(step - 1, back: true) } else { go(.level, back: true) }
        default: break
        }
    }

    private func close() {
        Welcome.mark(true)
        Prefs.markNewsSeen()
        withAnimation(.easeOut(duration: 0.35)) { model.showWelcome = false }
    }

    private func askPrivacy(demo: Bool = false, then: @escaping () -> Void) {
        privacyDemo = demo; onAccept = then; go(.privacy)
    }

    // MARK: barra superior

    private var topBar: some View {
        HStack {
            if page == .demo || page == .level || page == .step {
                Button { goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Regresar")
            } else { Color.clear.frame(width: 44, height: 44) }
            Spacer()
            if page == .step {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle().fill(i == step ? Color.primary : Color.primary.opacity(0.18)).frame(width: 7, height: 7)
                    }
                }
            }
            Spacer()
            if cloudMode && (page == .level || page == .step) {
                HStack(spacing: 5) {
                    Image(systemName: "cloud").font(.system(size: 12, weight: .semibold))
                    Text("Plata Cloud").font(.inter(13, .semibold))
                }
                .foregroundStyle(Brand.gainText)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Brand.accent.opacity(0.15), in: Capsule())
                .fixedSize()
            } else { Color.clear.frame(width: 44, height: 44) }
        }
        .frame(minHeight: 44)
    }

    // MARK: páginas

    @ViewBuilder
    private var content: some View {
        switch page {
        case .landing: landing
        case .demo: demo
        case .level: level
        case .step: stepPage
        case .privacy: privacy
        case .protect: ProtectStep { let f = onAccept; onAccept = nil; f?() }
        }
    }

    private var landing: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("PlataLogo").resizable().scaledToFit().frame(width: 210).accessibilityLabel("Plata")
            Text("Finanzas simples. Tu plata a tu modo.").font(.inter(17)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 16)
            Spacer()
            Text("Beta 4 · 464").font(.inter(13, .medium)).foregroundStyle(.secondary).padding(.bottom, 12)
            HStack(spacing: 10) {
                Button("Empezar") { cloudMode = false; w = WelcomeAnswers(); w.cur = Onboarding.guessCurrencies(timeZone: TimeZone.current.identifier, region: Locale.current.region?.identifier ?? ""); go(.level) }
                    .buttonStyle(PrimaryPillStyle())
                Menu {
                    Button { quick() } label: { Label("Inicio rápido", systemImage: "flashlight.on.fill") }
                    Button { go(.demo) } label: { Label("Datos de demostración", systemImage: "chart.bar") }
                    Button { importing = true } label: { Label("Cargar archivo de perfil", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 22, weight: .bold)).foregroundStyle(Color(hex: "#1C1C1E"))
                        .frame(width: 54, height: 54)
                        .plataGlass(in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
                .accessibilityLabel("Más opciones")
            }
            Button { startCloud() } label: {
                HStack(spacing: 8) {
                    CloudMark(kind: .cloud, height: 22).foregroundStyle(Brand.accent)
                    Text(checkingCloud ? "Revisando tu nube…" : "Empezar en la nube").font(.inter(18, .semibold))
                }
                .foregroundStyle(Color(hex: "#1C1C1E"))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(checkingCloud)
            .padding(.top, 10)
        }
    }

    /// `wcloudGo`: con sesión y sin datos aquí, carga tu nube o inicia el recorrido en modo nube; si no, muestra la tarjeta de Plata Cloud.
    private func startCloud() {
        guard cloud.isIn, !model.profile.hasData else { cloudCard = true; return }
        checkingCloud = true
        Task {
            await cloud.sync(.first)
            checkingCloud = false
            if model.showWelcome && !model.profile.hasData {
                w = WelcomeAnswers(); w.cur = Onboarding.guessCurrencies(timeZone: TimeZone.current.identifier, region: Locale.current.region?.identifier ?? "")
                cloudMode = true; go(.level)
            }
        }
    }

    private func quick() {
        let cur = Onboarding.guessCurrencies(timeZone: TimeZone.current.identifier, region: Locale.current.region?.identifier ?? "")
        askPrivacy {
            let raw = Onboarding.quick(currencies: cur)
            if let data = try? Profile(raw: raw).jsonData() { try? model.importProfile(data) }
            model.tab = .resumen
            close()
        }
    }

    private var demo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WTitle(title: "Perfiles de demostración", sub: "Elige uno para ver Plata con datos de ejemplo.")
                VStack(spacing: 10) {
                    ForEach(DemoPerson.all) { p in
                        Button {
                            askPrivacy(demo: true) {
                                do { try model.loadDemo(p.id) } catch { model.errorMessage = error.localizedDescription }
                                model.tab = .resumen
                                close()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Tile(symbol: p.symbol, color: Color(hex: p.color))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.inter(17, .semibold))
                                    Text(p.city).font(.inter(13)).foregroundStyle(.secondary)
                                    Text(p.line).font(.inter(14)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.primary)
                            .padding(16)
                            .plataGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Estos perfiles se crearon con estadísticas de ejemplo. Los datos no son reales.")
                    .font(.inter(12)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 18)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var level: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WTitle(title: "¿Cómo quieres empezar?", sub: "Elige cuánto quieres configurar ahora. Lo demás puedes añadirlo después.")
                levelRow("simple", "Simple", "Lo esencial: tu nombre, moneda y una cuenta. Registra ingresos y gastos y listo.", "1 min", false, "leaf", "#22B573")
                levelRow("standard", "Estándar", "Además: Insights y half‑time, tus ingresos y límites de presupuesto.", "3 min", true, "square.grid.2x2", "#22B573")
                levelRow("extended", "Extendido", "Todo desde el inicio: gastos fijos, suscripciones, deudas y una meta de ahorro.", "6 min", false, "paperplane", "#B98AE6")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func levelRow(_ k: String, _ title: String, _ detail: String, _ mins: String, _ rec: Bool, _ symbol: String, _ color: String) -> some View {
        Button {
            let cur = w.cur
            w = WelcomeAnswers(); w.cur = cur
            w.level = k
            if k == "simple" { w.ins = false; w.score = false }
            w.incDate = LocalDate.today().iso; w.jDate = w.incDate; w.fxDate = w.incDate
            step = 0
            goStep(0, back: false)
        } label: {
            HStack(spacing: 12) {
                Tile(symbol: symbol, color: Color(hex: color))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(title).font(.inter(17, .semibold))
                        if rec {
                            Text("Recomendado").font(.inter(12, .semibold)).foregroundStyle(Brand.gainText)
                                .padding(.horizontal, 10).padding(.vertical, 4).background(Brand.accent.opacity(0.16), in: Capsule())
                        }
                    }
                    Text(detail).font(.inter(14)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Text(mins).font(.inter(13)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .plataGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }

    private var stepPage: some View {
        let sid = step < steps.count ? steps[step] : ""
        let last = step == steps.count - 1
        let optional = Onboarding.optionalSteps.contains(sid)
        return VStack(spacing: 0) {
            ScrollView {
                WelcomeStepView(sid: sid, w: $w).padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            if sid == "ins" {
                Text("Esta información no es recopilada por Plata ni Estudio 22. Toda la información se maneja en tu archivo de perfil.")
                    .font(.inter(12)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 10).padding(.bottom, 12)
            }
            Button(last ? "Terminar" : "Continuar") { advance(skip: false, sid: sid, last: last) }
                .buttonStyle(PrimaryPillStyle())
            if optional {
                Button("Omitir") { advance(skip: true, sid: sid, last: last) }.buttonStyle(WGhostStyle())
            }
        }
    }

    private func advance(skip: Bool, sid: String, last: Bool) {
        if skip { w.clear(step: sid) }
        if last { finish() } else { goStep(step + 1, back: false) }
    }

    private func finish() {
        var answers = w
        if answers.accCur.isEmpty || !answers.cur.contains(answers.accCur) { answers.accCur = answers.cur.first ?? "USD" }
        let today = LocalDate.today()
        let raw = Onboarding.build(answers, today: today) { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased() }
        askPrivacy {
            if let data = try? Profile(raw: raw).jsonData() { try? model.importProfile(data) }
            model.tab = .resumen
            close()
        }
    }

    // MARK: «Tus datos son tuyos»

    private var privacy: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "lock.square.dashed").font(.system(size: 54, weight: .light)).foregroundStyle(Color(hex: "#3A3A3C")).padding(.top, 36).padding(.bottom, 20)
                    Text("Tus datos son tuyos.").font(.inter(32, .bold)).tracking(-0.8)
                    block("#22B573", "iphone", "Tus datos se almacenan localmente en tu teléfono.", "Estudio 22 y Plata no recopilan tus datos financieros.")
                    block("#8E8E93", "gearshape", "Respalda tus datos", "Aunque por el momento cerrar y abrir la app mantiene tus datos, haz siempre una copia desde Ajustes para mantenerla al día y segura.")
                    block("#6E6E73", "arrow.left.arrow.right", "Solo se sincroniza con Plata Cloud", "Para usar Plata en otro dispositivo, guarda tu archivo y cárgalo allí, o prueba Plata Cloud (opcional, por invitación).")
                    if privacyDemo {
                        Text("Los perfiles de demostración fueron creados usando estadísticas y no representan uso real de ningún usuario.")
                            .font(.inter(12)).foregroundStyle(.secondary).padding(.top, 22)
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            Text("Plata está en una versión Beta. Plata Cloud, la sincronización opcional, es por invitación.")
                .font(.inter(12)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 14).padding(.bottom, 12)
            Button("Aceptar") {
                if AppLock.shared.hasPIN { let f = onAccept; onAccept = nil; f?() } else { go(.protect) }
            }.buttonStyle(PrimaryPillStyle())
        }
    }

    private func block(_ color: String, _ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Tile(symbol: symbol, color: Color(hex: color))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.inter(17, .semibold)).tracking(-0.3).fixedSize(horizontal: false, vertical: true)
                Text(text).font(.inter(15)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 22)
    }
}


/// La tarjeta de «Empezar en la nube» (`wclHTML` de la web).
struct WelcomeCloudCard: View {
    var enter: () -> Void
    var later: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CloudMark(kind: .logo, height: 34).padding(.top, 8)
                Text("Tus datos, en todos tus dispositivos").font(.inter(24, .bold)).padding(.top, 14)
                Text("Plata Cloud sincroniza tu información entre tu teléfono y tu computadora, sin dejar de ser tuya.")
                    .font(.inter(16)).foregroundStyle(.secondary).padding(.top, 6)
                VStack(alignment: .leading, spacing: 12) {
                    item("1", "Cifrado de extremo a extremo: solo tú puedes leer tus datos.")
                    item("2", "Sin contraseñas: entras con un código que te llega al correo.")
                    item("3", "Marcha blanca gratuita de un mes, por invitación. Si aún no tienes, entras a la lista de espera.")
                }
                .padding(.top, 16)
                CloudPriceLine().frame(maxWidth: .infinity).padding(.top, 8)
                Button("Crear cuenta o entrar", action: enter).buttonStyle(CloudButtonStyle()).padding(.top, 12)
                Button("Ahora no", action: later).buttonStyle(CloudButtonStyle(kind: .alt)).padding(.top, 8)
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .plataBackground()
    }

    private func item(_ n: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: n).font(.inter(13, .bold)).foregroundStyle(Brand.gainText)
                .frame(width: 22, height: 22).background(Brand.accent.opacity(0.15), in: Circle())
            Text(t).font(.inter(15)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
