import XCTest
@testable import PlataCore

final class ProfileTests: XCTestCase {
    /// Un archivo con campos que Swift no conoce se lee y se vuelve a escribir sin perder nada.
    func testUnknownFieldsSurviveRoundTrip() throws {
        let json = """
        {"version":3,"demo":false,"settings":{"currency":"PEN","futuro":{"a":[1,2,{"b":null}]}},"accounts":[{"id":"bank","name":"Principal","balance":10.5,"campoNuevo":"x"}],
         "transactions":[{"id":7,"date":"2026-10-01","amount":-3.25,"category":"Comida","note":"café ☕","acc":"bank","imp":"ab12cd34","mod":1790000000000}],
         "budget":{"Comida":300},"cosaDeOtraVersion":[true,false,null,"t"]}
        """
        let p = try Profile(jsonData: Data(json.utf8))
        let again = try Profile(jsonData: p.jsonData())
        XCTAssertEqual(again, p)
        XCTAssertEqual(again.raw["cosaDeOtraVersion"], .array([.bool(true), .bool(false), .null, .string("t")]))
        XCTAssertEqual(again.raw["settings"]?["futuro"], p.raw["settings"]?["futuro"])
    }

    func testIntegersAreWrittenWithoutDecimals() throws {
        let p = Profile(raw: .object(["a": .number(5), "b": .number(5.25), "c": .number(1790000000000)]))
        let s = String(data: try p.raw.jsonData(sorted: true), encoding: .utf8)!
        XCTAssertEqual(s, #"{"a":5,"b":5.25,"c":1790000000000}"#)
    }

    func testReadModels() throws {
        let p = profile([(1, -41.8), (2, 100)])
        XCTAssertEqual(p.transactions.map(\.id), ["1", "2"])         // el id numérico de la web se lee como texto
        XCTAssertEqual(p.transactions[0].amount, -41.8)
        XCTAssertEqual(p.accounts.first?.id, "bank")
    }

    func testHasData() {
        XCTAssertFalse(Profile.empty.hasData)
        XCTAssertTrue(profile([(1, -1)]).hasData)
        var b = Profile.empty.raw; b["budget"] = .object(["Comida": .number(100)])
        XCTAssertTrue(Profile(raw: b).hasData)
    }

    func testNormalizedFillsMissingListsOnly() {
        let p = Profile(raw: .object(["version": .number(2), "transactions": .array([.object(["id": .number(1)])])])).normalized()
        XCTAssertEqual(p.raw["version"], .number(3))
        XCTAssertEqual(p.raw["transactions"]?.arrayValue?.count, 1)  // lo que había se respeta
        XCTAssertNotNil(p.raw["cards"]); XCTAssertNotNil(p.raw["settings"])
    }

    func testExportFileName() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let d = cal.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 7, minute: 5))!
        XCTAssertEqual(ProfileStore.exportFileName(d, calendar: cal), "plata-2026-10-08_07-05.json")
    }

    func testProfileStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let s = ProfileStore(directory: dir)
        XCTAssertNil(s.load())
        try s.save(profile([(1, -5)]))
        XCTAssertEqual(s.load()?.transactions.count, 1)
    }
}
