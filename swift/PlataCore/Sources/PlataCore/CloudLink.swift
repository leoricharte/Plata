import CryptoKit
import Foundation

/// Aprobar un inicio de sesión desde otro dispositivo (igual que `PCC.link*` en la web):
/// ECDH P-256 efímero + AES-GCM, con comparación de un código de 6 dígitos y compromiso previo.
/// El servidor solo retransmite texto cifrado; la semilla (la frase) viaja cifrada de un dispositivo al otro.
public enum CloudLink {
    private static let aad = Data("plata-link1".utf8)

    /// Par de claves efímero. `pub` = punto sin comprimir de 65 bytes en base64url, como `exportKey('raw')`.
    public struct Pair {
        public let priv: P256.KeyAgreement.PrivateKey
        public var pub: String { Base64URL.encode(priv.publicKey.x963Representation) }
        public init() { priv = P256.KeyAgreement.PrivateKey() }
        public init(priv: P256.KeyAgreement.PrivateKey) { self.priv = priv }
    }

    /// El dispositivo activo se compromete con su clave y su aleatorio ANTES de ver el aleatorio del nuevo.
    public struct Commit {
        public let pair: Pair
        public let na: String
        public var apub: String { pair.pub }
        public var c: String { CloudLink.commitHash(apub: apub, na: na) }
        public init() { pair = Pair(); na = CloudLink.random(16) }
        init(pair: Pair, na: String) { self.pair = pair; self.na = na }
    }

    public static func random(_ n: Int) -> String {
        var g = SystemRandomNumberGenerator()
        return Base64URL.encode(Data((0..<n).map { _ in UInt8.random(in: 0...255, using: &g) }))
    }

    private static func h64(_ t: String) -> String { Base64URL.encode(Data(SHA256.hash(data: Data(t.utf8)))) }

    public static func commitHash(apub: String, na: String) -> String { h64("plata-commit1|" + apub + "|" + na) }

    public static func verify(commit c: String?, apub: String, na: String) -> Bool {
        guard let c, !c.isEmpty else { return false }
        return c == commitHash(apub: apub, na: na)
    }

    /// Código de 6 dígitos que deben ver igual las dos pantallas.
    public static func code(pub: String, apub: String, na: String, nn: String) -> String {
        let d = [UInt8](SHA256.hash(data: Data(("plata-sas1|" + pub + "|" + apub + "|" + na + "|" + nn).utf8)))
        let n = (UInt32(d[0]) << 24 | UInt32(d[1]) << 16 | UInt32(d[2]) << 8 | UInt32(d[3])) % 1_000_000
        return String(format: "%06d", n)
    }

    private static func key(_ priv: P256.KeyAgreement.PrivateKey, _ pub: String) throws -> SymmetricKey {
        guard let raw = Base64URL.decode(pub) else { throw CloudCryptoError.malformed }
        let other = try P256.KeyAgreement.PublicKey(x963Representation: raw)
        let secret = try priv.sharedSecretFromKeyAgreement(with: other)
        return secret.withUnsafeBytes { SymmetricKey(data: Data($0)) }   // el secreto crudo es la clave AES, igual que deriveKey de WebCrypto
    }

    /// Cifra la semilla para el dispositivo nuevo (`reqPub`).
    public static func seal(priv: P256.KeyAgreement.PrivateKey, reqPub: String, seed: Data) throws -> (iv: String, ct: String) {
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(seed, using: key(priv, reqPub), nonce: nonce, authenticating: aad)
        return (Base64URL.encode(Data(nonce)), Base64URL.encode(box.ciphertext + box.tag))
    }

    /// Abre la semilla que mandó el dispositivo activo (`apub`).
    public static func open(priv: P256.KeyAgreement.PrivateKey, apub: String, iv: String, ct: String) throws -> Data {
        guard let ivd = Base64URL.decode(iv), let c = Base64URL.decode(ct), c.count > 16 else { throw CloudCryptoError.malformed }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: ivd), ciphertext: c.dropLast(16), tag: c.suffix(16))
        return try AES.GCM.open(box, using: key(priv, apub), authenticating: aad)
    }
}
