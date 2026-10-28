import XCTest
@testable import PlataCore

final class MoneyTests: XCTestCase {
    func testWholeRoundsLikeJS() {
        XCTAssertEqual(Money.whole(1234.5, "USD"), "$1,235")
        XCTAssertEqual(Money.whole(-1234.5, "USD"), "−$1,234")          // Math.round(-1234.5) = -1234
        XCTAssertEqual(Money.whole(0, "USD"), "$0")
        XCTAssertEqual(Money.whole(-0.4, "USD"), "$0")
        XCTAssertEqual(Money.whole(1_234_567, "EUR"), "€1,234,567")
        XCTAssertEqual(Money.whole(12, "PEN"), "S/\u{00A0}12")
    }

    func testExactUsesCurrencyDecimals() {
        XCTAssertEqual(Money.exact(1234.5, "USD"), "$1,234.50")
        XCTAssertEqual(Money.exact(-5, "USD"), "$5.00")
        XCTAssertEqual(Money.exact(1500.4, "JPY"), "¥1,500")
        XCTAssertEqual(Money.signed(-3.2, "USD"), "−$3.20")
        XCTAssertEqual(Money.signed(3.2, "USD"), "+$3.20")
    }

    func testSymbolWithTrailingSpaceUsesNonBreakingSpace() {
        XCTAssertEqual(Money.symbol("YER"), "YER\u{00A0}")
        XCTAssertEqual(Money.symbol("XQ", custom: "XQ"), "XQ\u{00A0}")
        XCTAssertEqual(Money.symbol("ZZZ"), "$")
    }
}
