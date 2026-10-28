import XCTest
@testable import PlataCore

final class MigrationTests: XCTestCase {
    /// Dónde difieren dos valores (ruta del primer cambio), para que el fallo diga algo útil.
    private func firstDiff(_ a: JSONValue, _ b: JSONValue, _ path: String = "") -> String? {
        if a == b { return nil }
        switch (a, b) {
        case (.object(let x), .object(let y)):
            for k in Set(x.keys).union(y.keys).sorted() {
                if x[k] != y[k] {
                    guard let l = x[k], let r = y[k] else { return "\(path).\(k): Swift=\(String(describing: x[k])) web=\(String(describing: y[k]))" }
                    return firstDiff(l, r, path + "." + k)
                }
            }
            return path
        case (.array(let x), .array(let y)):
            if x.count != y.count { return "\(path): \(x.count) elementos en Swift, \(y.count) en la web" }
            for i in x.indices where x[i] != y[i] { return firstDiff(x[i], y[i], path + "[\(i)]") }
            return path
        default:
            return "\(path): Swift=\(a) web=\(b)"
        }
    }

    func testRawProfilesMigrateLikeTheWeb() throws {
        let f = try fixture("engine")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let got = try Migration.migrate(c["raw"]!)
            if let d = firstDiff(got, c["migrated"]!) { XCTFail("perfil \(i): \(d)") }
        }
    }

    func testOddFilesMigrateLikeTheWeb() throws {
        let f = try fixture("migrate")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            if let want = c["migrated"], !want.isNull {
                do {
                    let got = try Migration.migrate(c["raw"]!)
                    if let d = firstDiff(got, want) { XCTFail("caso \(i): \(d)") }
                } catch { XCTFail("caso \(i): Swift falló (\(error)) y la web no") }
            } else {
                XCTAssertThrowsError(try Migration.migrate(c["raw"]!), "caso \(i): la web rechaza este archivo")
            }
        }
    }

    func testLegacyVersionIsRejected() {
        let raw: JSONValue = .object(["version": .number(2), "transactions": .array([]), "cards": .array([]), "accounts": .array([])])
        XCTAssertThrowsError(try Migration.migrate(raw)) { XCTAssertEqual($0 as? MigrationError, .legacyFormat) }
    }
}
