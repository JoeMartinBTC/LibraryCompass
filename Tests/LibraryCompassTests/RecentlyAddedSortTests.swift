import XCTest
@testable import LibraryCompassCore

/// Ein gerade erfasstes Buch war in **keiner** Sortierung zu finden (2026-08-08):
/// „Jahr" meint das **Erscheinungsjahr** — ein Roman von 2023, heute erfasst, steht
/// zwischen den anderen 2023ern. Und „Zuletzt gelesen" hilft nicht, solange kein
/// Lesedatum eingetragen ist; ohne eines landet das Buch ganz hinten.
final class RecentlyAddedSortTests: XCTestCase {

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

    private lazy var books = [
        TestBook(title: "Alt, aber neu erschienen", addedDate: day("2024-10-13"), year: 2026),
        TestBook(title: "Heute erfasst, ungelesen", addedDate: day("2026-08-08"), year: 2023),
        TestBook(title: "Gestern erfasst", addedDate: day("2026-08-07"), year: 1999),
    ]

    func testRecentlyAddedPutsTodaysBookFirst() {
        let rows = BookQuery(sort: .zuletztHinzugefügt).apply(to: books)
        XCTAssertEqual(rows.map(\.title),
                       ["Heute erfasst, ungelesen", "Gestern erfasst", "Alt, aber neu erschienen"])
    }

    /// Ohne Lesedatum bleibt das Buch auffindbar — das ist der Kern des Ganzen.
    func testWorksWithoutAnyReadDate() {
        let rows = BookQuery(sort: .zuletztHinzugefügt).apply(to: books)
        XCTAssertNil(rows.first?.readDate)
        XCTAssertEqual(rows.first?.title, "Heute erfasst, ungelesen")
    }

    /// Gleiches Datum → alphabetisch, damit die Liste stabil bleibt.
    func testSameDayIsOrderedByTitle() {
        let sameDay = [
            TestBook(title: "Zebra", addedDate: day("2026-08-08")),
            TestBook(title: "Anton", addedDate: day("2026-08-08"))
        ]
        XCTAssertEqual(BookQuery(sort: .zuletztHinzugefügt).apply(to: sameDay).map(\.title),
                       ["Anton", "Zebra"])
    }

    /// Das Erscheinungsjahr sortiert weiterhin nach Erscheinungsjahr — hier lag nie
    /// ein Fehler, nur eine missverständliche Beschriftung.
    func testYearSortStillUsesThePublicationYear() {
        XCTAssertEqual(BookQuery(sort: .jahr).apply(to: books).first?.title, "Alt, aber neu erschienen")
    }

    func testLabelsSayWhichDateIsMeant() {
        XCTAssertEqual(LibrarySort.jahr.title, "Erscheinungsjahr, neueste zuerst")
        XCTAssertEqual(LibrarySort.zuletztHinzugefügt.title, "Zuletzt hinzugefügt")
        XCTAssertTrue(LibrarySort.allCases.contains(.zuletztHinzugefügt))
    }
}
