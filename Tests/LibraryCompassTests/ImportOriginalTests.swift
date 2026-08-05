import XCTest
import SwiftData
@testable import LibraryCompassCore

/// ISC-5 (Abnahme-Import Original: `imported=1780 errors=0`) und ISC-10 (Quelldatei unverändert).
final class ImportOriginalTests: XCTestCase {

    func testOriginalImportReportsAllBooksAndNoErrors() throws {
        try Fixtures.requireFile(Fixtures.originalURL)
        let context = try Fixtures.freshContext()

        let report = try LibraryImporter.importFile(at: Fixtures.originalURL, into: context)

        print("IMPORT-REPORT: " + report.summary)
        XCTAssertEqual(report.summary, "imported=1780 errors=0")
        XCTAssertEqual(report.skippedNonBooks, 1, "der eine Gadget-Eintrag wird übersprungen")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1780)
    }

    func testOriginalImportDoesNotModifySourceFile() throws {
        try Fixtures.requireFile(Fixtures.originalURL)
        let before = try Fixtures.sha256(of: Fixtures.originalURL)

        _ = try LibraryImporter.importFile(at: Fixtures.originalURL, into: try Fixtures.freshContext())

        XCTAssertEqual(try Fixtures.sha256(of: Fixtures.originalURL), before)
    }
}
