import CryptoKit
import Foundation

/// La frase de recuperación: 12 palabras que codifican la semilla de 128 bits más 4 bits de suma de verificación.
/// Mismo esquema que la web (PCC.toPhrase / PCC.fromPhrase).
public enum Phrase {
    /// El idioma en que se escribe la frase. La llave es la misma: solo cambian las palabras.
    public enum Language: Sendable { case en, es }

    /// El idioma de la frase que corresponde al de la app.
    public static func language(forApp lang: String) -> Language { lang.hasPrefix("es") ? .es : .en }

    private static func list(_ l: Language) -> [String] { l == .es ? WordlistES.words : Wordlist.words }

    private static let indexEN = makeIndex(Wordlist.words)
    private static let indexES = makeIndex(WordlistES.words)
    private static func makeIndex(_ ws: [String]) -> [String: Int] {
        var d: [String: Int] = [:]
        for (i, w) in ws.enumerated() { d[w] = i }
        return d
    }
    private static func index(_ l: Language) -> [String: Int] { l == .es ? indexES : indexEN }

    private static func checksum(_ seed: Data) -> Int {
        Int(Array(SHA256.hash(data: seed))[0] >> 4)
    }

    public static func words(for seed: Data, language: Language = .en) -> [String] {
        let wl = list(language)
        precondition(seed.count == 16, "la semilla mide 16 bytes")
        var bits: [Int] = []
        for byte in seed { for i in stride(from: 7, through: 0, by: -1) { bits.append(Int((byte >> UInt8(i)) & 1)) } }
        let c = checksum(seed)
        for i in stride(from: 3, through: 0, by: -1) { bits.append((c >> i) & 1) }
        return (0..<12).map { w in
            var v = 0
            for j in 0..<11 { v = (v << 1) | bits[w * 11 + j] }
            return wl[v]
        }
    }

    /// Índice de una palabra: exacta, o por prefijo si es única (de 4 letras en adelante). -1 si no existe.
    /// En español se ignoran las tildes y la eñe (se acepta «canción» o «cancion»).
    public static func wordIndex(_ word: String, language: Language = .en) -> Int {
        var w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if language == .es { w = w.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "es")) }
        let ix = index(language)
        if let i = ix[w] { return i }
        if w.count < 4 { return -1 }
        let m = list(language).filter { $0.hasPrefix(w) }
        return m.count == 1 ? ix[m[0]]! : -1
    }

    /// Todas las lecturas posibles de una frase escrita: en el idioma que sea (unas pocas palabras existen en los dos).
    /// Quien la use comprueba cuál corresponde a la cuenta con la comprobación de clave.
    public static func seeds(from text: String) -> [Data] {
        [Language.es, .en].compactMap { seed(from: text, language: $0) }
    }

    /// La semilla, o nil si falta una palabra, sobra una o hay un error de escritura.
    public static func seed(from text: String, language: Language = .en) -> Data? {
        let words = text.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        guard words.count == 12 else { return nil }
        var bits: [Int] = []
        for w in words {
            let v = wordIndex(w, language: language)
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
