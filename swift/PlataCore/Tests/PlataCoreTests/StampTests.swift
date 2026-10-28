import XCTest
@testable import PlataCore

final class StampTests: XCTestCase {
    /// Secuencias de ediciones generadas con `syncStamp` de la web: Swift debe dejar las mismas marcas `mod`, lápidas y `fmod`.
    func testMatchesWebSyncStamp() throws {
        let f = try fixture("stamp")
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let stamper = SyncStamper()
            for (n, s) in c["steps"]!.arrayValue!.enumerated() {
                var p = s["before"]!
                stamper.stamp(&p, now: s["now"]!.doubleValue!)
                let want = s["after"]!
                // `tomb` se compara como conjunto por pares (colección, id): con la misma hora el orden depende del orden de claves de la web.
                func tombKeys(_ v: JSONValue?) -> [String] { (v?.arrayValue ?? []).map { "\($0["c"]!.stringValue!)|\(JS.string($0["id"]!))|\($0["t"]!.doubleValue!)" }.sorted() }
                XCTAssertEqual(tombKeys(p["tomb"]), tombKeys(want["tomb"]), "caso \(i) paso \(n): lápidas")
                XCTAssertEqual(p["fmod"], want["fmod"], "caso \(i) paso \(n): fmod")
                for col in SyncStamper.collections where p[col] != want[col] {
                    XCTAssertEqual(p[col], want[col], "caso \(i) paso \(n): \(col)")
                }
                for k in ["settings", "budget", "cats", "ovr", "halfSnaps", "history", "recurring"] { XCTAssertEqual(p[k], want[k], "caso \(i) paso \(n): \(k)") }
            }
        }
    }

    func testFirstPassOnlyTakesASnapshot() {
        var p = Profile.empty.raw
        p["transactions"] = .array([.object(["id": .number(1), "amount": .number(-5)])])
        let st = SyncStamper()
        st.stamp(&p, now: 1000)
        XCTAssertEqual(p["transactions"]!.arrayValue![0]["mod"], .number(0))
        XCTAssertEqual(p["tomb"], .array([]))
        // Un cambio posterior sí deja marca; un borrado deja lápida.
        p["transactions"] = .array([.object(["id": .number(1), "amount": .number(-9), "mod": .number(0)])])
        st.stamp(&p, now: 2000)
        XCTAssertEqual(p["transactions"]!.arrayValue![0]["mod"], .number(2000))
        p["transactions"] = .array([])
        st.stamp(&p, now: 3000)
        XCTAssertEqual(p["tomb"]!.arrayValue!.count, 1)
        XCTAssertEqual(p["tomb"]!.arrayValue![0]["t"], .number(3000))
    }
}
