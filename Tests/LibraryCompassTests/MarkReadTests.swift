import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Importierte Bücher gelten als gelesen (User-Entscheid 2026-08-06): Der Bestand
/// aus Delicious Library steht im Regal, weil er gelesen wurde. Als Datum dient
/// das Erfassungsdatum — ein einmaliges Datum genügt.
@MainActor
final class MarkReadTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        ModelContext(try LibraryStore.inMemoryContainer())
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: text)!
    }

    // MARK: Neuer Import

    func testImportMarksBooksAsRead() throws {
        let context = try makeContext()
        let parsed = ParseResult(books: [ImportedBook(isbn: "9783442494033",
                                                      title: "Kill for me",
                                                      addedDate: date("2024-11-14"))],
                                 skippedNonBooks: 0, errors: [])

        _ = try LibraryImporter.importBooks(parsed, into: context)

        let book = try XCTUnwrap(LibraryStore.book(isbn: "9783442494033", in: context))
        XCTAssertEqual(book.readDate, date("2024-11-14"))
    }

    // MARK: Bestand nachziehen

    func testMarksExistingBooksAsRead() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "1", title: "Eins", addedDate: date("2020-01-01")))
        context.insert(Book(isbn: "2", title: "Zwei", addedDate: date("2021-06-15")))
        try context.save()

        let count = ReadDates.markAllAsRead(in: context)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(LibraryStore.book(isbn: "1", in: context)?.readDate, date("2020-01-01"))
        XCTAssertEqual(LibraryStore.book(isbn: "2", in: context)?.readDate, date("2021-06-15"))
    }

    func testKeepsDatesThatAreAlreadySet() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "1", title: "Eins",
                            readDate: date("2019-05-05"), addedDate: date("2020-01-01")))
        try context.save()

        let count = ReadDates.markAllAsRead(in: context)

        XCTAssertEqual(count, 0, "Eigene Angaben bleiben unangetastet")
        XCTAssertEqual(LibraryStore.book(isbn: "1", in: context)?.readDate, date("2019-05-05"))
    }

    func testRunningTwiceChangesNothingTheSecondTime() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "1", title: "Eins", addedDate: date("2020-01-01")))
        try context.save()

        XCTAssertEqual(ReadDates.markAllAsRead(in: context), 1)
        XCTAssertEqual(ReadDates.markAllAsRead(in: context), 0)
    }
}
