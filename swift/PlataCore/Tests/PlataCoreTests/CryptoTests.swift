import CryptoKit
import XCTest
@testable import PlataCore

final class CryptoTests: XCTestCase {
    func testWordlistIsBIP39Size() {
        XCTAssertEqual(Wordlist.words.count, 2048)
        XCTAssertEqual(Set(Wordlist.words).count, 2048)
    }

    /// Semillas, frases, comprobación de clave y llave de escritura: deben coincidir con lo que calcula la web.
    func testSeedsMatchWeb() throws {
        let f = try fixture("crypto")
        for s in f["seeds"]!.arrayValue! {
            let seed = hexData(s["seedHex"]!.stringValue!)
            XCTAssertEqual(Phrase.words(for: seed).joined(separator: " "), s["phrase"]!.stringValue!)
            XCTAssertEqual(Phrase.seed(from: s["phrase"]!.stringValue!), seed)
            XCTAssertEqual(CloudCrypto.keyCheck(seed: seed), s["check"]!.stringValue!)
            XCTAssertEqual(CloudCrypto.writeKey(seed: seed), s["write"]!.stringValue!)
            XCTAssertEqual(Base64URL.encode(seed), s["seedB64u"]!.stringValue!)
        }
    }

    /// Copias cifradas por la web (con y sin gzip, con y sin revisión dentro): Swift las abre.
    func testOpensBlobsSealedByWeb() throws {
        let f = try fixture("crypto")
        let seed = hexData(f["seeds"]!.arrayValue![0]["seedHex"]!.stringValue!)
        let key = CloudCrypto.dataKey(seed: seed)
        for b in f["blobs"]!.arrayValue! {
            let name = b["name"]!.stringValue!, rev = b["rev"]!.intValue!
            let r = try CloudCrypto.openProfile(b["blob"]!.stringValue!, key: key, rev: rev, knownV2: false)
            XCTAssertEqual(r.profile, b["plain"]!, name)
            XCTAssertEqual(r.sawV2, rev > 0, name)
        }
    }

    func testRevisionMismatchIsRejected() throws {
        let f = try fixture("crypto")
        let key = CloudCrypto.dataKey(seed: hexData(f["seeds"]!.arrayValue![0]["seedHex"]!.stringValue!))
        let b = f["blobs"]!.arrayValue![0]["blob"]!.stringValue!      // lleva rev 7 dentro
        XCTAssertThrowsError(try CloudCrypto.openProfile(b, key: key, rev: 8, knownV2: false)) { XCTAssertEqual($0 as? CloudCryptoError, .revision) }
        let old = f["blobs"]!.arrayValue![2]["blob"]!.stringValue!    // sin revisión dentro
        XCTAssertThrowsError(try CloudCrypto.openProfile(old, key: key, rev: 1, knownV2: true)) { XCTAssertEqual($0 as? CloudCryptoError, .revision) }
    }

    func testWrongKeyFails() throws {
        let f = try fixture("crypto")
        let other = CloudCrypto.dataKey(seed: hexData(f["seeds"]!.arrayValue![1]["seedHex"]!.stringValue!))
        XCTAssertThrowsError(try CloudCrypto.open(f["blobs"]!.arrayValue![0]["blob"]!.stringValue!, key: other))
    }

    func testSealOpenRoundTrip() throws {
        let key = CloudCrypto.dataKey(seed: CloudCrypto.newSeed())
        let p = profile([(1, -10), (2, -20.5)]).raw
        let blob = try CloudCrypto.seal(p, key: key, rev: 5)
        let r = try CloudCrypto.openProfile(blob, key: key, rev: 5, knownV2: true)
        XCTAssertEqual(r.profile, p)
        // La web también debe poder abrirlo: formato = 0x01, bandera gzip, IV de 12 bytes.
        let raw = Base64URL.decode(blob)!
        XCTAssertEqual(raw[0], 1); XCTAssertTrue(raw[1] == 0 || raw[1] == 1)
    }

    func testGzipRoundTripAndHeader() throws {
        let data = Data(String(repeating: "Plata ☕ ", count: 500).utf8)
        let z = try Gzip.compress(data)
        XCTAssertEqual(Array(z.prefix(3)), [0x1f, 0x8b, 8])
        XCTAssertLessThan(z.count, data.count)
        XCTAssertEqual(try Gzip.decompress(z), data)
        XCTAssertEqual(Gzip.crc32(Data("123456789".utf8)), 0xCBF43926)   // vector estándar de CRC-32
    }

    func testPhraseRejectsTypos() {
        let seed = CloudCrypto.newSeed()
        var w = Phrase.words(for: seed)
        XCTAssertEqual(Phrase.seed(from: w.joined(separator: " ")), seed)
        XCTAssertEqual(Phrase.seed(from: w.joined(separator: "  ").uppercased()), seed)    // mayúsculas y espacios de más
        // la suma de verificación (4 bits) detecta casi todos los cambios de una palabra; uno solo puede colarse por azar (1 de 16)
        var rejected = 0
        for i in w.indices {
            var t = w
            t[i] = t[i] == "zoo" ? "abandon" : "zoo"
            if Phrase.seed(from: t.joined(separator: " ")) == nil { rejected += 1 }
        }
        XCTAssertGreaterThanOrEqual(rejected, 6)
        XCTAssertNil(Phrase.seed(from: w.dropLast().joined(separator: " ")))               // faltan palabras
    }
}

final class PhraseSpanishTests: XCTestCase {
    func testSpanishListIsCleanAndComplete() {
        XCTAssertEqual(WordlistES.words.count, 2048)
        XCTAssertEqual(Set(WordlistES.words).count, 2048)
        XCTAssertTrue(WordlistES.words.allSatisfy { $0.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter } }, "sin tildes ni eñes")
        XCTAssertEqual(Set(WordlistES.words.map { String($0.prefix(4)) }).count, 2048, "las 4 primeras letras bastan para reconocerla")
    }

    /// La misma llave se puede escribir en español o en inglés.
    func testSameSeedInBothLanguages() {
        for _ in 0..<50 {
            let seed = CloudCrypto.newSeed()
            let es = Phrase.words(for: seed, language: .es), en = Phrase.words(for: seed, language: .en)
            XCTAssertEqual(es.count, 12)
            XCTAssertEqual(es.map { Phrase.wordIndex($0, language: .es) }, en.map { Phrase.wordIndex($0, language: .en) })
            XCTAssertEqual(Phrase.seed(from: es.joined(separator: " "), language: .es), seed)
            XCTAssertTrue(Phrase.seeds(from: es.joined(separator: " ")).contains(seed))
            XCTAssertTrue(Phrase.seeds(from: en.joined(separator: " ")).contains(seed))
        }
    }

    func testAccentsAndPrefixesAreForgiven() {
        XCTAssertEqual(Phrase.wordIndex("ÁBACO", language: .es), 0)
        XCTAssertEqual(Phrase.wordIndex("abac", language: .es), 0)
        XCTAssertEqual(Phrase.wordIndex("CAÑÓN", language: .es), Phrase.wordIndex("canon", language: .es))
        XCTAssertGreaterThanOrEqual(Phrase.wordIndex("canon", language: .es), 0)
    }
}

extension PhraseSpanishTests {
    /// Las frases en español e inglés que arma la web para estas semillas.
    func testPhrasesMatchWeb() throws {
        for p in try fixture("cloud")["phrases"]!.arrayValue! {
            let seed = hexData(p["seed"]!.stringValue!)
            XCTAssertEqual(Phrase.words(for: seed, language: .es).joined(separator: " "), p["es"]!.stringValue!)
            XCTAssertEqual(Phrase.words(for: seed, language: .en).joined(separator: " "), p["en"]!.stringValue!)
            XCTAssertEqual(Phrase.seed(from: p["es"]!.stringValue!, language: .es), seed)
        }
    }
}
