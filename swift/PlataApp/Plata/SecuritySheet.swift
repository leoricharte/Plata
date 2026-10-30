import SwiftUI
import Combine
import LocalAuthentication

/// Crear un PIN: se escribe dos veces y se rechazan los obvios (000000, 123456…).
struct PinSetupView: View {
    var title = "Crea tu PIN"
    var onDone: (Bool) -> Void
    @State private var first: String?
    @State private var digits = ""
    @State private var shake = 0
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDone(false) } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cerrar")
                Spacer()
            }
            Spacer(minLength: 10)
            Image(systemName: "lock.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 64, height: 64).background(Brand.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            Text(first == nil ? title : "Repite tu PIN").font(.inter(26, .bold)).tracking(-0.6).padding(.top, 16)
            Text(error ?? (first == nil ? "Elige \(AppLock.pinLength) dígitos que solo tú sepas." : "Escríbelo otra vez para confirmarlo."))
                .font(.inter(15)).foregroundStyle(error == nil ? Color.secondary : Brand.lossText)
                .multilineTextAlignment(.center).padding(.top, 8).frame(minHeight: 40, alignment: .top)
            Spacer(minLength: 16)
            PinPad(digits: $digits, shake: shake) { pin in
                if let f = first {
                    if f == pin { AppLock.shared.setPIN(pin); onDone(true) }
                    else { first = nil; fail("No coinciden. Empieza de nuevo.") }
                } else if AppLock.isWeak(pin) {
                    fail("Ese PIN es muy fácil de adivinar. Elige otro.")
                } else {
                    error = nil; first = pin; digits = ""
                }
            }
            Spacer(minLength: 30)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func fail(_ t: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        error = t; shake += 1; digits = ""
    }
}

/// Pide el PIN actual (para apagar el bloqueo o cambiarlo).
struct PinCheckView: View {
    var title: String
    var onDone: (Bool) -> Void
    @State private var digits = ""
    @State private var shake = 0
    @State private var error: String?
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var remaining: Int { AppLock.shared.waitUntil.map { max(0, Int($0.timeIntervalSince(now).rounded(.up))) } ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDone(false) } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cerrar")
                Spacer()
            }
            Spacer(minLength: 10)
            Text(title).font(.inter(26, .bold)).tracking(-0.6).multilineTextAlignment(.center)
            Text(remaining > 0 ? "Demasiados intentos. Espera \(remaining) s." : (error ?? "Escribe tu PIN actual."))
                .font(.inter(15)).foregroundStyle(error == nil && remaining == 0 ? Color.secondary : Brand.lossText)
                .multilineTextAlignment(.center).padding(.top, 8).frame(minHeight: 40, alignment: .top)
            Spacer(minLength: 16)
            PinPad(digits: $digits, shake: shake, disabled: remaining > 0) { pin in
                switch AppLock.shared.verify(pin) {
                case .ok: onDone(true)
                case .wrong(let left): fail("PIN incorrecto. Te quedan \(left) intentos antes de esperar.")
                case .wait: fail(nil)
                }
            }
            Spacer(minLength: 30)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onReceive(tick) { now = $0 }
    }

    private func fail(_ t: String?) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        error = t; shake += 1; digits = ""; now = Date()
    }
}

/// Ajustes → Seguridad.
struct SecuritySheet: View {
    @Environment(\.dismiss) private var dismiss
    private var lock: AppLock { .shared }
    private enum Flow: Identifiable { case create, change, off
        var id: Int { switch self { case .create: 0; case .change: 1; case .off: 2 } } }
    @State private var flow: Flow?
    @State private var changing = false
    @State private var bioError: String?

    private let graces: [(String, Int)] = [("Siempre", 0), ("1 minuto", 60), ("5 minutos", 300), ("15 minutos", 900)]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Seguridad", onClose: { dismiss() })
                Text("Protege la entrada a Plata en este iPhone con un PIN y, si quieres, con \(AppLock.bioName).")
                    .font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 14)

                SCard {
                    toggleRow("lock.fill", "Bloquear con PIN", on: Binding(get: { lock.hasPIN }, set: { v in flow = v ? .create : .off }))
                    if lock.hasPIN {
                        RowDivider()
                        Button { flow = .change } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "key.fill").frame(width: 26).foregroundStyle(Brand.accent)
                                Text("Cambiar PIN").font(.inter(17)).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(.tertiaryLabel))
                            }
                            .padding(.vertical, 14).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if AppLock.bioAvailable {
                            RowDivider()
                            toggleRow(AppLock.bioKind == .touchID ? "touchid" : "faceid", "Usar \(AppLock.bioName)", on: Binding(get: { lock.bioOn }, set: { v in
                                if v { Task { if await !lock.enableBio() { bioError = "No se pudo activar \(AppLock.bioName). Revisa que esté configurado en tu iPhone y que Plata tenga permiso." } } }
                                else { lock.disableBio() }
                            }))
                        }
                    }
                }

                if lock.hasPIN {
                    Text("Pedir el PIN").font(.inter(13, .semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 22).padding(.bottom, 8)
                    SCard {
                        ForEach(Array(graces.enumerated()), id: \.offset) { i, g in
                            if i > 0 { RowDivider() }
                            Button { lock.setGrace(g.1) } label: {
                                HStack {
                                    Text(g.0).font(.inter(17)).foregroundStyle(.primary)
                                    Spacer()
                                    if lock.grace == g.1 { Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Brand.accent) }
                                }
                                .padding(.vertical, 14).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Es el tiempo que puedes salir de la app antes de que vuelva a pedirlo.")
                        .font(.inter(13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu PIN se guarda como una huella cifrada en el llavero de este iPhone, nunca en claro ni en la nube. Tras 5 intentos fallidos, la app te hace esperar cada vez más.")
                    Text("Si lo olvidas, puedes quitarlo confirmando con el código de tu iPhone. Tus datos no se tocan.")
                    Text("El bloqueo cubre la app. El Apple Watch y los widgets de la pantalla de inicio no piden PIN.")
                }
                .font(.inter(13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.top, 18)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 30)
        }
        .presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
        .fullScreenCover(item: $flow) { f in
            switch f {
            case .create: PinSetupView { _ in flow = nil }
            case .change:
                if changing { PinSetupView(title: "Crea tu PIN nuevo") { _ in changing = false; flow = nil } }
                else { PinCheckView(title: "Escribe tu PIN actual") { ok in if ok { changing = true } else { flow = nil } } }
            case .off:
                PinCheckView(title: "Escribe tu PIN para apagar el bloqueo") { ok in if ok { lock.disable() }; flow = nil }
            }
        }
        .alert("Plata", isPresented: Binding(get: { bioError != nil }, set: { if !$0 { bioError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(bioError ?? "") }
    }

    private func toggleRow(_ symbol: String, _ title: String, on: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(Brand.accent)
            Toggle(title, isOn: on).font(.inter(17)).tint(Brand.accent)
        }
        .padding(.vertical, 8)
    }
}

/// Paso de la bienvenida: ofrece crear el PIN (y Face ID) antes de entrar.
struct ProtectStep: View {
    var next: () -> Void
    @State private var creating = false
    @State private var asked = false
    private var lock: AppLock { .shared }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 76, height: 76).background(Brand.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("Protege tu app").font(.inter(30, .bold)).tracking(-0.8).padding(.top, 20)
            Text("Pon un PIN\(AppLock.bioAvailable ? " y \(AppLock.bioName)" : "") para que nadie más abra tus finanzas en este iPhone. Puedes cambiarlo cuando quieras en Ajustes → Seguridad.")
                .font(.inter(16)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 10).padding(.horizontal, 10)
            Spacer()
            Button("Crear PIN") { creating = true }.buttonStyle(PrimaryPillStyle())
            Button("Ahora no") { next() }.font(.inter(17, .medium)).foregroundStyle(Brand.green).frame(height: 52)
        }
        .fullScreenCover(isPresented: $creating) {
            PinSetupView { ok in
                creating = false
                if ok, AppLock.bioAvailable { Task { _ = await lock.enableBio(); next() } } else { next() }
            }
        }
    }
}
