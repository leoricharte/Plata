import Foundation
#if canImport(Security)
import Security
#endif

/// Guarda la sesión de Plata Cloud en este dispositivo.
/// - La semilla (la llave de los datos) y el token van en el **Llavero** de Apple: cifrados por el sistema y fuera de las copias de seguridad sin cifrar.
/// - El resto del estado (correo, revisión, modo) y la base de combinación van en una carpeta de la app.
public final class DiskCloudStore: CloudStore, @unchecked Sendable {
    private let dir: URL
    private let keychainService: String
    private let lock = NSLock()

    public init(directory: URL, keychainService: String = "net.plataapp.plata.cloud") {
        self.dir = directory
        self.keychainService = keychainService
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private var stateURL: URL { dir.appendingPathComponent("cloud-state.json") }
    private var baseURL: URL { dir.appendingPathComponent("cloud-base.json") }

    public func loadState() -> CloudState {
        lock.withLock {
            var st = (try? Data(contentsOf: stateURL)).flatMap { try? JSONDecoder().decode(CloudState.self, from: $0) } ?? CloudState()
            st.token = Keychain.get(keychainService, "token")
            st.seed = Keychain.get(keychainService, "seed")
            return st
        }
    }

    public func saveState(_ state: CloudState) {
        lock.withLock {
            var disk = state
            disk.token = nil; disk.seed = nil                      // los secretos no se escriben en el archivo
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: stateURL, options: [.atomic, .completeFileProtection]) }
            Keychain.set(keychainService, "token", state.token)
            Keychain.set(keychainService, "seed", state.seed)
        }
    }

    public func loadBase() -> JSONValue? {
        lock.withLock { (try? Data(contentsOf: baseURL)).flatMap { try? JSONValue(jsonData: $0) } }
    }

    public func saveBase(_ base: JSONValue?) {
        lock.withLock {
            if let base, let d = try? base.jsonData() { try? d.write(to: baseURL, options: [.atomic, .completeFileProtection]) }
            else { try? FileManager.default.removeItem(at: baseURL) }
        }
    }

    /// Cerrar sesión o borrar la cuenta: se olvida todo lo de la nube en este dispositivo.
    public func wipe() {
        lock.withLock {
            try? FileManager.default.removeItem(at: stateURL)
            try? FileManager.default.removeItem(at: baseURL)
            Keychain.set(keychainService, "token", nil)
            Keychain.set(keychainService, "seed", nil)
        }
    }
}

enum Keychain {
    #if canImport(Security)
    static func get(_ service: String, _ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ service: String, _ account: String, _ value: String?) {
        let match: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(match as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = match
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly   // no sale del dispositivo (ni en copias del sistema)
        SecItemAdd(add as CFDictionary, nil)
    }
    #else
    static func get(_ service: String, _ account: String) -> String? { nil }
    static func set(_ service: String, _ account: String, _ value: String?) {}
    #endif
}

/// El perfil en el disco del dispositivo (equivale a `finanzas.v3` en la web) y la lectura/escritura del archivo de perfil.
public final class ProfileStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("finanzas.v3.json")
    }

    public func load() -> Profile? {
        lock.withLock { (try? Data(contentsOf: url)).flatMap { try? Profile(jsonData: $0) }?.normalized() }
    }

    public func save(_ profile: Profile) throws {
        try lock.withLock { try profile.jsonData().write(to: url, options: [.atomic, .completeFileProtection]) }
    }

    /// Nombre de archivo de exportación, igual que la web: `plata-AAAA-MM-DD_HH-mm.json`.
    public static func exportFileName(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        func z(_ n: Int?) -> String { String(format: "%02d", n ?? 0) }
        return "plata-\(c.year ?? 0)-\(z(c.month))-\(z(c.day))_\(z(c.hour))-\(z(c.minute)).json"
    }
}
