import XCTest
@testable import LibraryCompassCore

/// ISC-6: echte Abfrage gegen Open Library / Google Books (Netz nötig).
final class LookupTests: XCTestCase {

    func testKnownISBNYieldsTitleAndAuthor() async throws {
        let lookup = MetadataLookup()
        guard let metadata = try await lookup.metadata(isbn: "9783442156917") else {
            return XCTFail("Kein Treffer für ISBN 9783442156917")
        }
        XCTAssertFalse(metadata.title.isEmpty, "Titel leer")
        XCTAssertFalse(metadata.author.isEmpty, "Autor leer")
    }

    /// Deutsche Ausgabe, die Open Library nicht kennt und Google anonym drosselt —
    /// muss über die DNB kommen (Meldung des Nutzers vom 2026-08-05).
    func testGermanOnlyISBNResolvesViaDNB() async throws {
        let lookup = MetadataLookup()
        guard let metadata = try await lookup.metadata(isbn: "9783785728390") else {
            return XCTFail("Kein Treffer für ISBN 9783785728390")
        }
        XCTAssertEqual(metadata.title, "Toxin: Thriller")
        XCTAssertTrue(metadata.author.contains("Lange"), metadata.author)
        XCTAssertEqual(metadata.year, 2023)
        XCTAssertEqual(metadata.pages, 459)
    }
}
