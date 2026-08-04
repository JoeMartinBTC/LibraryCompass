import XCTest
import SwiftData
@testable import LibraryCompassCore

/// ISC-7: Eigene Felder (Bewertung, Kommentar, Gelesen-Datum) überleben einen Store-Neustart.
final class PersistenceTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lc-persistence-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
    }

    func testOwnFieldsSurviveStoreReopen() throws {
        let gelesenAm = Date(timeIntervalSince1970: 1_754_000_000)

        // Erste Sitzung: Buch anlegen und eigene Felder setzen.
        do {
            let container = try LibraryStore.container(at: storeURL)
            let context = ModelContext(container)
            let buch = Book(isbn: "9783442156917", title: "Der Schwarm", author: "Frank Schätzing",
                            addedDate: Date(timeIntervalSince1970: 1_700_000_000), year: 2004, pages: 1000)
            context.insert(buch)
            buch.rating = 4
            buch.comment = "Zäher Mittelteil, starkes Ende."
            buch.readDate = gelesenAm
            try context.save()
        }

        // Zweite Sitzung: frischer Container auf dieselbe Datei.
        let container = try LibraryStore.container(at: storeURL)
        let context = ModelContext(container)
        let buecher = try context.fetch(FetchDescriptor<Book>())

        XCTAssertEqual(buecher.count, 1)
        let buch = try XCTUnwrap(buecher.first)
        XCTAssertEqual(buch.rating, 4)
        XCTAssertEqual(buch.comment, "Zäher Mittelteil, starkes Ende.")
        XCTAssertEqual(buch.readDate, gelesenAm)
        XCTAssertEqual(buch.title, "Der Schwarm")
        XCTAssertEqual(buch.author, "Frank Schätzing")
        XCTAssertEqual(buch.isbn, "9783442156917")
        XCTAssertEqual(buch.year, 2004)
        XCTAssertEqual(buch.pages, 1000)
    }

    func testInMemoryContainerStartsEmpty() throws {
        let container = try LibraryStore.inMemoryContainer()
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 0)
    }
}
