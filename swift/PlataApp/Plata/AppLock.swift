import SwiftUI
import Combine
import UIKit
import Security
import CommonCrypto
import LocalAuthentication

/// Bloqueo de la app: PIN de 6 dígitos (guardado como hash PBKDF2 con sal en el llavero del sistema) y, si la persona quiere, Face ID / Touch ID.
/// El PIN protege la entrada a la app en este iPhone; no es la llave de cifrado de los datos.
@MainActor @Observable
final class AppLock {
    static let shared = AppLock()
    static let pinLength = 6

    private(set) var hasPIN = false
    private(set) var bioOn = false
    private(set) var grace = 0            // segundos fuera de la app antes de volver a pedir el PIN (0 = siempre)
    private(set) var locked = false
    private(set) var covering = false     // la app no está activa: se tapa el contenido (selector de apps)
    private(set) var waitUntil: Date?     // espera tras demasiados intentos fallidos
    private var leftAt: Date?
    private var window: UIWindow?

    private enum Acct { static let pin = "pin", tries = "tries", bioState = "bio.state" }
    private static let service = "net.plataapp.plata.lock"
    private static let bioKey = "plata.lock.bio", graceKey = "plata.lock.grace", installedKey = "plata.lock.installed"

    private struct PinRecord: Codable { var salt: Data; var hash: Data; var iter: Int }
    private struct Tries: Codable { var fails: Int; var until: Double }

    private init() {
        // El llavero sobrevive a borrar la app: en una instalación nueva se limpia, para no dejar a nadie fuera de una app vacía.
        if !UserDefaults.standard.bool(forKey: Self.installedKey) {
            for a in [Acct.pin, Acct.tries, Acct.bioState] { Self.kcRemove(a) }
            UserDefaults.standard.set(true, forKey: Self.installedKey)
        }
        hasPIN = Self.kcGet(Acct.pin) != nil
        bioOn = hasPIN && UserDefaults.standard.bool(forKey: Self.bioKey)
        grace = UserDefaults.standard.integer(forKey: Self.graceKey)
        locked = hasPIN
        if let t = Self.loadTries(), t.until > Date().timeIntervalSince1970 { waitUntil = Date(timeIntervalSince1970: t.until) }
    }

    // MARK: ciclo de vida

    /// Se llama al arrancar: si hay PIN, la ventana de bloqueo se pone antes de que se vea nada.
    func attach() { sync() }

    func sceneInactive() { if hasPIN { covering = true; sync() } }

    func sceneBackground() {
        guard hasPIN else { return }
        leftAt = leftAt ?? Date()
        if grace == 0 { locked = true }
        covering = true
        sync()
    }

    func sceneActive() {
        covering = false
        if hasPIN, !locked, let t = leftAt, Date().timeIntervalSince(t) >= Double(grace) { locked = true }
        leftAt = nil
        sync()
    }

    // MARK: PIN

    static func isWeak(_ pin: String) -> Bool {
        let d = pin.compactMap { $0.wholeNumberValue }
        guard d.count == pinLength else { return true }
        if Set(d).count == 1 { return true }
        let up = zip(d, d.dropFirst()).allSatisfy { $1 - $0 == 1 }
        let down = zip(d, d.dropFirst()).allSatisfy { $0 - $1 == 1 }
        return up || down
    }

    func setPIN(_ pin: String) {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let iter = 200_000
        let rec = PinRecord(salt: salt, hash: Self.derive(pin, salt: salt, iter: iter), iter: iter)
        guard let data = try? JSONEncoder().encode(rec) else { return }
        Self.kcSet(data, Acct.pin)
        Self.kcRemove(Acct.tries)
        waitUntil = nil
        hasPIN = true
        locked = false
        sync()
    }

    enum Check { case ok, wrong(left: Int), wait(seconds: Int) }

    /// Revisa un PIN. Tras 5 fallos pide esperar (30 s, 1 min, 5 min, 15 min, 1 h) y vuelve a empezar al acertar.
    func check(_ pin: String) -> Check {
        if let w = waitUntil, w > Date() { return .wait(seconds: Int(w.timeIntervalSinceNow.rounded(.up))) }
        guard let data = Self.kcGet(Acct.pin), let rec = try? JSONDecoder().decode(PinRecord.self, from: data) else { return .wrong(left: 0) }
        let h = Self.derive(pin, salt: rec.salt, iter: rec.iter)
        if Self.same(h, rec.hash) {
            Self.kcRemove(Acct.tries); waitUntil = nil
            return .ok
        }
        var t = Self.loadTries() ?? Tries(fails: 0, until: 0)
        t.fails += 1
        let steps: [Int: Double] = [5: 30, 6: 60, 7: 300, 8: 900]
        if t.fails >= 5 {
            let s = steps[t.fails] ?? 3600
            t.until = Date().timeIntervalSince1970 + s
            waitUntil = Date(timeIntervalSince1970: t.until)
        }
        if let d = try? JSONEncoder().encode(t) { Self.kcSet(d, Acct.tries) }
        if t.fails >= 5 { return .wait(seconds: Int((waitUntil?.timeIntervalSinceNow ?? 30).rounded(.up))) }
        return .wrong(left: 5 - t.fails)
    }

    /// Para abrir la app.
    func unlock(with pin: String) -> Check {
        let r = check(pin)
        if case .ok = r { locked = false; leftAt = nil; sync() }
        return r
    }

    /// Para confirmar la identidad dentro de Ajustes (apagar el bloqueo, cambiar el PIN).
    func verify(_ pin: String) -> Check { check(pin) }

    func disable() {
        Self.kcRemove(Acct.pin); Self.kcRemove(Acct.tries); Self.kcRemove(Acct.bioState)
        UserDefaults.standard.set(false, forKey: Self.bioKey)
        hasPIN = false; bioOn = false; locked = false; waitUntil = nil
        sync()
    }

    func setGrace(_ s: Int) { grace = s; UserDefaults.standard.set(s, forKey: Self.graceKey) }

    // MARK: Face ID

    static var bioKind: LABiometryType {
        let c = LAContext(); var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return .none }
        return c.biometryType
    }
    static var bioAvailable: Bool { bioKind != .none }
    static var bioName: String { bioKind == .touchID ? "Touch ID" : "Face ID" }

    /// Enciende Face ID: pide confirmarlo una vez y recuerda el estado biométrico, para apagarlo si cambian las caras o huellas registradas.
    func enableBio() async -> Bool {
        let c = LAContext(); var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return false }
        guard (try? await c.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Activa \(Self.bioName) para abrir Plata")) == true else { return false }
        if let st = c.evaluatedPolicyDomainState { Self.kcSet(st, Acct.bioState) }
        UserDefaults.standard.set(true, forKey: Self.bioKey)
        bioOn = true
        return true
    }

    func disableBio() {
        UserDefaults.standard.set(false, forKey: Self.bioKey)
        Self.kcRemove(Acct.bioState)
        bioOn = false
    }

    func unlockWithBio() async -> Bool {
        guard hasPIN, bioOn, waitUntil.map({ $0 <= Date() }) ?? true else { return false }
        let c = LAContext(); var e: NSError?
        c.localizedCancelTitle = "Usar PIN"
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return false }
        // si cambiaron las caras o huellas registradas, se vuelve a pedir el PIN
        if let saved = Self.kcGet(Acct.bioState), let now = c.evaluatedPolicyDomainState, saved != now { disableBio(); return false }
        guard (try? await c.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Abre Plata")) == true else { return false }
        locked = false; leftAt = nil; sync()
        return true
    }

    /// «Olvidé mi PIN»: se confirma con el código del iPhone, se quita el bloqueo y se puede crear un PIN nuevo en Ajustes.
    func resetWithDevicePasscode() async -> Bool {
        let c = LAContext(); var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthentication, error: &e) else { return false }
        guard (try? await c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Confirma que eres tú para quitar el PIN de Plata")) == true else { return false }
        disable()
        return true
    }

    // MARK: ventana de bloqueo (cubre también las hojas abiertas)

    private func sync() {
        let show = hasPIN && (locked || covering)
        if show {
            if window == nil, let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState != .unattached }) {
                let w = UIWindow(windowScene: scene)
                w.windowLevel = UIWindow.Level.alert + 100
                let theme = UserDefaults.standard.string(forKey: Prefs.themeKey) ?? "auto"
                w.overrideUserInterfaceStyle = theme == "dark" ? .dark : theme == "light" ? .light : .unspecified
                let host = UIHostingController(rootView: LockView())
                host.view.backgroundColor = .systemBackground
                w.rootViewController = host
                w.isHidden = false
                window = w
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        } else if let w = window {
            w.isHidden = true
            window = nil
        }
    }

    // MARK: criptografía y llavero

    private static func derive(_ pin: String, salt: Data, iter: Int) -> Data {
        var out = [UInt8](repeating: 0, count: 32)
        let pw = Array(pin.utf8)
        _ = pw.withUnsafeBytes { p in
            salt.withUnsafeBytes { s in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     p.bindMemory(to: Int8.self).baseAddress, p.count,
                                     s.bindMemory(to: UInt8.self).baseAddress, s.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iter), &out, out.count)
            }
        }
        return Data(out)
    }

    private static func same(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var d: UInt8 = 0
        for (x, y) in zip(a, b) { d |= x ^ y }
        return d == 0
    }

    private static func loadTries() -> Tries? { kcGet(Acct.tries).flatMap { try? JSONDecoder().decode(Tries.self, from: $0) } }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    private static func kcGet(_ account: String) -> Data? {
        var q = query(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }
    private static func kcSet(_ data: Data, _ account: String) {
        kcRemove(account)
        var q = query(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
    private static func kcRemove(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}

// MARK: - teclado y pantalla de bloqueo

/// Teclado numérico con los 6 puntos del PIN (se usa al abrir la app, al crearlo y al confirmarlo).
struct PinPad: View {
    @Binding var digits: String
    var shake: Int = 0
    var disabled = false
    var showBio = false
    var onBio: () -> Void = {}
    var onFull: (String) -> Void

    private let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 34) {
            HStack(spacing: 18) {
                ForEach(0..<AppLock.pinLength, id: \.self) { i in
                    Circle().fill(i < digits.count ? Color.primary : Color.clear)
                        .overlay(Circle().stroke(Color.primary.opacity(0.45), lineWidth: 1.5))
                        .frame(width: 15, height: 15)
                }
            }
            .modifier(Shake(amount: CGFloat(shake)))
            .animation(.default, value: shake)
            VStack(spacing: 14) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 22) { ForEach(row, id: \.self) { key($0) } }
                }
                HStack(spacing: 22) {
                    if showBio {
                        Button(action: onBio) {
                            Image(systemName: AppLock.bioKind == .touchID ? "touchid" : "faceid").font(.system(size: 28)).frame(width: 78, height: 78)
                        }
                        .buttonStyle(.plain).accessibilityLabel(AppLock.bioName)
                    } else { Color.clear.frame(width: 78, height: 78) }
                    key("0")
                    Button {
                        if !digits.isEmpty { digits.removeLast() }
                    } label: {
                        Image(systemName: "delete.left").font(.system(size: 24)).frame(width: 78, height: 78)
                    }
                    .buttonStyle(.plain).opacity(digits.isEmpty ? 0.3 : 1).accessibilityLabel("Borrar")
                }
            }
            .opacity(disabled ? 0.35 : 1).allowsHitTesting(!disabled)
        }
    }

    private func key(_ d: String) -> some View {
        Button {
            guard digits.count < AppLock.pinLength else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            digits += d
            if digits.count == AppLock.pinLength { let v = digits; onFull(v) }
        } label: {
            Text(d).font(.inter(32, .medium)).frame(width: 78, height: 78)
                .background(Color(.secondarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 3), y: 0))
    }
}

/// La pantalla que tapa la app: en bloqueo pide el PIN; si solo está inactiva, deja el logo (para que el selector de apps no enseñe montos).
struct LockView: View {
    private var lock: AppLock { .shared }
    @State private var digits = ""
    @State private var shake = 0
    @State private var message: String?
    @State private var now = Date()
    @State private var forgot = false
    @State private var notice: String?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remaining: Int { lock.waitUntil.map { max(0, Int($0.timeIntervalSince(now).rounded(.up))) } ?? 0 }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                Image(systemName: "lock.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 68, height: 68).background(Brand.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Plata está bloqueada").font(.inter(24, .bold)).tracking(-0.5).padding(.top, 18)
                if lock.locked {
                    Text(remaining > 0 ? "Demasiados intentos. Espera \(Self.clock(remaining))." : (message ?? "Escribe tu PIN"))
                        .font(.inter(15)).foregroundStyle(remaining > 0 || message != nil ? Brand.lossText : Color.secondary)
                        .multilineTextAlignment(.center).padding(.top, 8).frame(minHeight: 22)
                    Spacer(minLength: 24)
                    PinPad(digits: $digits, shake: shake, disabled: remaining > 0, showBio: lock.bioOn && remaining == 0, onBio: { Task { _ = await lock.unlockWithBio() } }) { pin in
                        switch lock.unlock(with: pin) {
                        case .ok: break
                        case .wrong(let left): fail("PIN incorrecto. Te quedan \(left) intentos antes de esperar.")
                        case .wait: fail(nil)
                        }
                    }
                    Button("¿Olvidaste tu PIN?") { forgot = true }
                        .font(.inter(15, .medium)).foregroundStyle(Brand.green).padding(.top, 22)
                } else {
                    Spacer()
                }
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
        }
        .onReceive(tick) { now = $0 }
        .task {
            // Face ID se ofrece solo al abrir, cuando la app ya está activa
            guard lock.locked, lock.bioOn else { return }
            for _ in 0..<20 where UIApplication.shared.applicationState != .active { try? await Task.sleep(for: .milliseconds(150)) }
            try? await Task.sleep(for: .milliseconds(250))
            if lock.locked { _ = await lock.unlockWithBio() }
        }
        .alert("¿Olvidaste tu PIN?", isPresented: $forgot) {
            Button("Usar el código del iPhone") { Task { notice = await lock.resetWithDevicePasscode() ? nil : "No se pudo confirmar con el código del iPhone." } }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Confirma con el código de tu iPhone para quitar el PIN. Tus datos no se tocan. Después puedes crear uno nuevo en Ajustes.") }
        .alert("Plata", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(notice ?? "") }
    }

    private func fail(_ text: String?) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        message = text
        shake += 1
        now = Date()
        digits = ""
    }

    private static func clock(_ s: Int) -> String { s >= 60 ? "\(s / 60) min \(s % 60) s" : "\(s) s" }
}
