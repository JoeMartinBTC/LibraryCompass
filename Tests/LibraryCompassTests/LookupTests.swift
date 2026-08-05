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

    /// „Kill for me" (Steve Cavanagh, 9783442494033): Die freien Quellen führen unter
    /// dieser ISBN kein Bild und liefern über die Titelsuche die englische Ausgabe.
    /// Amazon hat die deutsche Goldmann-Ausgabe — ausgabegenau über die ISBN-10.
    func testCoverForGermanEditionComesFromAmazon() async throws {
        let lookup = MetadataLookup()
        guard let metadata = try await lookup.metadata(isbn: "9783442494033") else {
            return XCTFail("Kein Treffer für ISBN 9783442494033")
        }
        XCTAssertTrue(metadata.title.contains("Kill for me"), metadata.title)
        let cover = try XCTUnwrap(metadata.coverURL, "Cover fehlt")
        XCTAssertEqual(cover.host, "m.media-amazon.com", cover.absoluteString)
        XCTAssertTrue(cover.absoluteString.contains("3442494036"), "ISBN-10 der deutschen Ausgabe")
    }

    /// Die Titelsuche bleibt als Rückfall — mit Autor-Abgleich.
    func testTitleSearchStillFindsSomethingWhenAmazonHasNothing() async throws {
        let lookup = MetadataLookup()
        let cover = try await lookup.coverByTitle(title: "Kill for me: Thriller", author: "Cavanagh, Steve")
        XCTAssertNotNil(cover)
    }
}
