import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Dieselbe ISBN zweimal eingeben darf keine Dublette erzeugen — sonst legt ein
/// zweiter Versuch nach fehlgeschlagenem Lookup ein weiteres leeres Buch an.
@MainActor
final class DuplicateISBNTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        ModelContext(try LibraryStore.inMemoryContainer())
    }

    func testFindsExistingBookByISBN() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783785728390", title: "Toxin: Thriller", author: "Lange, Kathrin"))
        try context.save()

        let found = LibraryStore.book(isbn: "9783785728390", in: context)
        XCTAssertEqual(found?.title, "Toxin: Thriller")
    }

    func testMatchesRegardlessOfSeparators() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783785728390", title: "Toxin: Thriller"))
        try context.save()

        XCTAssertNotNil(LibraryStore.book(isbn: "978-3-7857-2839-0", in: context))
        XCTAssertNotNil(LibraryStore.book(isbn: " 9783785728390 ", in: context))
    }

    func testUnknownISBNYieldsNil() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783785728390", title: "Toxin: Thriller"))
        try context.save()

        XCTAssertNil(LibraryStore.book(isbn: "9780345391803", in: context))
    }

    func testEmptyISBNNeverMatches() throws {
        let context = try makeContext()
        context.insert(Book(isbn: "", title: "Buch ohne ISBN"))
        try context.save()

        XCTAssertNil(LibraryStore.book(isbn: "", in: context))
    }
}
