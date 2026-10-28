import CryptoKit
import Foundation

/// Estado de la sesión de Plata Cloud en este dispositivo (equivale a `CL.st` en la web).
public struct CloudState: Codable, Equatable, Sendable {
    public var token: String?
    public var email: String?
    public var seed: String?        // semilla en base64url: la llave de los datos. En la app va en el Llavero (ver SessionStore)
    public var kc: String?          // comprobación de clave de la cuenta
    public var mode: Mode = .local
    public var rev: Int = 0         // última revisión sincronizada
    public var last: Double = 0     // ms desde 1970 de la última sincronización
    public var v2: Bool = false     // ya se vieron copias con la revisión dentro del cifrado

    public enum Mode: String, Codable, Sendable { case local, cloud }
    public init() {}

    public var isSignedIn: Bool { token != nil && seed != nil }
    public var isCloud: Bool { isSignedIn && mode == .cloud }
}

/// Dónde se guardan la sesión y la última versión sincronizada (la "base" de la combinación de 3 vías).
public protocol CloudStore: Sendable {
    func loadState() -> CloudState
    func saveState(_ state: CloudState)
    func loadBase() -> JSONValue?
    func saveBase(_ base: JSONValue?)
}

public final class MemoryCloudStore: CloudStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state = CloudState()
    private var base: JSONValue?
    public init() {}
    public func loadState() -> CloudState { lock.withLock { state } }
    public func saveState(_ s: CloudState) { lock.withLock { state = s } }
    public func loadBase() -> JSONValue? { lock.withLock { base } }
    public func saveBase(_ b: JSONValue?) { lock.withLock { base = b } }
}

public enum SyncReason: Sendable { case edit, first, manual, mode, tour }

public enum SyncFailure: Error, Equatable, Sendable {
    case http(Int)
    case revision          // la nube retrocedió o la revisión cifrada no coincide: copia sospechosa
    case writeKey          // la frase de este dispositivo no es la de la cuenta
    case network
    case crypto
}

/// Resultado de una sincronización. La interfaz solo tiene que reaccionar a esto.
public enum SyncResult: Equatable, Sendable {
    case upToDate(rev: Int)                          // nada que aplicar aquí
    case apply(JSONValue, rev: Int)                  // reemplazar el perfil local por este (ya está subido si hacía falta)
    case needsChoice(remote: JSONValue, rev: Int, next: Int)   // los dos lados tienen datos distintos y no hay base: preguntar qué conservar
    case needsLocalConfirm(rev: Int)                 // volver al modo Cloud con datos locales distintos: confirmar antes de reemplazar la nube
    case loggedOut                                   // la sesión venció (401)
    case demoPaused                                  // hay un demo cargado: no se sincroniza
    case failed(SyncFailure)
}

/// Motor de sincronización: port de `clSync` de la web. No toca la interfaz ni el disco del perfil: recibe el perfil local,
/// habla con la nube y dice qué hacer. Así se prueba entero con un servidor falso.
public actor SyncEngine {
    private let api: CloudAPI
    private let store: CloudStore
    private let device: String
    private let now: @Sendable () -> Double
    private var busy = false

    public init(api: CloudAPI = CloudAPI(), store: CloudStore, device: String, now: @escaping @Sendable () -> Double = { Date().timeIntervalSince1970 * 1000 }) {
        self.api = api; self.store = store; self.device = device; self.now = now
    }

    public var state: CloudState { store.loadState() }

    private func seedData(_ st: CloudState) -> Data? { st.seed.flatMap(Base64URL.decode) }

    public func sync(local localIn: Profile, why: SyncReason = .edit) async -> SyncResult {
        var st = store.loadState()
        guard st.isCloud, let token = st.token, let seed = seedData(st) else { return .failed(.http(0)) }
        if localIn.isDemo { return .demoPaused }
        if busy { return .upToDate(rev: st.rev) }
        busy = true; defer { busy = false }

        let key = CloudCrypto.dataKey(seed: seed), wk = CloudCrypto.writeKey(seed: seed)
        var local = localIn.raw
        var changedLocal = false           // ¿el resultado final difiere de lo que me pasaron?
        do {
            for _ in 0..<4 {
                let g = try await api.getSync(token: token, writeKey: wk)
                if g.status == 401 { return .loggedOut }
                guard g.ok else { return .failed(.http(g.status)) }
                let rev = g["rev"]?.intValue ?? 0, next = g["next"]?.intValue ?? rev + 1
                let base = store.loadBase()
                let stale = st.last == 0 || now() - st.last > 80 * 864e5
                if st.v2 && rev > 0 && rev < st.rev { return .failed(.revision) }      // la nube nunca retrocede
                let localHas = Profile(raw: local).hasData

                if rev == 0 {
                    let p = try await put(base: 0, next: next, profile: local, key: key, token: token, wk: wk)
                    if p.status == 409 { continue }
                    guard p.ok else { return .failed(.http(p.status)) }
                    done(&st, rev: p.json["rev"]?.intValue ?? next, profile: local)
                    return changedLocal ? .apply(local, rev: st.rev) : .upToDate(rev: st.rev)
                }

                /* Un dispositivo sin datos nunca borra ni pisa lo que hay en la nube: se carga la nube */
                if rev > 0 && !localHas {
                    let rm = try openRemote(g, key: key, rev: rev, st: &st)
                    if Profile(raw: rm).hasData { done(&st, rev: rev, profile: rm); return .apply(rm, rev: rev) }
                }
                if why == .mode && rev > 0 && localHas {
                    let rm = try openRemote(g, key: key, rev: rev, st: &st)
                    if rm != local { return .needsLocalConfirm(rev: rev) }
                    done(&st, rev: rev, profile: rm); return .upToDate(rev: rev)
                }

                var remote: JSONValue?
                if rev != st.rev || base == nil { remote = try openRemote(g, key: key, rev: rev, st: &st) }
                if let remote, (base == nil || stale), localHas, local != remote {
                    return .needsChoice(remote: remote, rev: rev, next: next)
                }
                let merged: JSONValue
                if let remote {
                    merged = ((base == nil || stale) && !localHas)
                        ? remote
                        : Merge.profiles(base: (base != nil && !stale) ? base : nil, local: local, remote: remote, now: now())
                } else { merged = local }
                if merged != local { local = merged; changedLocal = true }

                let ref = remote ?? base
                if ref == nil || merged != ref! {
                    let p = try await put(base: rev, next: next, profile: merged, key: key, token: token, wk: wk)
                    if p.status == 409 { continue }
                    if p.status == 403 { return p.json["error"]?.stringValue == "wk" ? .failed(.writeKey) : .demoPaused }
                    guard p.ok else { return .failed(.http(p.status)) }
                    st.v2 = true
                    done(&st, rev: p.json["rev"]?.intValue ?? next, profile: merged)
                } else {
                    done(&st, rev: rev, profile: merged)
                }
                return changedLocal ? .apply(local, rev: st.rev) : .upToDate(rev: st.rev)
            }
            return .failed(.http(409))
        } catch is URLError {
            return .failed(.network)
        } catch let e as CloudCryptoError {
            return .failed(e == .revision ? .revision : .crypto)
        } catch {
            return .failed(.crypto)
        }
    }

    // MARK: elegir qué conservar la primera vez (clFirstPick)

    /// Quedarse con la copia de la nube.
    public func chooseRemote(_ remote: JSONValue, rev: Int) -> SyncResult {
        var st = store.loadState(); done(&st, rev: rev, profile: remote)
        return .apply(remote, rev: rev)
    }

    /// Combinar los dos lados y subir el resultado. A diferencia de la web, aquí se manda `next`, para que la revisión viaje cifrada
    /// dentro de la copia (la web lo omite en este camino, y la copia resultante no pasaría la verificación de otros dispositivos).
    public func chooseMerge(local: Profile, remote: JSONValue, rev: Int, next: Int) async -> SyncResult {
        var st = store.loadState()
        guard let token = st.token, let seed = seedData(st) else { return .failed(.http(0)) }
        let merged = Merge.profiles(base: nil, local: local.raw, remote: remote, now: now())
        do {
            let p = try await put(base: rev, next: next, profile: merged, key: CloudCrypto.dataKey(seed: seed), token: token, wk: CloudCrypto.writeKey(seed: seed))
            guard p.ok else { return .failed(.http(p.status)) }
            st.v2 = true
            done(&st, rev: p.json["rev"]?.intValue ?? next, profile: merged)
            return .apply(merged, rev: st.rev)
        } catch is URLError { return .failed(.network) } catch { return .failed(.crypto) }
    }

    // MARK: piezas

    private func put(base: Int, next: Int, profile: JSONValue, key: SymmetricKey, token: String, wk: String) async throws -> CloudResponse {
        let blob = try CloudCrypto.seal(profile, key: key, rev: next)
        return try await api.putSync(base: base, next: next, blob: blob, device: device, token: token, writeKey: wk)
    }

    private func openRemote(_ g: CloudResponse, key: SymmetricKey, rev: Int, st: inout CloudState) throws -> JSONValue {
        guard let blob = g["blob"]?.stringValue else { throw CloudCryptoError.malformed }
        let r = try CloudCrypto.openProfile(blob, key: key, rev: rev, knownV2: st.v2)
        if r.sawV2 && !st.v2 { st.v2 = true; store.saveState(st) }
        return r.profile
    }

    private func done(_ st: inout CloudState, rev: Int, profile: JSONValue) {
        st.rev = rev; st.last = now()
        store.saveState(st); store.saveBase(profile)
    }
}
