import XCTest
@testable import LibraryCompassCore

/// Der Katalog für den Taschen-Viewer. Er beantwortet unterwegs genau eine Frage —
/// **habe ich das schon?** — und ein falsches „hast du nicht" ist der teure Fehler,
/// denn danach kauft man doppelt.
final class LibraryWebTests: XCTestCase {

    private func book(_ title: String, _ author: String = "", isbn: String = "",
                      read: Bool = false, rating: Int = 0, cover: String? = nil) -> Book {
        Book(isbn: isbn, title: title, author: author, coverPath: cover, rating: rating,
             readDate: read ? Date(timeIntervalSince1970: 1_700_000_000) : nil)
    }

    private var date: Date { Date(timeIntervalSince1970: 1_754_800_000) }

    /// Die ISBN steht kanonisch drin, damit ein gescannter Strichcode (immer EAN-13)
    /// auch einen Eintrag trifft, der als ISBN-10 erfasst wurde.
    func testISBNIsStoredCanonically() {
        let c = LibraryWeb.catalogue([book("Cobra", "Forsyth", isbn: "344247776X")], date: date)
        XCTAssertEqual(c.books.first?.i, "9783442477760")
    }

    func testBookWithoutISBNKeepsAnEmptyField() {
        XCTAssertEqual(LibraryWeb.catalogue([book("Ohne Nummer")], date: date).books.first?.i, "")
    }

    /// Titellose Einträge ans Ende — sonst ist das Erste, was die Seite zeigt, eine
    /// leere Zeile.
    func testUntitledEntriesSortLast() {
        let c = LibraryWeb.catalogue([book(""), book("Anfang"), book("")], date: date)
        XCTAssertEqual(c.books.map(\.t), ["Anfang", "", ""])
    }

    func testSortsByTitleIgnoringCase() {
        let c = LibraryWeb.catalogue([book("zebra"), book("Anfang"), book("Mitte")], date: date)
        XCTAssertEqual(c.books.map(\.t), ["Anfang", "Mitte", "zebra"])
    }

    /// Gelesen wird als Ja/Nein übertragen, nicht als Datum. Wann jemand ein Buch
    /// gelesen hat, geht die Hosentasche nichts an — für die Kauffrage zählt nur, ob.
    func testReadIsABooleanNotADate() {
        let c = LibraryWeb.catalogue([book("A", read: true), book("B", read: false)], date: date)
        XCTAssertEqual(c.books.map(\.g), [true, false])
    }

    func testCoverIsNilWhenThereIsNone() {
        let c = LibraryWeb.catalogue([book("A"), book("B", cover: "x.jpg")], date: date)
        XCTAssertNil(c.books[0].c)
        XCTAssertEqual(c.books[1].c, "x.jpg")
    }

    /// Jedes Bild nur einmal — zwei Erfassungen desselben Buchs teilen sich die Datei.
    func testCoverListHasNoDuplicates() {
        let c = LibraryWeb.catalogue([book("A", cover: "x.jpg"), book("B", cover: "x.jpg"),
                                      book("C", cover: "y.jpg"), book("D")], date: date)
        XCTAssertEqual(LibraryWeb.coverFiles(c), ["x.jpg", "y.jpg"])
    }

    /// Der Stand gehört in die Datei: die Seite zeigt ihn an, damit niemand einem alten
    /// Bestand vertraut, ohne es zu merken.
    func testExportDateTravelsWithTheCatalogue() {
        XCTAssertEqual(LibraryWeb.catalogue([book("A")], date: date).exported, "2025-08-10")
    }

    /// Zwei Exporte desselben Bestands ergeben dieselbe Datei — sonst überträgt jeder
    /// Abgleich alles neu.
    func testJSONIsStable() throws {
        let one = try LibraryWeb.json(LibraryWeb.catalogue([book("A", isbn: "9783442477760")], date: date))
        let two = try LibraryWeb.json(LibraryWeb.catalogue([book("A", isbn: "9783442477760")], date: date))
        XCTAssertEqual(one, two)
    }

    /// Der Katalog muss klein bleiben — er wird übers Mobilnetz geladen.
    func testCatalogueStaysSmall() throws {
        let books = (0..<1840).map { book("Ein Titel Nummer \($0)", "Verfasser Name", isbn: "9783442477760") }
        let bytes = try LibraryWeb.json(LibraryWeb.catalogue(books, date: date)).count
        XCTAssertLessThan(bytes, 400_000, "1840 Bücher sollten unter 400 KB bleiben, sind \(bytes)")
    }
}
