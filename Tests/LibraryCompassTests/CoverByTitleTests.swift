import XCTest
@testable import LibraryCompassCore

/// Fall „Kill for me" (Steve Cavanagh, ISBN 9783442494033, 2026-08-05):
/// Unter der ISBN hat weder Open Library noch Google ein Bild, über Titel und Autor
/// haben beide eines. Die Titelsuche fand es trotzdem nicht.
final class CoverByTitleTests: XCTestCase {

    /// So steht der Titel nach dem DNB-Lookup im Buch.
    private let messyTitle = "[Kill for me, kill for you] ; Kill for me: Thriller: sie tötet deinen schlimmsten Feind, wenn du ihren tötest ..."

    // MARK: Suchtitel

    func testSearchTitleDropsBracketedVariantAndSubtitle() {
        XCTAssertEqual(SearchTitle.simplify(messyTitle), "Kill for me")
    }

    func testSearchTitleKeepsPlainTitle() {
        XCTAssertEqual(SearchTitle.simplify("Der Schwarm"), "Der Schwarm")
    }

    func testSearchTitleDropsSubtitleAfterColon() {
        XCTAssertEqual(SearchTitle.simplify("Toxin: Thriller"), "Toxin")
    }

    func testSearchTitleSurvivesBracketsOnly() {
        XCTAssertEqual(SearchTitle.simplify("[Kill for me, kill for you]"), "Kill for me, kill for you")
    }

    // MARK: Open-Library-Suche

    func testSearchURLCarriesTitleAndAuthor() {
        let url = OpenLibrary.searchURL(title: "Kill for me", author: "Cavanagh, Steve").absoluteString
        XCTAssertTrue(url.contains("title=Kill%20for%20me") || url.contains("title=Kill+for+me"), url)
        XCTAssertTrue(url.lowercased().contains("author="), url)
    }

    /// Der echte Treffer hat kein `isbn`-Feld, aber ein `cover_i` — genau daran
    /// scheiterte die alte Fassung.
    func testSearchResultsReadCoverIDWithoutISBN() throws {
        let json = """
        {"numFound": 1, "docs": [
          {"title": "Kill for Me Kill for You", "author_name": ["Steve Cavanagh"], "cover_i": 14597245}
        ]}
        """
        let results = OpenLibrary.searchResults(Data(json.utf8))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.coverID, 14597245)
        XCTAssertNil(results.first?.isbn)
    }

    func testCoverURLFromCoverID() {
        XCTAssertEqual(OpenLibrary.coverURL(coverID: 14597245).absoluteString,
                       "https://covers.openlibrary.org/b/id/14597245-L.jpg")
    }

    // MARK: Zusammenspiel

    func testFindsCoverViaOpenLibraryTitleSearch() async throws {
        let search = """
        {"docs": [{"title": "Kill for Me Kill for You", "author_name": ["Steve Cavanagh"], "cover_i": 14597245}]}
        """
        let client = StubClient(responses: [
            "openlibrary.org/search.json": (Data(search.utf8), 200),
            "covers.openlibrary.org/b/id/14597245": (Data(repeating: 7, count: 14_324), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let cover = try await lookup.coverByTitle(title: messyTitle, author: "Cavanagh, Steve")
        XCTAssertEqual(cover?.absoluteString, "https://covers.openlibrary.org/b/id/14597245-L.jpg")
    }

    func testFallsBackToGoogleTitleSearch() async throws {
        let google = #"""
        {"items": [{"volumeInfo": {"title": "Kill for Me", "authors": ["Steve Cavanagh"],
          "imageLinks": {"thumbnail": "http://books.google.com/books/content?id=iWBSEQAAQBAJ&img=1"}}}]}
        """#
        let client = StubClient(responses: [
            "openlibrary.org/search.json": (Data(#"{"docs": []}"#.utf8), 200),
            "googleapis.com": (Data(google.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let cover = try await lookup.coverByTitle(title: messyTitle, author: "Cavanagh, Steve")
        XCTAssertEqual(cover?.host, "books.google.com")
        XCTAssertEqual(cover?.scheme, "https", "Google liefert http")
    }

    /// Der Fallstrick aus dem Bauauftrag: „Broken" bekam das Cover von
    /// „Once Upon a Broken Heart". Fremder Autor bleibt verworfen.
    func testRejectsMatchFromDifferentAuthor() async throws {
        let search = """
        {"docs": [{"title": "Kill for Me", "author_name": ["Stephanie Garber"], "cover_i": 999}]}
        """
        let google = #"{"items": [{"volumeInfo": {"title": "Kill for Me", "authors": ["Jemand Anderes"], "imageLinks": {"thumbnail": "http://books.google.com/x"}}}]}"#
        let client = StubClient(responses: [
            "openlibrary.org/search.json": (Data(search.utf8), 200),
            "googleapis.com": (Data(google.utf8), 200),
            "covers.openlibrary.org": (Data(repeating: 7, count: 14_324), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let cover = try await lookup.coverByTitle(title: messyTitle, author: "Cavanagh, Steve")
        XCTAssertNil(cover)
    }

    func testNeedsAuthorToSearchAtAll() async throws {
        let client = StubClient(responses: [:])
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        let cover = try await lookup.coverByTitle(title: messyTitle, author: "")
        XCTAssertNil(cover)
        let requested = await client.requested
        XCTAssertTrue(requested.isEmpty, "Ohne Autor darf gar nicht gesucht werden")
    }
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
