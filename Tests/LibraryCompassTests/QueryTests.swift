import XCTest
@testable import LibraryCompassCore

/// Filter → Suche → Sortierung → Limit (README §7), ohne Genre-Anteil.
final class QueryTests: XCTestCase {

    struct TestBook: BookFields {
        var isbn = ""
        var title = ""
        var author = ""
        var coverPath: String? = nil
        var rating = 0
        var comment = ""
        var readDate: Date? = nil
        var addedDate = Date(timeIntervalSince1970: 0)
        var year: Int? = nil
        var pages: Int? = nil
    }

    private func day(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f.date(from: iso)!
    }

    private lazy var books: [TestBook] = [
        TestBook(title: "Zebra", author: "Meier, Anna", rating: 5, readDate: day("2024-01-05"), year: 1999),
        TestBook(title: "Äpfel", author: "Zorn, Bert", rating: 0, year: 2015),
        TestBook(title: "Banane", author: "Albers, Cem", rating: 3, readDate: day("2026-07-01"), year: 2015),
        TestBook(title: "Comet", author: "albers, Dora", rating: 3, year: 1980)
    ]

    func testFilterAlleKeepsEverything() {
        XCTAssertEqual(BookQuery(filter: .alle).apply(to: books).count, 4)
    }

    func testFilterGelesenAndUngelesen() {
        XCTAssertEqual(Set(BookQuery(filter: .gelesen).apply(to: books).map(\.title)), ["Zebra", "Banane"])
        XCTAssertEqual(Set(BookQuery(filter: .ungelesen).apply(to: books).map(\.title)), ["Äpfel", "Comet"])
    }

    func testFilterBewertet() {
        XCTAssertEqual(Set(BookQuery(filter: .bewertet).apply(to: books).map(\.title)),
                       ["Zebra", "Banane", "Comet"])
    }

    func testSearchMatchesTitleAndAuthorCaseInsensitiveSubstring() {
        XCTAssertEqual(BookQuery(search: "ban").apply(to: books).map(\.title), ["Banane"])
        XCTAssertEqual(Set(BookQuery(search: "ALBERS").apply(to: books).map(\.title)), ["Banane", "Comet"])
        XCTAssertEqual(BookQuery(search: "  ").apply(to: books).count, 4, "leere Suche filtert nicht")
    }

    func testSortTitleUsesGermanCollation() {
        XCTAssertEqual(BookQuery(sort: .titel).apply(to: books).map(\.title),
                       ["Äpfel", "Banane", "Comet", "Zebra"])
    }

    func testSortAuthorFallsBackToTitle() {
        XCTAssertEqual(BookQuery(sort: .autor).apply(to: books).map(\.title),
                       ["Banane", "Comet", "Zebra", "Äpfel"])
    }

    func testSortYearDescending() {
        let titles = BookQuery(sort: .jahr).apply(to: books).map(\.title)
        XCTAssertEqual(titles, ["Äpfel", "Banane", "Zebra", "Comet"])
    }

    func testSortRatingDescendingThenTitle() {
        XCTAssertEqual(BookQuery(sort: .bewertung).apply(to: books).map(\.title),
                       ["Zebra", "Banane", "Comet", "Äpfel"])
    }

    func testSortLastReadPutsUnreadLast() {
        XCTAssertEqual(BookQuery(sort: .zuletztGelesen).apply(to: books).map(\.title),
                       ["Banane", "Zebra", "Äpfel", "Comet"])
    }

    func testEvaluationOrderFilterThenSearchThenSort() {
        let query = BookQuery(filter: .bewertet, search: "a", sort: .titel)
        XCTAssertEqual(query.apply(to: books).map(\.title), ["Banane", "Comet", "Zebra"])
    }

    func testFilterCountsIgnoreSearch() {
        let counts = BookQuery(search: "zebra").counts(for: books)
        XCTAssertEqual(counts.alle, 4)
        XCTAssertEqual(counts.gelesen, 2)
        XCTAssertEqual(counts.ungelesen, 2)
        XCTAssertEqual(counts.bewertet, 3)
    }

    func testFilterTitlesAreGerman() {
        XCTAssertEqual(LibraryFilter.allCases.map(\.title),
                       ["Alle Bücher", "Gelesen", "Ungelesen", "Bewertet"])
        XCTAssertEqual(LibrarySort.allCases.map(\.title),
                       ["Titel A–Z", "Autor A–Z", "Jahr, neueste zuerst",
                        "Bewertung, beste zuerst", "Zuletzt gelesen"])
    }
}
