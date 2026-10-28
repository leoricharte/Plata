import XCTest
@testable import PlataCore

final class SyncEngineTests: XCTestCase {
    let seed = hexData("000102030405060708090a0b0c0d0e0f")

    func testFirstSyncUploadsAndRevisionTravelsEncrypted() async throws {
        let cloud = FakeCloud()
        let (engine, store) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        let r = await engine.sync(local: profile([(1, -10)]))
        XCTAssertEqual(r, .upToDate(rev: 1))
        XCTAssertEqual(cloud.rev, 1)
        XCTAssertEqual(store.loadBase(), profile([(1, -10)]).raw)
        // El servidor solo ve texto cifrado, y dentro va la revisión.
        let opened = try CloudCrypto.open(cloud.blob!, key: CloudCrypto.dataKey(seed: seed))
        XCTAssertEqual(opened["plata"]?.intValue, 2); XCTAssertEqual(opened["rev"]?.intValue, 1)
    }

    func testSecondDeviceWithoutDataLoadsTheCloud() async throws {
        let cloud = FakeCloud()
        let (a, _) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        _ = await a.sync(local: profile([(1, -10), (2, -5)]))
        let (b, _) = makeEngine(cloud: cloud, seed: seed, device: "Android")
        let r = await b.sync(local: .empty, why: .first)
        XCTAssertEqual(r, .apply(profile([(1, -10), (2, -5)]).raw, rev: 1))
        XCTAssertEqual(cloud.puts, 1)                    // un dispositivo vacío nunca pisa la nube
    }

    func testBothDevicesEditAndMerge() async throws {
        let cloud = FakeCloud()
        let (a, _) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        let (b, _) = makeEngine(cloud: cloud, seed: seed, device: "Windows")
        let base = profile([(1, -10)])
        _ = await a.sync(local: base)
        _ = await b.sync(local: .empty, why: .first)     // b adopta la base
        // a agrega el movimiento 2 y sube; b agrega el 3 y sincroniza
        _ = await a.sync(local: profile([(1, -10), (2, -20)]))
        let r = await b.sync(local: profile([(1, -10), (3, -30)]))
        guard case .apply(let merged, let rev) = r else { return XCTFail("esperaba .apply, llegó \(r)") }
        XCTAssertEqual(rev, 3)
        let ids = Set(Profile(raw: merged).transactions.map(\.id))
        XCTAssertEqual(ids, ["1", "2", "3"])
        XCTAssertEqual(cloud.rev, 3)
    }

    func testDifferentDataWithoutBaseAsksWhatToKeep() async throws {
        let cloud = FakeCloud()
        let (a, _) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        _ = await a.sync(local: profile([(1, -10)]))
        let (b, _) = makeEngine(cloud: cloud, seed: seed, device: "Mac")
        let r = await b.sync(local: profile([(9, -99)]), why: .first)
        guard case .needsChoice(let remote, let rev, let next) = r else { return XCTFail("esperaba .needsChoice, llegó \(r)") }
        XCTAssertEqual(rev, 1); XCTAssertEqual(next, 2)
        XCTAssertEqual(Profile(raw: remote).transactions.map(\.id), ["1"])
        // "Combinar los dos": sube con la revisión cifrada dentro, así otros dispositivos pueden abrirla.
        let m = await b.chooseMerge(local: profile([(9, -99)]), remote: remote, rev: rev, next: next)
        guard case .apply(let merged, _) = m else { return XCTFail("\(m)") }
        XCTAssertEqual(Set(Profile(raw: merged).transactions.map(\.id)), ["1", "9"])
        let again = await a.sync(local: profile([(1, -10)]))     // el primer dispositivo debe poder abrir la copia combinada
        guard case .apply = again else { return XCTFail("a no pudo abrir la copia combinada: \(again)") }
    }

    func testExpiredSessionAndWrongWriteKey() async throws {
        let cloud = FakeCloud()
        let (a, _) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        _ = await a.sync(local: profile([(1, -10)]))
        cloud.tokenValid = false
        let r1 = await a.sync(local: profile([(1, -10), (2, -1)]))
        XCTAssertEqual(r1, .loggedOut)
        cloud.tokenValid = true
        // Otro dispositivo con otra frase que cree estar al día (misma revisión y base): al subir, la nube no se deja pisar.
        let (other, otherStore) = makeEngine(cloud: cloud, seed: hexData("ffffffffffffffffffffffffffffffff"), device: "otro")
        var os = otherStore.loadState(); os.rev = 1; os.last = 1_790_000_000_000; otherStore.saveState(os)
        otherStore.saveBase(profile([(1, -10)]).raw)
        let r2 = await other.sync(local: profile([(1, -10), (5, -1)]))
        XCTAssertEqual(r2, .failed(.writeKey))
        XCTAssertEqual(cloud.rev, 1)
    }

    func testDemoNeverSyncs() async {
        let cloud = FakeCloud()
        let (a, _) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        var d = profile([(1, -1)]).raw; d["demo"] = .bool(true)
        let r = await a.sync(local: Profile(raw: d))
        XCTAssertEqual(r, .demoPaused)
        XCTAssertEqual(cloud.puts, 0)
    }

    func testCloudNeverGoesBackwards() async throws {
        let cloud = FakeCloud()
        let (a, store) = makeEngine(cloud: cloud, seed: seed, device: "iPhone")
        _ = await a.sync(local: profile([(1, -10)]))
        var st = store.loadState(); st.rev = 9; st.v2 = true; store.saveState(st)    // este dispositivo ya vio la revisión 9
        let r = await a.sync(local: profile([(1, -10)]))
        XCTAssertEqual(r, .failed(.revision))                                         // el servidor devuelve la 1: copia vieja
    }
}
