import SwiftUI
import PlataCore

// Las piezas de Plata Cloud que se ven fuera de la pantalla de entrada: el logo, la tarjeta del perfil, la franja del Resumen y la solicitud de otro dispositivo.

/// El logo y las nubes de Plata Cloud (`PC_LOGO` / `PC_CLOUDS` de la web). El verde es fijo; la «k» y el texto siguen el color del texto.
enum CloudMarks {
    struct Piece { let path: Path; let green: Bool }
    struct Mark { let vb: CGRect; let pieces: [Piece] }
    private struct RawShape: Decodable { let k: String; let d: String }
    private struct RawMark: Decodable { let vb: [CGFloat]; let s: [RawShape] }

    private static func mark(_ r: RawMark) -> Mark {
        Mark(vb: CGRect(x: r.vb[0], y: r.vb[1], width: r.vb[2], height: r.vb[3]), pieces: r.s.map { Piece(path: SVGPath.parse($0.d), green: $0.k == "g") })
    }

    static let all: [String: Mark] = {
        guard let url = Bundle.main.url(forResource: "cloud_marks", withExtension: "json"),
              let data = try? Data(contentsOf: url), let raw = try? JSONDecoder().decode([String: RawMark].self, from: data) else { return [:] }
        return raw.mapValues(mark)
    }()
}

struct CloudMark: View {
    enum Kind: String { case logo, cloud }
    var kind: Kind = .logo
    var height: CGFloat

    var body: some View {
        if let m = CloudMarks.all[kind.rawValue] {
            Canvas { ctx, size in
                let vb = m.vb
                let s = min(size.width / vb.width, size.height / vb.height)
                let t = CGAffineTransform(translationX: (size.width - vb.width * s) / 2 - vb.minX * s, y: (size.height - vb.height * s) / 2 - vb.minY * s).scaledBy(x: s, y: s)
                for p in m.pieces { ctx.fill(p.path.applying(t), with: p.green ? .color(Color(hex: "#22B573")) : .color(.primary)) }
            }
            .aspectRatio(m.vb.width / m.vb.height, contentMode: .fit)
            .frame(height: height)
            .accessibilityLabel("Plata Cloud")
        } else {
            Text(verbatim: "Plata Cloud").font(.inter(height * 0.6, .bold))
        }
    }
}

/// Botones de la pantalla de Plata Cloud: píldora verde, gris o roja.
struct CloudButtonStyle: ButtonStyle {
    enum Kind { case primary, alt, danger }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(18, .bold))
            .foregroundStyle(kind == .alt ? Color.primary : Color.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 12)
            .background(fill, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
    private var fill: Color {
        switch kind {
        case .primary: return Brand.accent
        case .alt: return Color(.secondarySystemFill)
        case .danger: return Color(hex: "#D70015")
        }
    }
}

enum CloudPrice {
    static var peru: Bool { TimeZone.current.identifier.contains("Lima") }
    static func fmt(_ n: Double) -> String { (peru ? "S/" : "$") + String(format: "%.2f", n) }
    static var base: Double { peru ? 9.99 : 2.99 }
    static var early: Double { (base * 0.7 * 100).rounded() / 100 }
    static var zero: String { peru ? "S/0" : "$0" }
}

/// «$2.09 ~~ $0 primer mes · por invitación»
struct CloudPriceLine: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: CloudPrice.fmt(CloudPrice.early)).strikethrough().foregroundStyle(.secondary).font(.inter(15))
            Text(verbatim: CloudPrice.zero).font(.inter(24, .bold)).foregroundStyle(Brand.gainText)
            Text("primer mes · por invitación").font(.inter(13)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// Nubes verdes de fondo de las tarjetas de Plata Cloud.
private struct CloudBackdrop: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloudMark(kind: .cloud, height: 40).opacity(0.10).offset(x: 24, y: -4).foregroundStyle(Brand.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: texto de estado

extension CloudModel {
    static func ago(_ ms: Double) -> String {
        let m = Int(((Date().timeIntervalSince1970 * 1000) - ms) / 60000)
        if m < 1 { return "hace un momento" }
        if m < 60 { return "hace \(m) min" }
        if m < 1440 { return "hace \(Int((Double(m) / 60).rounded())) h" }
        return "hace \(Int((Double(m) / 1440).rounded())) d"
    }

    var statusText: String {
        if st.mode != .cloud { return "Modo local: este dispositivo no se sincroniza." }
        if status == .demo { return "Hay un demo cargado: la sincronización está en pausa." }
        switch status {
        case .syncing: return "Sincronizando…"
        case .offline: return "Sin conexión. Se reintenta solo."
        case .error: return "No se pudo sincronizar. Se reintenta solo."
        case .login: return "Tu sesión venció. Inicia sesión de nuevo."
        case .choose: return "Falta elegir qué conservar."
        default: return st.last > 0 ? "Sincronizado " + Self.ago(st.last) : "Listo para sincronizar."
        }
    }
}

/// «Sincronizado · Última sincronización · hace 3 min» (`clStatHTML`).
struct CloudStatusLabel: View {
    @Environment(CloudModel.self) private var cloud
    var body: some View {
        if cloud.isIn && cloud.isCloud {
            let bad = [CloudModel.Status.error, .offline, .login, .choose, .demo].contains(cloud.status)
            let busy = cloud.status == .syncing
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: bad ? "exclamationmark.circle.fill" : "checkmark.circle.fill").foregroundStyle(bad ? Color(hex: "#FF9500") : Brand.accent)
                    Text(busy ? "Sincronizando…" : bad ? "Sin sincronizar" : "Sincronizado").foregroundStyle(bad ? Color(hex: "#FF9500") : Brand.gainText)
                }
                .font(.inter(15, .semibold))
                Text(cloud.st.last > 0 ? Tr.t("Última sincronización") + " · " + Tr.t(CloudModel.ago(cloud.st.last)) : Tr.t("Aún sin sincronizar"))
                    .font(.inter(13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: tarjeta del perfil

struct CloudCard: View {
    @Environment(CloudModel.self) private var cloud
    @Environment(AppModel.self) private var model

    private enum Ask: Identifiable {
        case phrase, out, outAll, wipe, del, load, toCloud, toLocal
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .phrase: return "Ver tu frase de recuperación"
            case .out: return "¿Cerrar sesión?"
            case .outAll: return "¿Cerrar sesión en tus otros dispositivos?"
            case .wipe: return "¿Borrar los datos de la nube?"
            case .del: return "¿Borrar tu cuenta?"
            case .load: return "Cargar archivo de perfil"
            case .toCloud: return "¿Activar Plata Cloud?"
            case .toLocal: return "¿Volver al modo local?"
            }
        }
        var message: String {
            switch self {
            case .phrase: return "Asegúrate de que nadie más esté mirando tu pantalla."
            case .out: return "Este dispositivo deja de sincronizarse y olvida tu frase. Tus datos locales se quedan, y para volver a entrar necesitarás el código del correo y tu frase."
            case .outAll: return "Úsalo si perdiste un dispositivo o crees que alguien más entró. Este dispositivo sigue con sesión; en los demás habrá que volver a entrar."
            case .wipe: return "Se borra la copia que Plata Cloud guarda de tus datos (y su respaldo). Tu cuenta sigue activa y los datos de este dispositivo no se tocan, pero pasarás al modo Local. No se puede deshacer. Antes te pediremos 3 palabras de tu frase de recuperación."
            case .del: return "Se borran tu cuenta y tu copia en la nube. Los datos de este dispositivo no se tocan. No se puede deshacer. Te enviaremos un código de verificación a tu correo."
            case .load: return "Esto reemplazará los datos de este dispositivo y tu copia en la nube. Primero te enviaremos un código de verificación a tu correo."
            case .toCloud: return "Los datos de este dispositivo se sincronizarán, cifrados, con tu cuenta."
            case .toLocal: return "Este dispositivo deja de sincronizarse. Tus datos se quedan aquí y la copia de la nube se conserva."
            }
        }
        var action: String {
            switch self {
            case .phrase: return "Mostrar"
            case .out: return "Cerrar sesión"
            case .outAll: return "Cerrar las demás"
            case .wipe: return "Continuar"
            case .del, .load: return "Enviar código"
            case .toCloud: return "Activar"
            case .toLocal: return "Pasar a local"
            }
        }
        var destructive: Bool { self == .outAll || self == .wipe || self == .del }
    }

    @State private var ask: Ask?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CloudMark(height: 30)
                Spacer(minLength: 8)
                BetaPill()
                if cloud.isIn { menu }
            }
            .padding(.bottom, 10)
            if !cloud.isIn { signedOut } else { signedIn }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ZStack { Color(.secondarySystemGroupedBackground); CloudBackdrop() } }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 6).padding(.bottom, 14)
        .alert(Tr.t(ask?.title ?? ""), isPresented: Binding(get: { ask != nil }, set: { if !$0 { ask = nil } }), presenting: ask) { a in
            Button(a.action, role: a.destructive ? .destructive : nil) { run(a) }
            Button("Cancelar", role: .cancel) {}
        } message: { a in Text(a.message) }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sincroniza tus datos entre dispositivos, cifrados de extremo a extremo. Por invitación durante la marcha blanca; si aún no tienes, te apuntamos a la lista de espera.")
                .font(.inter(13)).foregroundStyle(.secondary)
            CloudPriceLine()
            Button("Crear cuenta o entrar") { cloud.openFlow() }.buttonStyle(CloudButtonStyle()).padding(.top, 4)
        }
    }

    private var signedIn: some View {
        let isCloud = cloud.isCloud
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: cloud.email).font(.inter(15, .semibold)).lineLimit(1).truncationMode(.middle)
                    Text(cloud.statusText).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isCloud {
                    Button("Sincronizar") { cloud.syncNow() }
                        .font(.inter(13, .semibold)).foregroundStyle(Brand.gainText)
                        .padding(.horizontal, 14).frame(minHeight: 32)
                        .background(Brand.accent.opacity(0.15), in: Capsule())
                        .disabled(cloud.status == .syncing)
                }
            }
            HStack(spacing: 0) {
                seg("Local", on: !isCloud) { if isCloud { ask = .toLocal } }
                seg("Cloud", on: isCloud) { if !isCloud { ask = .toCloud } }
            }
            .padding(4).background(Color(.tertiarySystemFill), in: Capsule())
            let left = cloud.cooldownLeft
            if left > 0 { CooldownNote(left: left) }
        }
    }

    private func seg(_ t: String, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(t).font(.inter(15, .semibold)).foregroundStyle(on ? Color.primary : .secondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(on ? Color(.systemBackground) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var menu: some View {
        Menu {
            Button("Ver frase de recuperación") { ask = .phrase }
            Button("Cargar archivo de perfil") { ask = .load }
            Button("Cerrar sesión") { ask = .out }
            Button("Cerrar sesión en otros dispositivos") { ask = .outAll }
            Button("Borrar datos de la nube", role: .destructive) { ask = .wipe }
            Button("Borrar cuenta", role: .destructive) { ask = .del }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 34, height: 34).contentShape(Rectangle())
        }
        .accessibilityLabel("Más opciones")
    }

    private func run(_ a: Ask) {
        switch a {
        case .phrase: cloud.showPhrase()
        case .out: cloud.logout()
        case .outAll: cloud.logoutOthers()
        case .wipe: cloud.askWipeCloud()
        case .del: cloud.askDeleteAccount()
        case .load: cloud.askLoadFile()
        case .toCloud: cloud.setMode(.cloud)
        case .toLocal: cloud.setMode(.local)
        }
    }
}

/// «Podrás cambiar de modo otra vez en 42 s.», con la cuenta atrás viva.
private struct CooldownNote: View {
    let left: Int
    @Environment(CloudModel.self) private var cloud
    @State private var shown = 0
    var body: some View {
        Text("Podrás cambiar de modo otra vez en \(shown) s.").font(.inter(12)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            .task {
                shown = left
                while shown > 0 { try? await Task.sleep(for: .seconds(1)); shown = cloud.cooldownLeft }
            }
    }
}

// MARK: franja del Resumen

/// Arriba del Resumen: solicitud de otro dispositivo, aviso de cuenta borrada o la invitación a Plata Cloud.
struct CloudStrip: View {
    @Environment(CloudModel.self) private var cloud

    var body: some View {
        VStack(spacing: 10) {
            if cloud.isIn, let l = cloud.link { LinkRequestCard(req: l) }
            if cloud.gone && !cloud.isIn { goneStrip }
            if !cloud.isIn && !cloud.gone && !cloud.stripClosed && !cloud.joined { invite }
        }
    }

    private var invite: some View {
        HStack(spacing: 10) {
            Image(systemName: "cloud.fill").foregroundStyle(Brand.accent)
            Text("Plata Cloud: marcha blanca gratis un mes").font(.inter(14, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Button("Entrar") { cloud.openFlow() }
                .font(.inter(13, .semibold)).foregroundStyle(.white).padding(.horizontal, 14).frame(minHeight: 32).background(Brand.green, in: Capsule())
            Button { cloud.closeStrip() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary).frame(width: 28, height: 28) }
                .accessibilityLabel("Cerrar")
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var goneStrip: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cuenta borrada").font(.inter(15, .bold)).foregroundStyle(Brand.lossText)
                Text("Tu cuenta de Plata Cloud ya no existe. Guarda tu archivo local para no perder tus datos.").font(.inter(15))
            }
            Spacer(minLength: 0)
            Button { cloud.closeGone() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Brand.lossText).frame(width: 28, height: 28) }
                .accessibilityLabel("Cerrar")
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(hex: "#D70015").opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Un dispositivo nuevo pide entrar: se compara el código y se aprueba o se rechaza (`clLinkHTML`).
struct LinkRequestCard: View {
    let req: CloudModel.LinkRequest
    @Environment(CloudModel.self) private var cloud
    @State private var confirming = false

    private static let tz: [String: String] = {
        guard let url = Bundle.main.url(forResource: "tz_countries", withExtension: "json"),
              let d = try? Data(contentsOf: url), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return m
    }()

    private var place: String {
        guard !req.tz.isEmpty else { return "" }
        let city = (req.tz.split(separator: "/").last.map(String.init) ?? req.tz).replacingOccurrences(of: "_", with: " ")
        if let cc = Self.tz[req.tz], let name = Locale(identifier: Tr.lang).localizedString(forRegionCode: cc) { return city + ", " + name }
        return city
    }

    private var os: (name: String, icon: String) {
        let o = req.plat.components(separatedBy: " · ").first ?? ""
        switch o {
        case "iPhone": return (o, "iphone")
        case "iPad": return (o, "ipad")
        case "Android": return (o, "candybarphone")
        case "Mac": return (o, "laptopcomputer")
        case "Windows", "Linux": return (o, "desktopcomputer")
        default: return (o.isEmpty ? "Dispositivo" : o, "iphone")
        }
    }

    private func spaced(_ c: String) -> String { c.count == 6 ? String(c.prefix(3)) + " " + String(c.suffix(3)) : c }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Solicitud de inicio de sesión").font(.inter(15, .bold))
                Spacer(minLength: 8)
                if req.code.isEmpty {
                    Text(req.stage == .calculating ? "Calculando código…" : "Otro dispositivo está respondiendo").font(.inter(12)).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text("Código").font(.inter(12)).foregroundStyle(.secondary)
                        Text(verbatim: spaced(req.code)).font(.inter(15, .bold)).tracking(1.2)
                    }
                }
            }
            HStack(spacing: 14) {
                Label { Text(verbatim: os.name) } icon: { Image(systemName: os.icon) }
                if !place.isEmpty { Label { Text(verbatim: place) } icon: { Image(systemName: "globe") } }
                if req.t > 0 { Label { Text(verbatim: Date(timeIntervalSince1970: req.t / 1000).formatted(date: .omitted, time: .shortened)) } icon: { Image(systemName: "clock") } }
            }
            .font(.inter(12)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            HStack(spacing: 8) {
                Button("Rechazar") { Task { await cloud.answerLink(approve: false, seen: nil) } }
                    .font(.inter(15, .semibold)).foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                if !req.code.isEmpty {
                    Button("Aprobar") { confirming = true }
                        .font(.inter(15, .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 36)
                        .background(Brand.accent, in: Capsule())
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Color(hex: "#FF9500").opacity(0.15), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .alert("¿Aprobar este dispositivo?", isPresented: $confirming) {
            Button(Tr.t("Aprobar") + " " + spaced(req.code)) { Task { await cloud.answerLink(approve: true, seen: req) } }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Solo apruébalo si fuiste tú y el código es exactamente el mismo que ves en el dispositivo nuevo.") }
    }
}

/// Aviso corto flotante («Sesión cerrada», «Dispositivo aprobado»…).
struct CloudNoticeOverlay: ViewModifier {
    @Environment(CloudModel.self) private var cloud
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let n = cloud.notice {
                Text(n).font(.inter(14, .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24).padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: cloud.notice)
    }
}
