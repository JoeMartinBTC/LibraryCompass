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
}
