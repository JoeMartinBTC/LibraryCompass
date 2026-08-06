import XCTest
import SwiftData
@testable import LibraryCompassCore

/// ISC-3 (Sample vollständig), ISC-4 (idempotent), ISC-10 (Quelldatei unverändert).
final class ImportSampleTests: XCTestCase {

    func testSampleImportsAllEntriesWithRatingsAndNotes() throws {
        try Fixtures.requireFile(Fixtures.sampleURL)
        let context = try Fixtures.freshContext()

        let report = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: context)

        print("IMPORT-REPORT: " + report.summary)
        XCTAssertEqual(report.imported, 108)
        XCTAssertEqual(report.errors, 0)
        XCTAssertEqual(report.summary, "imported=108 errors=0")

        let books = try context.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 108)
        XCTAssertEqual(books.filter { $0.rating > 0 }.count, 105)
        XCTAssertEqual(books.filter { !$0.comment.isEmpty }.count, 83)
        XCTAssertEqual(books.filter { !$0.title.isEmpty }.count, 106)
        // Importierte Bücher gelten als gelesen (Entscheid 2026-08-06). Delicious Library
        // pflegte `hasExperienced` nie, deshalb dient das Erfassungsdatum als Gelesen-Datum.
        XCTAssertEqual(books.filter { $0.readDate != nil }.count, 108)
        XCTAssertEqual(books.filter { $0.readDate == $0.addedDate }.count, 108)
    }

    func testSecondImportOfSameFileCreatesNoDuplicates() throws {
        try Fixtures.requireFile(Fixtures.sampleURL)
        let context = try Fixtures.freshContext()

        let first = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: context)
        let second = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: context)

        XCTAssertEqual(first.imported, 108)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skippedDuplicates, 108)
        XCTAssertEqual(second.errors, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 108)
    }

    func testImportKeepsOwnEditsOfExistingBooks() throws {
        try Fixtures.requireFile(Fixtures.sampleURL)
        let context = try Fixtures.freshContext()
        _ = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: context)

        let book = try XCTUnwrap(try context.fetch(FetchDescriptor<Book>()).first)
        book.rating = 5
        book.comment = "eigene Notiz"
        try context.save()

        _ = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: context)

        let again = try XCTUnwrap(try context.fetch(FetchDescriptor<Book>())
            .first { $0.persistentModelID == book.persistentModelID })
        XCTAssertEqual(again.rating, 5)
        XCTAssertEqual(again.comment, "eigene Notiz")
    }

    func testImportDoesNotModifySourceFile() throws {
        try Fixtures.requireFile(Fixtures.sampleURL)
        let before = try Fixtures.sha256(of: Fixtures.sampleURL)

        _ = try LibraryImporter.importFile(at: Fixtures.sampleURL, into: try Fixtures.freshContext())

        XCTAssertEqual(try Fixtures.sha256(of: Fixtures.sampleURL), before)
    }
}
