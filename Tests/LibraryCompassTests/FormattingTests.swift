import XCTest
@testable import LibraryCompassCore

/// Zahlen und Daten immer `de-DE` (TOKENS §3): „1.800", „Ø 3,6", „09.08.2026".
final class FormattingTests: XCTestCase {

    func testGroupedNumberUsesGermanThousandsSeparator() {
        XCTAssertEqual(LCFormat.number(1800), "1.800")
        XCTAssertEqual(LCFormat.number(7), "7")
    }

    func testAverageUsesGermanDecimalComma() {
        XCTAssertEqual(LCFormat.average(3.64), "3,6")
        XCTAssertEqual(LCFormat.average(4.0), "4,0")
    }

    func testDateIsDayMonthYear() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 9
        components.timeZone = TimeZone.current
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(LCFormat.date(date), "09.08.2026")
    }

    func testMissingDateIsDash() {
        XCTAssertEqual(LCFormat.date(nil), "–")
    }

    func testStarsRendersFilledAndEmpty() {
        XCTAssertEqual(LCFormat.stars(0), "")
        XCTAssertEqual(LCFormat.stars(3), "★★★☆☆")
        XCTAssertEqual(LCFormat.stars(5), "★★★★★")
    }
}
