import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Regel des Nutzers (2026-08-08): „Alle Bücher, die ich erfasse, sind immer gelesen,
/// sonst werden sie nicht erfasst." Der Import hält es schon so (`readDate := addedDate`);
/// beim Erfassen von Hand fehlte es — „Toxin" landete ohne Lesedatum auf Platz 1782 von
/// 1782 der Gelesen-Sortierung.
@MainActor
final class AddedBooksAreReadTests: XCTestCase {

    func testNewBookCountsAsReadOnTheDayItWasAdded() throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        let added = Date(timeIntervalSince1970: 1_700_000_000)

        let book = NewBook.make(isbn: "9783442494033", addedDate: added)
        context.insert(book)
        try context.save()

        XCTAssertEqual(book.readDate, added, "erfasst heißt gelesen")
        XCTAssertEqual(book.addedDate, added)
    }

    /// Damit taucht das Buch sofort oben auf — der eigentliche Zweck der Regel.
    func testNewBookIsFoundByTheLastReadSort() throws {
        let old = Book(isbn: "1", title: "Alt", readDate: Date(timeIntervalSince1970: 0),
                       addedDate: Date(timeIntervalSince1970: 0))
        let fresh = NewBook.make(isbn: "2", addedDate: Date(timeIntervalSince1970: 1_700_000_000))
        fresh.title = "Frisch erfasst"

        let rows = BookQuery(sort: .zuletztGelesen).apply(to: [old, fresh])
        XCTAssertEqual(rows.first?.title, "Frisch erfasst")
    }

    /// Anti: Ein bereits vorhandenes Lesedatum wird nicht überschrieben — wer ein
    /// eigenes Datum gesetzt hat, behält es.
    func testExistingReadDateIsKept() throws {
        let own = Date(timeIntervalSince1970: 1_000_000)
        let book = Book(isbn: "3", title: "Eigenes Datum", readDate: own, addedDate: Date())
        XCTAssertEqual(book.readDate, own)
    }
}
