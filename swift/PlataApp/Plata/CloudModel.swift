import CryptoKit
import Foundation
import Network
import Observation
import PlataCore
import UIKit

/// Lo que está abierto en la pantalla completa de Plata Cloud (entrar, frase, borrar…): equivale a `CL.ui` de la web.
@MainActor
@Observable
final class CloudFlow {
    enum Step { case email, nolist, listed, linkwait, code, newkey, quiz, enter, show, delcode, replaceauth, wipeq, wipeauth, replacepick, preview, done, tour, first }

    /// Un perfil que se va a subir en lugar de la copia de la nube (archivo elegido, o este dispositivo).
    struct Pending {
        enum Mode { case tour, replace }
        var raw: JSONValue
        var at: Double
        var plat: String
        var mode: Mode
        var code: String?
    }

    var step: Step
    var email = ""
    var err = ""
    var busy = false
    var fresh = false
    var linkCode = ""
    var words: [String] = []
    var pos: [Int] = []
    var enterKc = ""
    var tour = 0
    var locked = false
    var promote = false
    var pend: Pending?
    var code = ""
    var seed: Data?
    /// El idioma de las palabras de la frase que se está mostrando (el de la app).
    var lang: Phrase.Language = .en
    init(_ step: Step, email: String = "") { self.step = step; self.email = email }
}

/// Plata Cloud en la app: la sesión, la sincronización en segundo plano, las pantallas de entrada y la aprobación de dispositivos.
/// El cifrado, el protocolo y la combinación de datos viven en PlataCore (`CloudCrypto`, `CloudAPI`, `SyncEngine`, `Merge`); aquí solo se conectan con la interfaz.
@MainActor
@Observable
final class CloudModel {
    enum Status: Equatable { case idle, syncing, ok, offline, error, login, choose, demo }

    /// Un dispositivo nuevo pidiendo entrar (lo ve el dispositivo que ya tiene sesión).
    struct LinkRequest: Equatable {
        enum Stage { case waiting, calculating, ready }
        var pub: String
        var plat: String
        var tz: String
        var t: Double
        var code = ""
        var stage: Stage = .waiting
    }

    /// Los dos lados tienen datos distintos la primera vez: hay que elegir qué conservar.
    struct FirstPick { var remote: JSONValue; var rev: Int; var next: Int }

    private(set) var st: CloudState
    private(set) var status: Status = .idle
    private(set) var link: LinkRequest?
    private(set) var gone: Bool
    var flow: CloudFlow?
    var notice: String?
    var askLocalUp = false
    var stripClosed: Bool
    /// Ya te apuntaste a la lista de espera (el Resumen deja de ofrecerla).
    private(set) var joined: Bool

    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private let store: DiskCloudStore
    @ObservationIgnored private let api = CloudAPI()
    @ObservationIgnored private let engine: SyncEngine
    @ObservationIgnored private var firstPick: FirstPick?
    @ObservationIgnored private var busy = false
    @ObservationIgnored private var hold = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var linkTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var secret: CloudLink.Commit?
    @ObservationIgnored private var linkBusy = false
    @ObservationIgnored private var active = true
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var online = true
    @ObservationIgnored private let defaults = UserDefaults.standard

    static let cooldown: Double = 60

    /// «iPhone · app» / «iPad · app»: el nombre que el servidor y el otro dispositivo muestran. «app» distingue la app nativa de la web abierta en Safari («iPhone · móvil»).
    static var device: String { (UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") + " · app" }

    init() {
        let dir = URL.applicationSupportDirectory.appending(path: "Plata/cloud", directoryHint: .isDirectory)
        let store = DiskCloudStore(directory: dir)
        self.store = store
        self.st = store.loadState()
        self.engine = SyncEngine(api: CloudAPI(), store: store, device: Self.device)
        self.gone = UserDefaults.standard.bool(forKey: "plata.cloud.gone")
        self.stripClosed = UserDefaults.standard.bool(forKey: "plata.cloud.strip")
        self.joined = UserDefaults.standard.bool(forKey: "plata.cloudwl")
    }

    // MARK: arranque

    func attach(_ model: AppModel) {
        self.model = model
        model.onEdited = { [weak self] in self?.dirty() }
        model.onDemoExit = { [weak self] in
            guard let self, self.st.isSignedIn else { return }
            self.update { $0.last = 0 }
            Task { try? await Task.sleep(for: .milliseconds(400)); await self.sync(.edit) }
        }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let now = path.status == .satisfied
                if now && !self.online { await self.sync(.edit) }
                self.online = now
            }
        }
        m.start(queue: DispatchQueue(label: "plata.cloud.path"))
        monitor = m
        loop?.cancel()
        loop = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            await self?.sync(.edit)
            var n = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                guard let self else { return }
                n += 1
                if self.active {
                    await self.linkCheck()
                    if n % 10 == 0 { await self.sync(.edit) }
                }
            }
        }
    }

    func scene(active: Bool) {
        self.active = active
        if active {
            Task { await sync(.edit); await linkCheck() }
        }
    }

    // MARK: estado

    var isIn: Bool { st.isSignedIn }
    var isCloud: Bool { st.isCloud }
    var email: String { st.email ?? "" }

    /// Segundos que faltan para poder cambiar otra vez entre Local y Cloud.
    var cooldownLeft: Int {
        let t = defaults.double(forKey: "plata.cloud.modeAt")
        guard t > 0 else { return 0 }
        return max(0, Int(ceil(Self.cooldown - (Date().timeIntervalSince1970 - t))))
    }

    private func update(_ f: (inout CloudState) -> Void) {
        var s = store.loadState()
        f(&s)
        store.saveState(s)
        st = s
    }

    private func setGone(_ v: Bool) { gone = v; defaults.set(v, forKey: "plata.cloud.gone") }
    private func markMode(_ on: Bool) { defaults.set(on ? Date().timeIntervalSince1970 : 0, forKey: "plata.cloud.modeAt") }
    private var seedData: Data? { st.seed.flatMap(Base64URL.decode) }
    private var token: String { st.token ?? "" }
    private var wk: String { seedData.map { CloudCrypto.writeKey(seed: $0) } ?? "" }
    private var lang: String { String(Tr.lang.prefix(2)) }
    private var phraseLang: Phrase.Language { Phrase.language(forApp: Tr.lang) }

    func say(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            if !Task.isCancelled { self?.notice = nil }
        }
    }

    private static let connectError = "No pudimos conectar. Inténtalo más tarde."
    private static let tooMany = "Demasiados intentos. Prueba en una hora."

    /// Un perfil que llegó de la nube: reemplaza el local sin volver a dispararse a sí mismo.
    private func applyRemote(_ raw: JSONValue) { model?.applyRemote(raw) }

    /// La nube dice que la sesión ya no vale (401): se olvida todo lo de la nube en este dispositivo y se conserva el correo.
    private func drop() {
        let em = st.email
        let was = st.mode == .cloud || st.seed != nil
        store.wipe()
        st = CloudState()
        update { $0.email = em }
        setGone(was)
        status = .idle
        firstPick = nil
        link = nil; secret = nil
    }

    private func wipeSession() {
        debounce?.cancel()
        store.wipe()
        st = CloudState()
        status = .idle
        firstPick = nil
        link = nil; secret = nil
        markMode(false)
    }

    // MARK: sincronizar

    func dirty() {
        guard st.isCloud, !hold, let m = model, !m.isDemo else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { await self?.sync(.edit) }
        }
    }

    func sync(_ why: SyncReason) async {
        guard let model, st.isCloud, !hold, !busy else { return }
        if model.isDemo { status = .demo; return }
        if !online { status = .offline; return }
        busy = true
        status = .syncing
        let r = await engine.sync(local: model.profile, why: why)
        busy = false
        st = store.loadState()
        handle(r)
    }

    private func handle(_ r: SyncResult) {
        switch r {
        case .upToDate:
            status = .ok
        case .apply(let raw, _):
            applyRemote(raw); status = .ok
        case .needsChoice(let remote, let rev, let next):
            firstPick = FirstPick(remote: remote, rev: rev, next: next)
            status = .choose
            if flow == nil { flow = CloudFlow(.first) }
        case .needsLocalConfirm:
            status = .idle
            update { $0.mode = .local }
            markMode(true)
            askLocalUp = true
        case .loggedOut:
            drop()
        case .demoPaused:
            status = .demo
        case .failed(let f):
            switch f {
            case .network: status = .offline
            default: status = .error
            }
        }
    }

    func syncNow() { Task { await sync(.manual) } }

    // MARK: Local / Cloud

    func setMode(_ to: CloudState.Mode) {
        if to == st.mode { return }
        let wait = cooldownLeft
        if wait > 0 { say("Espera \(wait) s para volver a cambiar de modo"); return }
        update { $0.mode = to }
        markMode(true)
        if to == .cloud { Task { try? await Task.sleep(for: .milliseconds(200)); await sync(.mode) } } else { status = .idle }
    }

    /// Elegiste «Quedarme con este dispositivo»: antes de reemplazar la nube se verifica el correo.
    func confirmLocalUp() {
        Task {
            do {
                let r = try await api.syncConfirm(lang: lang, token: token, writeKey: wk)
                if r.status == 401 { drop(); return }
                if r.status == 429 { say(Self.tooMany); return }
                guard r.ok else { say("No pudimos enviar el código. Inténtalo más tarde."); return }
                let f = CloudFlow(.replaceauth); f.promote = true
                flow = f
            } catch { say(Self.connectError) }
        }
    }

    // MARK: pantalla de entrada

    func openFlow(_ step: CloudFlow.Step = .email) {
        if gone { setGone(false) }
        flow = CloudFlow(step)
    }

    func closeFlow() {
        guard let f = flow, !f.locked else { return }
        linkTask?.cancel()
        if f.step == .tour { tourEnd(); return }
        if f.step == .first { return }          // hay que elegir
        flow = nil
    }

    func closeStrip() { stripClosed = true; defaults.set(true, forKey: "plata.cloud.strip") }
    func closeGone() { setGone(false) }

    private func validEmail(_ s: String) -> Bool { s.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil }

    private func fail(_ f: CloudFlow, _ msg: String) { f.err = msg; f.busy = false }

    /// Paso 1: pedir el código por correo (o ir a la lista de espera si ese correo aún no tiene acceso).
    func sendCode(_ raw: String, resend: Bool = false) {
        guard let f = flow else { return }
        let em = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail(em) else { f.err = "Escribe un correo válido."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.authStart(email: em, lang: lang)
                if r.status == 429 { fail(f, Self.tooMany) }
                else if r.status != 200 { fail(f, Self.connectError) }
                else if r["access"]?.boolValue == false {
                    f.email = em; f.step = r["listed"]?.boolValue == true ? .listed : .nolist; f.fresh = false; f.busy = false
                } else {
                    f.email = em; f.step = .code; f.code = ""; f.busy = false
                    if resend { say("Te mandamos otro código") }
                }
            } catch { fail(f, Self.connectError) }
        }
    }

    func joinWaitlist() {
        guard let f = flow else { return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.waitlist(email: f.email, lang: lang, platform: Self.device)
                if r.status == 429 { fail(f, Self.tooMany); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                joined = true; defaults.set(true, forKey: "plata.cloudwl")
                f.fresh = true; f.step = .listed; f.busy = false
            } catch { fail(f, Self.connectError) }
        }
    }

    func backToEmail() { guard let f = flow else { return }; f.step = .email; f.err = ""; f.busy = false; linkTask?.cancel() }

    /// Paso 2: el código del correo.
    func verify(_ raw: String) {
        guard let f = flow else { return }
        let code = raw.filter { !$0.isWhitespace }
        guard code.count == 6, code.allSatisfy(\.isNumber) else { f.err = "Escribe el código completo."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.authVerify(email: f.email, code: code, device: Self.device)
                guard r.status == 200, let tok = r["token"]?.stringValue else { fail(f, "Código incorrecto o vencido."); return }
                if let old = st.email, old != f.email { store.wipe(); st = CloudState() }
                update { $0.token = tok; $0.email = f.email }
                if r["hasKey"]?.boolValue == true {
                    let kc = r["kc"]?.stringValue ?? ""
                    if st.seed != nil && st.kc == kc { await authDone(isNew: false) }
                    else {
                        update { $0.seed = nil }
                        f.enterKc = kc; f.step = .enter; f.err = ""; f.busy = false
                    }
                } else {
                    let seed = CloudCrypto.newSeed()
                    f.seed = seed; f.lang = phraseLang; f.words = Phrase.words(for: seed, language: phraseLang); f.step = .newkey; f.err = ""; f.busy = false
                }
            } catch { fail(f, Self.connectError) }
        }
    }

    func phraseSaved() {
        guard let f = flow else { return }
        var p = Set<Int>()
        while p.count < 3 { p.insert(Int.random(in: 0..<12)) }
        f.pos = p.sorted(); f.step = .quiz; f.err = ""
    }

    func backToPhrase() { flow?.step = .newkey; flow?.err = "" }

    private func quizOK(_ f: CloudFlow, _ answers: [String]) -> Bool {
        guard answers.count == f.pos.count else { return false }
        for (i, p) in f.pos.enumerated() {
            let a = Phrase.wordIndex(answers[i], language: f.lang), b = Phrase.wordIndex(f.words[p], language: f.lang)
            if a < 0 || a != b { return false }
        }
        return true
    }

    /// Cuenta nueva: se comprueba que anotó la frase y se fija la llave en el servidor.
    func confirmQuiz(_ answers: [String]) {
        guard let f = flow, let seed = f.seed else { return }
        guard quizOK(f, answers) else { f.err = "Alguna palabra no coincide. Revisa tu frase."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.putKey(seed: seed, token: token)
                if r.status == 200 || r.status == 409 {
                    update { $0.seed = Base64URL.encode(seed); $0.kc = CloudCrypto.keyCheck(seed: seed); if r.status == 200 { $0.v2 = true } }
                    await authDone(isNew: true)
                } else { fail(f, "No pudimos guardar la clave. Inténtalo otra vez.") }
            } catch { fail(f, Self.connectError) }
        }
    }

    /// Cuenta existente en un dispositivo nuevo: escribe la frase.
    func enterPhrase(_ text: String) {
        guard let f = flow else { return }
        let cands = Phrase.seeds(from: text)         // español o inglés: sirve la que corresponda a la cuenta
        guard !cands.isEmpty else { f.err = "La frase no es válida. Revisa que sean 12 palabras y que estén bien escritas."; return }
        guard let seed = cands.first(where: { CloudCrypto.keyCheck(seed: $0) == f.enterKc }) else { f.err = "Esa frase no corresponde a esta cuenta."; return }
        let kc = f.enterKc
        update { $0.seed = Base64URL.encode(seed); $0.kc = kc }
        f.busy = true
        Task { await authDone(isNew: false) }
    }

    private func authDone(isNew: Bool) async {
        guard let f = flow else { return }
        update { $0.mode = .cloud }
        markMode(false)
        f.busy = false; f.err = ""
        if isNew { hold = true; f.tour = 0; f.step = .tour; return }
        if let m = model, m.showWelcome, !m.profile.hasData {
            flow = nil
            await sync(.first)
            return
        }
        f.step = .done
        Task { try? await Task.sleep(for: .milliseconds(300)); await sync(.first) }
    }

    // MARK: recorrido de bienvenida

    func tourNext() { flow?.tour += 1 }

    /// «Configurar mi Plata»: sigue el asistente de cuenta nueva.
    func tourSetup() {
        hold = false
        flow = nil
        model?.showWelcome = true
        Task { try? await Task.sleep(for: .milliseconds(300)); await sync(.tour) }
    }

    func tourEnd() {
        hold = false
        flow = nil
        Task { try? await Task.sleep(for: .milliseconds(300)); await sync(.tour) }
    }

    // MARK: pedir aprobación desde otro dispositivo

    func startLink(_ raw: String) {
        guard let f = flow else { return }
        let em = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail(em) else { f.err = "Escribe un correo válido."; return }
        f.busy = true; f.err = ""
        let pair = CloudLink.Pair(), rid = CloudLink.random(24)
        Task {
            do {
                let r = try await api.linkStart(email: em, pub: pair.pub, rid: rid, platform: Self.device, tz: TimeZone.current.identifier, lang: lang)
                if r.status == 429 { fail(f, Self.tooMany); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                if r["access"]?.boolValue == false { f.email = em; f.step = r["listed"]?.boolValue == true ? .listed : .nolist; f.fresh = false; f.busy = false; return }
                f.email = em; f.linkCode = ""; f.step = .linkwait; f.busy = false
                waitForApproval(f, email: em, rid: rid, pair: pair)
            } catch { fail(f, Self.connectError) }
        }
    }

    private func waitForApproval(_ f: CloudFlow, email: String, rid: String, pair: CloudLink.Pair) {
        linkTask?.cancel()
        let t0 = Date()
        linkTask = Task { [weak self] in
            var c: String?, nn: String?, apub: String?
            @MainActor func back(_ msg: String) { f.err = msg; f.step = .email; f.linkCode = "" }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, f.step == .linkwait else { return }
                if Date().timeIntervalSince(t0) > 610 { back("La solicitud venció. Inténtalo otra vez."); return }
                guard let r = try? await self.api.linkPoll(email: email, rid: rid), r.status == 200 else { continue }
                let s = r["st"]?.stringValue ?? ""
                switch s {
                case "p", "n": continue
                case "d": back("Rechazaron la solicitud desde el otro dispositivo."); return
                case "x": back("No hay un dispositivo que pueda aprobarla. Usa el código del correo."); return
                case "c":
                    // el otro dispositivo ya se comprometió: recién ahora elegimos nuestro aleatorio
                    if c == nil { c = r["c"]?.stringValue; nn = CloudLink.random(16) }
                    if c != r["c"]?.stringValue { back("La solicitud cambió a mitad de camino. Inténtalo otra vez."); return }
                    _ = try? await self.api.linkPoll(email: email, rid: rid, nonce: nn)
                    continue
                default: break
                }
                let theirPub = r["apub"]?.stringValue ?? "", na = r["na"]?.stringValue ?? ""
                guard let nn, CloudLink.verify(commit: c, apub: theirPub, na: na) else { back("No pudimos verificar al otro dispositivo. Usa el código del correo."); return }
                if s == "r" {
                    if f.linkCode.isEmpty { apub = theirPub; f.linkCode = CloudLink.code(pub: pair.pub, apub: theirPub, na: na, nn: nn) }
                    continue
                }
                guard s == "a", theirPub == apub else { back("No pudimos verificar la aprobación. Usa el código del correo."); return }
                guard let iv = r["iv"]?.stringValue, let ct = r["ct"]?.stringValue, let tok = r["token"]?.stringValue,
                      let seed = try? CloudLink.open(priv: pair.priv, apub: theirPub, iv: iv, ct: ct),
                      CloudCrypto.keyCheck(seed: seed) == r["kc"]?.stringValue
                else { back("No pudimos verificar la aprobación. Usa el código del correo."); return }
                if let old = self.st.email, old != email { self.store.wipe(); self.st = CloudState() }
                self.update { $0.token = tok; $0.email = email; $0.seed = Base64URL.encode(seed); $0.kc = CloudCrypto.keyCheck(seed: seed) }
                await self.authDone(isNew: false)
                return
            }
        }
    }

    func cancelLink() { linkTask?.cancel(); backToEmail() }

    // MARK: aprobar a otro dispositivo (el que ya tiene sesión)

    func linkCheck() async {
        guard st.isSignedIn, !linkBusy else { return }
        linkBusy = true
        var again = false
        defer { linkBusy = false }
        do {
            let r = try await api.linkPending(token: token, writeKey: wk)
            if r.status == 401 { drop(); return }
            guard r.status == 200 else { return }
            guard let q = r["req"]?.objectValue, let pub = q["pub"]?.stringValue else {
                if link != nil { link = nil; secret = nil }
                return
            }
            let qst = q["st"]?.stringValue ?? ""
            if link == nil || link!.pub != pub {
                link = LinkRequest(pub: pub, plat: q["plat"]?.stringValue ?? "", tz: q["tz"]?.stringValue ?? "", t: q["t"]?.doubleValue ?? 0)
                secret = nil
                if qst == "p" {
                    let c = CloudLink.Commit()
                    let res = try await api.linkStep(["step": .string("commit"), "pub": .string(pub), "c": .string(c.c)], token: token, writeKey: wk)
                    if res.status == 200 { secret = c; link?.stage = .calculating }
                }
            } else if let sec = secret, link?.stage == .calculating, qst == "n", let nn = q["nn"]?.stringValue {
                let res = try await api.linkStep(["step": .string("reveal"), "pub": .string(pub), "apub": .string(sec.apub), "na": .string(sec.na)], token: token, writeKey: wk)
                if res.status == 200 {
                    link?.code = CloudLink.code(pub: pub, apub: sec.apub, na: sec.na, nn: nn)
                    link?.stage = .ready
                }
            }
            again = secret != nil && link?.stage == .calculating     // mientras se arma el código, más seguido
        } catch { /* sin red */ }
        if again { Task { try? await Task.sleep(for: .milliseconds(1500)); await linkCheck() } }
    }

    func answerLink(approve: Bool, seen: LinkRequest?) async {
        guard let L = link else { return }
        if approve, seen == nil || seen != L { say("La solicitud cambió. Revisa el código otra vez."); return }   // se aprueba solo la solicitud cuyo código vio la persona
        var body: [String: JSONValue] = ["step": .string("answer"), "pub": .string(L.pub), "ok": .bool(false)]
        if approve {
            guard L.stage == .ready, let sec = secret, let seed = seedData, let x = try? CloudLink.seal(priv: sec.pair.priv, reqPub: L.pub, seed: seed) else { return }
            body = ["step": .string("answer"), "pub": .string(L.pub), "ok": .bool(true), "iv": .string(x.iv), "ct": .string(x.ct)]
        }
        do {
            let r = try await api.linkStep(body, token: token, writeKey: wk)
            if r.status == 200 { link = nil; secret = nil; say(approve ? "Dispositivo aprobado" : "Solicitud rechazada") }
            else if r.status == 404 || r.status == 409 { link = nil; secret = nil; say("La solicitud ya venció") }
            else { say(Self.connectError) }
        } catch { say(Self.connectError) }
    }

    // MARK: primera vez con datos en los dos lados

    enum PickHow { case merge, remote, local }

    func pickFirst(_ how: PickHow) {
        guard let p = firstPick, let model else { return }
        firstPick = nil
        flow = nil
        busy = true; status = .syncing
        Task {
            var res: SyncResult?
            switch how {
            case .remote: res = await engine.chooseRemote(p.remote, rev: p.rev)
            case .merge: res = await engine.chooseMerge(local: model.profile, remote: p.remote, rev: p.rev, next: p.next)
            case .local: break
            }
            busy = false
            st = store.loadState()
            if how == .local { status = .idle; update { $0.mode = .local }; markMode(true); askLocalUp = true; return }
            if let res {
                handle(res)
                if status == .ok { say("Listo, ya está sincronizado") }
            }
        }
    }

    // MARK: menú de la cuenta

    func showPhrase() {
        guard let seed = seedData else { return }
        let f = CloudFlow(.show)
        f.lang = phraseLang
        f.words = Phrase.words(for: seed, language: phraseLang)
        flow = f
    }

    func logout() {
        Task {
            _ = try? await api.logout(token: token)
            wipeSession()
            say("Sesión cerrada")
        }
    }

    func logoutOthers() {
        Task {
            do {
                let r = try await api.logoutAll(device: Self.device, token: token, writeKey: wk)
                if r.status == 200, let tok = r["token"]?.stringValue { update { $0.token = tok }; say("Listo: cerramos tus otras sesiones") }
                else { say("No pudimos cerrar las sesiones. Inténtalo más tarde.") }
            } catch { say(Self.connectError) }
        }
    }

    /// Pide el código por correo para una acción delicada y abre el paso que lo recibe.
    private func askEmailCode(kind: String?, next: CloudFlow.Step, promote: Bool = false) {
        Task {
            do {
                let r = try await api.syncConfirm(kind: kind, lang: lang, token: token, writeKey: wk)
                if r.status == 401 { drop(); return }
                if r.status == 429 { say(Self.tooMany); return }
                guard r.ok else { say("No pudimos enviar el código. Inténtalo más tarde."); return }
                let f = CloudFlow(next); f.promote = promote
                flow = f
            } catch { say(Self.connectError) }
        }
    }

    func askDeleteAccount() { askEmailCode(kind: "delete", next: .delcode) }

    func deleteAccount(_ raw: String) {
        guard let f = flow else { return }
        let code = raw.filter { !$0.isWhitespace }
        guard code.count == 6, code.allSatisfy(\.isNumber) else { f.err = "Escribe el código completo."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.deleteAccount(code: code, token: token, writeKey: wk)
                if r.status == 400 { fail(f, "Código incorrecto o vencido."); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                wipeSession()
                flow = nil
                say("Cuenta borrada")
            } catch { fail(f, Self.connectError) }
        }
    }

    /// «Borrar datos de la nube»: tres palabras de la frase, cuenta atrás de 5 s y se vacía la copia.
    func askWipeCloud() {
        guard let seed = seedData else { return }
        var p = Set<Int>()
        while p.count < 3 { p.insert(Int.random(in: 0..<12)) }
        let f = CloudFlow(.wipeq)
        f.lang = phraseLang; f.words = Phrase.words(for: seed, language: phraseLang); f.pos = p.sorted()
        flow = f
    }

    func wipeQuizOK(_ answers: [String]) -> Bool {
        guard let f = flow else { return false }
        if quizOK(f, answers) { return true }
        f.err = "Alguna palabra no coincide. Revisa tu frase."
        return false
    }

    func wipeCloudNow() async {
        flow = nil
        do {
            let r = try await api.deleteSync(token: token, writeKey: wk)
            if r.status == 200 {
                update { $0.mode = .local; $0.last = 0 }
                markMode(true)
                status = .idle
                say("Borramos los datos de tu nube. Pasaste al modo Local; lo de este dispositivo sigue intacto.")
            }
            else if r.status == 401 { drop() }
            else if r.status == 403 { say("Tu frase no coincide con la de la cuenta. Cierra sesión y vuelve a entrar con tu frase.") }
            else { say("No pudimos borrar tus datos. Inténtalo más tarde.") }
        } catch { say(Self.connectError) }
    }

    // MARK: reemplazar la copia de la nube con un archivo de perfil

    /// Desde el perfil: «Cargar archivo de perfil». Sin copia previa no hace falta verificar el correo.
    func askLoadFile() {
        if st.rev == 0 { let f = CloudFlow(.replacepick); f.code = ""; flow = f }
        else { askEmailCode(kind: nil, next: .replaceauth) }
    }

    func checkReplaceCode(_ raw: String) {
        guard let f = flow else { return }
        let code = raw.filter { !$0.isWhitespace }
        guard code.count == 6, code.allSatisfy(\.isNumber) else { f.err = "Escribe el código completo."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let r = try await api.syncCheck(code: code, token: token, writeKey: wk)
                if r.status == 400 { fail(f, "Código incorrecto o vencido."); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                f.busy = false
                if f.promote, let m = model {
                    f.pend = .init(raw: m.profile.raw, at: Date().timeIntervalSince1970 * 1000, plat: Self.device, mode: .replace, code: code)
                    f.step = .preview
                } else { f.code = code; f.step = .replacepick }
            } catch { fail(f, Self.connectError) }
        }
    }

    /// El archivo que eligió la persona (desde la pantalla de elegir archivo o desde el recorrido).
    func fileChosen(_ data: Data, tour: Bool) {
        guard let f = flow else { return }
        do {
            let incoming = try Profile(jsonData: data)
            let meta = incoming.raw["meta"]
            let migrated = try Migration.migrate(incoming)
            if migrated.isDemo { say("Ese archivo es de una demostración y no se puede subir."); return }
            var raw = migrated.raw; raw["demo"] = .bool(false)
            f.pend = .init(raw: raw, at: meta?["at"]?.doubleValue ?? 0, plat: String((meta?["plat"]?.stringValue ?? "").prefix(40)),
                           mode: tour ? .tour : .replace, code: tour ? nil : (f.code.isEmpty ? nil : f.code))
            f.err = ""
            f.step = .preview
        } catch { say("No pude leer ese archivo de perfil") }
    }

    func previewBack() {
        guard let f = flow, let p = f.pend else { return }
        f.pend = nil; f.err = ""
        if p.mode == .tour { f.step = .tour }
        else if let c = p.code { f.code = c; f.step = .replacepick }
        else { flow = nil }
    }

    func uploadPending() {
        guard let f = flow, let p = f.pend, let seed = seedData else { return }
        f.busy = true; f.err = ""
        Task {
            do {
                let g = try await api.getSync(token: token, writeKey: wk)
                if g.status == 401 { drop(); return }
                let rev = g["rev"]?.intValue ?? 0, next = g["next"]?.intValue ?? rev + 1
                let blob = try CloudCrypto.seal(p.raw, key: CloudCrypto.dataKey(seed: seed), rev: next)
                let r = try await api.replaceSync(base: rev, next: next, blob: blob, device: Self.device, code: p.code, token: token, writeKey: wk)
                if r.status == 400 { fail(f, "Código incorrecto o vencido. Vuelve a empezar."); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                let newRev = r["rev"]?.intValue ?? next
                applyRemote(p.raw)
                update { $0.v2 = true; $0.rev = newRev; $0.last = Date().timeIntervalSince1970 * 1000; if f.promote { $0.mode = .cloud } }
                store.saveBase(p.raw)
                if f.promote { markMode(true) }
                status = .ok
                f.busy = false
                say(p.mode == .tour ? "Archivo de perfil cargado" : "Archivo cargado y copia reemplazada")
                if p.mode == .tour { tourEnd() } else { flow = nil }
            } catch { fail(f, Self.connectError) }
        }
    }

    /// Reemplaza la copia de la nube por un perfil vacío (para «Borrar todos tus datos» en modo Cloud), con el código del correo.
    func wipeWithCode(_ raw: String, then run: @escaping () -> Void) {
        guard let f = flow, let seed = seedData else { return }
        let code = raw.filter { !$0.isWhitespace }
        guard code.count == 6, code.allSatisfy(\.isNumber) else { f.err = "Escribe el código completo."; return }
        f.busy = true; f.err = ""
        Task {
            do {
                let empty = try Migration.migrate(Profile.empty).raw
                let g = try await api.getSync(token: token, writeKey: wk)
                let rev = g["rev"]?.intValue ?? 0, next = g["next"]?.intValue ?? rev + 1
                let blob = try CloudCrypto.seal(empty, key: CloudCrypto.dataKey(seed: seed), rev: next)
                let r = try await api.replaceSync(base: rev, next: next, blob: blob, device: Self.device, code: code, token: token, writeKey: wk)
                if r.status == 400 { fail(f, "Código incorrecto o vencido."); return }
                guard r.status == 200 else { fail(f, Self.connectError); return }
                flow = nil
                run()
                update { $0.v2 = true; $0.rev = r["rev"]?.intValue ?? next; $0.last = Date().timeIntervalSince1970 * 1000 }
                store.saveBase(empty)
            } catch { fail(f, Self.connectError) }
        }
    }

    /// Para que «Borrar todos tus datos» de Ajustes sepa si debe pedir el código del correo.
    var needsCodeToWipe: Bool { st.isCloud && st.rev > 0 }

    func askWipeLocalToo(run: @escaping () -> Void) {
        Task {
            do {
                let r = try await api.syncConfirm(lang: lang, token: token, writeKey: wk)
                if r.status == 401 { drop(); return }
                if r.status == 429 { say(Self.tooMany); return }
                guard r.ok else { say("No pudimos enviar el código. Inténtalo más tarde."); return }
                let f = CloudFlow(.wipeauth)
                flow = f
                wipeRun = run
            } catch { say(Self.connectError) }
        }
    }
    @ObservationIgnored var wipeRun: (() -> Void)?
}
