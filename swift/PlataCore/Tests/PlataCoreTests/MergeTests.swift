import XCTest
@testable import PlataCore

final class MergeTests: XCTestCase {
    /// 90 casos generados ejecutando `mergeData` de la web. Swift debe producir exactamente el mismo perfil.
    func testMatchesWebMergeData() throws {
        let f = try fixture("merge")
        let now = f["now"]!.doubleValue!
        for (i, c) in f["cases"]!.arrayValue!.enumerated() {
            let base: JSONValue? = (c["base"]?.isNull ?? true) ? nil : c["base"]
            let got = Merge.profiles(base: base, local: c["local"]!, remote: c["remote"]!, now: now)
            let want = c["expected"]!
            if got != want {
                var diff: [String] = []
                for k in Set(got.objectValue!.keys).union(want.objectValue!.keys) where got[k] != want[k] { diff.append(k) }
                XCTFail("caso \(i): difiere en \(diff.sorted())")
            }
        }
    }

    func testBalancesAddUpWhenBothSidesChange() {
        func acct(_ bal: Double, _ mod: Double) -> JSONValue { .object(["id": .string("bank"), "balance": .number(bal), "mod": .number(mod)]) }
        func prof(_ a: JSONValue) -> JSONValue { var p = Profile.empty.raw; p["accounts"] = .array([a]); return p }
        let m = Merge.profiles(base: prof(acct(1000, 1)), local: prof(acct(900, 2)), remote: prof(acct(1050, 3)), now: 1_790_000_000_000)
        XCTAssertEqual(m["accounts"]!.arrayValue![0]["balance"]!.doubleValue, 950)   // 1000 −100 +50
    }

    func testDeletionOnOneSideIsRespected() {
        let tx: JSONValue = .object(["id": .number(1), "amount": .number(-5), "mod": .number(10)])
        func prof(_ items: [JSONValue]) -> JSONValue { var p = Profile.empty.raw; p["transactions"] = .array(items); return p }
        // Estaba en la base, el otro dispositivo lo borró y aquí no cambió: desaparece.
        let m = Merge.profiles(base: prof([tx]), local: prof([tx]), remote: prof([]), now: 1_790_000_000_000)
        XCTAssertEqual(m["transactions"], .array([]))
    }
}
