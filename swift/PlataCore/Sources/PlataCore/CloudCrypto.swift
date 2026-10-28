import CryptoKit
import Foundation

public enum CloudCryptoError: Error, Equatable {
    case version          // el blob no empieza con la versión 1
    case malformed
    case revision         // la revisión cifrada no coincide con la que dice el servidor (copia vieja reenviada)
}

/// Cifrado de Plata Cloud, idéntico al de la web (PCC en app.html):
/// semilla de 128 bits → HKDF-SHA256 (sal "plata-cloud-v1") → clave de datos AES-GCM-256, comprobación de clave y llave de escritura.
/// Blob = base64url( 0x01 · gzip(0/1) · IV de 12 bytes · AES-GCM(texto + etiqueta de 16 bytes) ), con "plata1" como datos autenticados.
public enum CloudCrypto {
    private static let salt = Data("plata-cloud-v1".utf8)
    private static let aad = Data("plata1".utf8)

    public static func newSeed() -> Data {
        var g = SystemRandomNumberGenerator()
        return Data((0..<16).map { _ in UInt8.random(in: 0...255, using: &g) })
    }

    private static func derive(_ seed: Data, _ info: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: seed), salt: salt, info: Data(info.utf8), outputByteCount: 32)
    }

    public static func dataKey(seed: Data) -> SymmetricKey { derive(seed, "data") }

    /// Comprobación que ve el servidor (no revela la clave de datos).
    public static func keyCheck(seed: Data) -> String { Base64URL.encode(derive(seed, "check").withUnsafeBytes { Data($0) }) }

    /// Permiso para escribir o borrar la copia: sin la frase no se puede pisar.
    public static func writeKey(seed: Data) -> String { Base64URL.encode(derive(seed, "write").withUnsafeBytes { Data($0) }) }

    /// Cifra un perfil. Con `rev` (> 0) la revisión viaja DENTRO del cifrado: `{ plata: 2, rev, d: perfil }`.
    public static func seal(_ profile: JSONValue, key: SymmetricKey, rev: Int?) throws -> String {
        let body: JSONValue = (rev ?? 0) > 0
            ? .object(["plata": .number(2), "rev": .number(Double(rev!)), "d": profile])
            : profile
        let plain = try body.jsonData()
        var payload = plain
        var z: UInt8 = 0
        if let zipped = try? Gzip.compress(plain) { payload = zipped; z = 1 }   // como la web: si no se puede comprimir, va sin comprimir
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(payload, using: key, nonce: nonce, authenticating: aad)
        var out = Data([1, z])
        out.append(contentsOf: nonce)
        out.append(box.ciphertext)
        out.append(box.tag)
        return Base64URL.encode(out)
    }

    /// Abre un blob y devuelve el JSON tal como se cifró (sin interpretar la revisión).
    public static func open(_ blob: String, key: SymmetricKey) throws -> JSONValue {
        guard let u = Base64URL.decode(blob), u.count > 14 + 16 else { throw CloudCryptoError.malformed }
        let b = [UInt8](u)
        guard b[0] == 1 else { throw CloudCryptoError.version }
        let nonce = try AES.GCM.Nonce(data: Data(b[2..<14]))
        let rest = Array(b[14...])
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: Data(rest.dropLast(16)), tag: Data(rest.suffix(16)))
        var plain = try AES.GCM.open(box, using: key, authenticating: aad)
        if b[1] == 1 { plain = try Gzip.decompress(plain) }
        return try JSONValue(jsonData: plain)
    }

    /// Abre la copia de la nube y comprueba que la revisión cifrada coincide con la del servidor.
    /// `knownV2`: ya vimos copias con revisión cifrada, así que una sin ella no se acepta. `sawV2` indica que esta sí la traía.
    public static func openProfile(_ blob: String, key: SymmetricKey, rev: Int, knownV2: Bool) throws -> (profile: JSONValue, sawV2: Bool) {
        let x = try open(blob, key: key)
        if x["plata"]?.intValue == 2 {
            guard x["rev"]?.intValue == rev else { throw CloudCryptoError.revision }
            return (x["d"] ?? .null, true)
        }
        if knownV2 { throw CloudCryptoError.revision }
        return (x, false)
    }
}
