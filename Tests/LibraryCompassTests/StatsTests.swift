import XCTest
@testable import LibraryCompassCore

/// ISC-13: Leseanteil, Bewertungs-Durchschnitt/-Verteilung und „zuletzt gelesen"-Reihenfolge.
final class StatsTests: XCTestCase {

    private func day(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f.date(from: iso)!
    }

    private lazy var fixture: [QueryTests.TestBook] = [
        .init(title: "A", rating: 5, readDate: day("2024-05-01")),
        .init(title: "B", rating: 4, readDate: day("2026-01-09")),
        .init(title: "C", rating: 4, readDate: day("2025-12-31")),
        .init(title: "D", rating: 3, readDate: day("2020-02-02")),
        .init(title: "E", rating: 2),
        .init(title: "F", rating: 0),
        .init(title: "G", rating: 0),
        .init(title: "H", rating: 0)
    ]

    func testCountsAndReadShare() {
        let stats = LibraryStats(books: fixture)
        XCTAssertEqual(stats.total, 8)
        XCTAssertEqual(stats.readCount, 4)
        XCTAssertEqual(stats.unreadCount, 4)
        XCTAssertEqual(stats.ratedCount, 5)
        XCTAssertEqual(stats.readPercent, 50)
    }

    func testAverageRatingOverRatedBooksOnly() {
        // (5+4+4+3+2) / 5 = 3,6
        XCTAssertEqual(LibraryStats(books: fixture).averageRating, 3.6, accuracy: 0.0001)
    }

    func testDistributionRunsFromFiveToOne() {
        let bars = LibraryStats(books: fixture).distribution
        XCTAssertEqual(bars.map(\.stars), [5, 4, 3, 2, 1])
        XCTAssertEqual(bars.map(\.count), [1, 2, 1, 1, 0])
    }

    func testEmptyLibraryHasZeroValues() {
        let stats = LibraryStats(books: [QueryTests.TestBook]())
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.readPercent, 0)
        XCTAssertEqual(stats.averageRating, 0)
        XCTAssertEqual(stats.distribution.map(\.count), [0, 0, 0, 0, 0])
    }

    func testRecentlyReadIsNewestFirstAndLimitedToFour() {
        let recent = LibraryStats.recentlyRead(fixture, limit: 4)
        XCTAssertEqual(recent.map(\.title), ["B", "C", "A", "D"])
    }

    func testRecentlyReadIgnoresUnreadBooks() {
        let recent = LibraryStats.recentlyRead(fixture, limit: 8)
        XCTAssertEqual(recent.count, 4)
    }
}
