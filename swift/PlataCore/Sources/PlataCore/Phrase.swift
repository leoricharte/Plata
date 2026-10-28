import CryptoKit
import Foundation

/// La frase de recuperación: 12 palabras que codifican la semilla de 128 bits más 4 bits de suma de verificación.
/// Mismo esquema que la web (PCC.toPhrase / PCC.fromPhrase).
public enum Phrase {
    private static let index: [String: Int] = {
        var d: [String: Int] = [:]
        for (i, w) in Wordlist.words.enumerated() { d[w] = i }
        return d
    }()

    private static func checksum(_ seed: Data) -> Int {
        Int(SHA256.hash(data: seed).first! >> 4)
    }

    public static func words(for seed: Data) -> [String] {
        precondition(seed.count == 16, "la semilla mide 16 bytes")
        var bits: [Int] = []
        for byte in seed { for i in stride(from: 7, through: 0, by: -1) { bits.append(Int((byte >> UInt8(i)) & 1)) } }
        let c = checksum(seed)
        for i in stride(from: 3, through: 0, by: -1) { bits.append((c >> i) & 1) }
        return (0..<12).map { w in
            var v = 0
            for j in 0..<11 { v = (v << 1) | bits[w * 11 + j] }
            return Wordlist.words[v]
        }
    }

    /// Índice de una palabra: exacta, o por prefijo si es única (de 4 letras en adelante). -1 si no existe.
    public static func wordIndex(_ word: String) -> Int {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = index[w] { return i }
        if w.count < 4 { return -1 }
        let m = Wordlist.words.filter { $0.hasPrefix(w) }
        return m.count == 1 ? index[m[0]]! : -1
    }

    /// La semilla, o nil si falta una palabra, sobra una o hay un error de escritura.
    public static func seed(from text: String) -> Data? {
        let words = text.lowercased()
            .split(whereSeparator: { !($0.isASCII && $0.isLetter) })
            .map(String.init)
        guard words.count == 12 else { return nil }
        var bits: [Int] = []
        for w in words {
            let v = wordIndex(w)
            if v < 0 { return nil }
            for j in stride(from: 10, through: 0, by: -1) { bits.append((v >> j) & 1) }
        }
        var seed = Data(count: 16)
        for i in 0..<128 { seed[i >> 3] |= UInt8(bits[i] << (7 - (i & 7))) }
        var c = 0
        for i in 128..<132 { c = (c << 1) | bits[i] }
        return checksum(seed) == c ? seed : nil
    }
}
