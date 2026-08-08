import XCTest
@testable import LibraryCompassCore

/// Nach dem Vollimport haben 144 von 1780 Büchern kein Bild. Sie sollen sich in einem
/// Rutsch durchsehen lassen, statt im Bestand verstreut zu liegen — deshalb eine
/// Sortierung, die sie nach vorn holt.
final class CoverSortTests: XCTestCase {

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

    private let books = [
        TestBook(title: "Mit Bild", coverPath: "9783442494033.jpg"),
        TestBook(title: "Ohne Bild B"),
        TestBook(title: "Auch mit Bild", coverPath: "t-abc.jpg"),
        TestBook(title: "Ohne Bild A", coverPath: ""),
    ]

    func testBooksWithoutCoverComeFirst() {
        let rows = BookQuery(sort: .ohneCover).apply(to: books)
        XCTAssertEqual(rows.map(\.title), ["Ohne Bild A", "Ohne Bild B", "Auch mit Bild", "Mit Bild"])
    }

    /// Innerhalb beider Gruppen alphabetisch — sonst ist die Liste beim Durchsehen
    /// nicht wiederfindbar.
    func testAlphabeticalWithinEachGroup() {
        let rows = BookQuery(sort: .ohneCover).apply(to: books)
        XCTAssertEqual(rows[0].title, "Ohne Bild A")
        XCTAssertEqual(rows[1].title, "Ohne Bild B")
        XCTAssertEqual(rows[2].title, "Auch mit Bild")
    }

    /// Ein leerer `coverPath` zählt wie keiner — beide Schreibweisen kommen im
    /// Bestand vor.
    func testEmptyStringCountsAsMissing() {
        let rows = BookQuery(sort: .ohneCover).apply(to: [
            TestBook(title: "Leer", coverPath: ""),
            TestBook(title: "Vorhanden", coverPath: "x.jpg")
        ])
        XCTAssertEqual(rows.first?.title, "Leer")
    }

    func testSortWorksTogetherWithFilterAndSearch() {
        let rows = BookQuery(filter: .alle, search: "ohne", sort: .ohneCover).apply(to: books)
        XCTAssertEqual(rows.map(\.title), ["Ohne Bild A", "Ohne Bild B"])
    }

    /// Die Auswahl in der Werkzeugleiste zeigt alle Fälle — der neue muss beschriftet sein.
    func testOptionIsOfferedAndLabelled() {
        XCTAssertTrue(LibrarySort.allCases.contains(.ohneCover))
        XCTAssertEqual(LibrarySort.ohneCover.title, "Ohne Cover zuerst")
    }

    /// Anti: Die übrigen Sortierungen bleiben unberührt.
    func testOtherSortsUnchanged() {
        XCTAssertEqual(BookQuery(sort: .titel).apply(to: books).first?.title, "Auch mit Bild")
    }
}
