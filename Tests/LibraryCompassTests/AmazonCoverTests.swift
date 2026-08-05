import XCTest
@testable import LibraryCompassCore

/// Amazon führt Cover unter der ISBN-10 — und zwar ausgabegenau, also die
/// deutsche Ausgabe zur deutschen ISBN. Freie Quellen liefern stattdessen oft
/// eine fremdsprachige Ausgabe (live 2026-08-05: „Kill for me").
final class AmazonCoverTests: XCTestCase {

    // MARK: ISBN-10 ableiten

    func testDerivesISBN10FromISBN13() {
        XCTAssertEqual(AmazonCover.isbn10(from: "9783442494033"), "3442494036")
        XCTAssertEqual(AmazonCover.isbn10(from: "9783785728390"), "3785728395")
    }

    func testKeepsExistingISBN10() {
        XCTAssertEqual(AmazonCover.isbn10(from: "3442156912"), "3442156912")
        // Prüfziffer X ist gültig — nachgerechnet, nicht geraten.
        XCTAssertEqual(AmazonCover.isbn10(from: "080442957X"), "080442957X")
        XCTAssertNil(AmazonCover.isbn10(from: "344215691X"), "falsche Prüfziffer")
    }

    func testHandlesSeparators() {
        XCTAssertEqual(AmazonCover.isbn10(from: "978-3-442-49403-3"), "3442494036")
    }

    /// 979er-ISBN haben keine ISBN-10-Entsprechung.
    func testRejectsISBN13WithoutISBN10Equivalent() {
        XCTAssertNil(AmazonCover.isbn10(from: "9791234567896"))
    }

    /// Der Fallstrick: `1234567890` hat eine **falsche** Prüfziffer, ist bei Amazon
    /// aber eine gültige ASIN — die Adresse lieferte live ein Foto von Bremsscheiben.
    /// Ohne Prüfziffernkontrolle landen fremde Produktbilder in der Bibliothek.
    func testRejectsInvalidCheckDigit() {
        XCTAssertNil(AmazonCover.isbn10(from: "1234567890"))
        XCTAssertNil(AmazonCover.isbn10(from: "9783442494039"))
    }

    func testRejectsNonsense() {
        XCTAssertNil(AmazonCover.isbn10(from: ""))
        XCTAssertNil(AmazonCover.isbn10(from: "abc"))
        XCTAssertNil(AmazonCover.isbn10(from: "12345"))
    }

    // MARK: Adresse

    func testCoverURLUsesISBN10() {
        let url = AmazonCover.url(isbn: "9783442494033")?.absoluteString
        XCTAssertEqual(url, "https://m.media-amazon.com/images/P/3442494036.01.LZZZZZZZ.jpg")
    }

    func testNoURLWithoutValidISBN() {
        XCTAssertNil(AmazonCover.url(isbn: "1234567890"))
    }

    // MARK: Im Lookup

    func testAmazonCoverWinsOverForeignEditionFromTitleSearch() async throws {
        let search = #"{"docs": [{"title": "Kill for Me Kill for You", "author_name": ["Steve Cavanagh"], "cover_i": 14597245}]}"#
        let client = StubClient(responses: [
            "openlibrary.org/api/books": (Data("{}".utf8), 200),
            "services.dnb.de": (Data(dnbRecord.utf8), 200),
            "m.media-amazon.com": (Data(repeating: 9, count: 24_896), 200),
            "covers.openlibrary.org": (Data(repeating: 7, count: 14_324), 200),
            "openlibrary.org/search.json": (Data(search.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let result = try await lookup.metadata(isbn: "9783442494033")
        let cover = try XCTUnwrap(result?.coverURL)
        XCTAssertEqual(cover.host, "m.media-amazon.com", "Die ausgabegenaue Quelle hat Vorrang")
    }

    /// 43 Byte statt Bild — so antwortet Amazon, wenn es zur ISBN nichts hat.
    func testTinyAmazonAnswerFallsThroughToFreeSources() async throws {
        let client = StubClient(responses: [
            "openlibrary.org/api/books": (Data("{}".utf8), 200),
            "services.dnb.de": (Data(dnbRecord.utf8), 200),
            "m.media-amazon.com": (Data(repeating: 0, count: 43), 200),
            "covers.openlibrary.org": (Data(repeating: 7, count: 14_324), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let result = try await lookup.metadata(isbn: "9783442494033")
        XCTAssertEqual(try XCTUnwrap(result?.coverURL).host, "covers.openlibrary.org")
    }

    func testBooksWithoutISBNNeverAskAmazon() async throws {
        let client = StubClient(responses: [:])
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        _ = try? await lookup.coverByTitle(title: "Irgendein Buch", author: "Autor, Anna")
        let requested = await client.requested
        XCTAssertFalse(requested.contains { $0.contains("amazon") }, requested.description)
    }

    private let dnbRecord = """
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><numberOfRecords>1</numberOfRecords>
    <records><record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Kill for me : Thriller / Steve Cavanagh</dc:title>
    <dc:creator>Cavanagh, Steve [Verfasser]</dc:creator>
    </dc></recordData></record></records></searchRetrieveResponse>
    """
}

private actor StubClient: HTTPClient {
    private let responses: [String: (Data, Int)]
    private(set) var requested: [String] = []

    init(responses: [String: (Data, Int)]) {
        self.responses = responses
    }

    func get(_ url: URL) async throws -> (Data, Int) {
        requested.append(url.absoluteString)
        for (fragment, response) in responses where url.absoluteString.contains(fragment) {
            return response
        }
        return (Data(), 404)
    }
}
