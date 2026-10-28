import XCTest
@testable import PlataCore

final class OnboardingTests: XCTestCase {
    let today = LocalDate(year: 2026, month0: 9, day: 28)

    func testStepsByLevel() {
        XCTAssertEqual(Onboarding.steps(level: "simple"), ["name", "cur", "acc", "look"])
        XCTAssertEqual(Onboarding.steps(level: "extended").count, 11)
        XCTAssertTrue(Onboarding.steps(level: "standard", importer: true).contains("imp"))
    }

    func testGuessCurrency() {
        XCTAssertEqual(Onboarding.guessCurrencies(timeZone: "America/Lima", region: "PE"), ["PEN", "USD"])
        XCTAssertEqual(Onboarding.guessCurrencies(timeZone: "Europe/Madrid", region: "ES"), ["EUR"])
        XCTAssertEqual(Onboarding.guessCurrencies(timeZone: "Nowhere/None", region: "GB"), ["GBP"])
        XCTAssertEqual(Onboarding.guessCurrencies(timeZone: "America/Argentina/Cordoba", region: ""), ["ARS"])
    }

    func testBuildStandard() {
        var w = WelcomeAnswers()
        w.first = " Ana "; w.bal = "1200,5"; w.incAmt = "2000"; w.incDate = "2026-11-01"; w.bud = ["Comida": "300", "Ocio": ""]
        var n = 0
        let p = Onboarding.build(w, today: today) { n += 1; return "id\(n)" }
        XCTAssertEqual(p["settings"]?["first"]?.stringValue, "Ana")
        XCTAssertEqual(p["accounts"]?.arrayValue?.first?["balance"]?.doubleValue, 1200.5)
        let inc = p["expected_income"]?.arrayValue?.first
        XCTAssertEqual(inc?["amount"]?.doubleValue, 2000)
        XCTAssertEqual(inc?["repeat"]?.stringValue, "m")
        XCTAssertEqual(p["budget"]?["Comida"]?.doubleValue, 300)
        XCTAssertNil(p["budget"]?["Ocio"])
        XCTAssertTrue((p["cards"]?.arrayValue ?? []).isEmpty)
    }

    func testBuildExtendedBiweeklyJob() {
        var w = WelcomeAnswers()
        w.level = "extended"; w.incKind = "j"; w.jRate = "20"; w.jFreq = "b"; w.jDate = "2026-11-05"
        w.dbName = "Visa"; w.dbBal = "500"; w.gName = "Viaje"; w.gGoal = "1000"; w.fxAmt = "800"; w.fxRep = "q"
        var n = 0
        let p = Onboarding.build(w, today: today) { n += 1; return "id\(n)" }
        XCTAssertEqual(p["jobs"]?.arrayValue?.count, 1)
        XCTAssertNotNil(p["expected_income"]?.arrayValue?.first?["job"])
        XCTAssertEqual(p["cards"]?.arrayValue?.first?["name"]?.stringValue, "Visa")
        XCTAssertEqual(p["savings"]?.arrayValue?.first?["goal"]?.doubleValue, 1000)
        let fx = p["expected_expense"]?.arrayValue?.first
        XCTAssertEqual(fx?["repeat"]?.stringValue?.hasPrefix("q"), true)
        XCTAssertEqual(fx?["cat"]?.stringValue, "Alquiler")
    }
}
