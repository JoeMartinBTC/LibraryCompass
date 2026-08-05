import XCTest
@testable import LibraryCompassCore

/// Deutsche Nationalbibliothek als dritte Quelle — ohne Netz.
/// Grund (live 2026-08-05): Open Library kennt deutsche Ausgaben oft nicht
/// (`{}` zu 9783785728390) und Google Books drosselt anonym pro Tag (429).
final class DNBLookupTests: XCTestCase {

    /// Echtes Antwortfragment der DNB zu ISBN 9783785728390.
    private let toxinRecord = """
    <?xml version="1.0" encoding="UTF-8"?>
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><version>1.1</version>
    <numberOfRecords>1</numberOfRecords><records><record><recordSchema>oai_dc</recordSchema>
    <recordData><dc xmlns:dnb="http://d-nb.de/standards/dnbterms"
    xmlns="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <dc:title>Toxin : Thriller / Kathrin Lange, Susanne Thiele</dc:title>
      <dc:creator>Lange, Kathrin [Verfasser]</dc:creator>
      <dc:creator>Thiele, Susanne [Verfasser]</dc:creator>
      <dc:publisher>Köln : Lübbe</dc:publisher>
      <dc:date>2023</dc:date>
      <dc:format>459 Seiten</dc:format>
    </dc></recordData></record></records></searchRetrieveResponse>
    """

    func testRecordYieldsTitleAuthorYearPages() throws {
        let metadata = try XCTUnwrap(DNB.parse(Data(toxinRecord.utf8)))
        XCTAssertEqual(metadata.title, "Toxin: Thriller")
        XCTAssertEqual(metadata.author, "Lange, Kathrin; Thiele, Susanne")
        XCTAssertEqual(metadata.year, 2023)
        XCTAssertEqual(metadata.pages, 459)
        XCTAssertNil(metadata.coverURL, "Die DNB liefert keine Cover")
    }

    func testTitleDropsStatementOfResponsibility() throws {
        let xml = record(title: "Stillhalten : Roman / Nina Jäckle", creators: ["Jäckle, Nina [Verfasser]"])
        XCTAssertEqual(try XCTUnwrap(DNB.parse(Data(xml.utf8))).title, "Stillhalten: Roman")
    }

    func testTitleWithoutSubtitleStaysUnchanged() throws {
        let xml = record(title: "Broken / Don Winslow", creators: ["Winslow, Don [Verfasser]"])
        XCTAssertEqual(try XCTUnwrap(DNB.parse(Data(xml.utf8))).title, "Broken")
    }

    func testPrefersAuthorsOverOtherRoles() throws {
        let xml = record(title: "Titel / X",
                         creators: ["Müller, Anna [Übersetzer]", "Beispiel, Bert [Verfasser]"])
        XCTAssertEqual(try XCTUnwrap(DNB.parse(Data(xml.utf8))).author, "Beispiel, Bert")
    }

    func testFallsBackToRemainingRolesWhenNoAuthorNamed() throws {
        let xml = record(title: "Titel / X", creators: ["Müller, Anna [Herausgeber]"])
        XCTAssertEqual(try XCTUnwrap(DNB.parse(Data(xml.utf8))).author, "Müller, Anna")
    }

    func testEmptyResultIsMiss() {
        let xml = """
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <numberOfRecords>0</numberOfRecords><records/></searchRetrieveResponse>
        """
        XCTAssertNil(DNB.parse(Data(xml.utf8)))
    }

    func testQueryURLCarriesNormalisedISBN() {
        let url = DNB.searchURL(isbn: "9783785728390").absoluteString
        XCTAssertTrue(url.contains("services.dnb.de/sru/dnb"), url)
        XCTAssertTrue(url.contains("9783785728390"), url)
        XCTAssertTrue(url.contains("oai_dc"), url)
    }

    // MARK: Reihenfolge der Quellen

    func testDNBAnswersWhenOpenLibraryIsEmptyAndGoogleIsThrottled() async throws {
        let client = StubClient(responses: [
            "openlibrary.org": (Data("{}".utf8), 200),
            "googleapis.com": (Data(#"{"error": {"code": 429}}"#.utf8), 429),
            "services.dnb.de": (Data(toxinRecord.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let result = try await lookup.metadata(isbn: "978-3-7857-2839-0")
        let metadata = try XCTUnwrap(result)
        XCTAssertEqual(metadata.title, "Toxin: Thriller")
        XCTAssertEqual(metadata.author, "Lange, Kathrin; Thiele, Susanne")
    }

    func testOpenLibraryStillWinsWhenItAnswers() async throws {
        let json = #"{"ISBN:9783442156917": {"title": "Der Schwarm", "authors": [{"name": "Frank Schätzing"}]}}"#
        let client = StubClient(responses: [
            "openlibrary.org": (Data(json.utf8), 200),
            "services.dnb.de": (Data(toxinRecord.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let result = try await lookup.metadata(isbn: "9783442156917")
        let metadata = try XCTUnwrap(result)
        XCTAssertEqual(metadata.title, "Der Schwarm")
        let requested = await client.requested
        XCTAssertFalse(requested.contains { $0.contains("services.dnb.de") },
                       "Bei OL-Treffer darf die DNB nicht gefragt werden")
    }

    /// Die DNB liefert nie ein Cover. Steht der Titel schon fest, muss Google
    /// trotzdem nach dem Bild gefragt werden — sonst bringt ein eigener
    /// Google-Schlüssel für deutsche Ausgaben gar nichts.
    func testAsksGoogleForCoverEvenWhenDNBAlreadyNamedTheTitle() async throws {
        let google = #"""
        {"items": [{"volumeInfo": {"title": "Toxin", "authors": ["Kathrin Lange"],
         "imageLinks": {"thumbnail": "http://books.google.com/books?id=42&img=1"}}}]}
        """#
        let client = StubClient(responses: [
            "openlibrary.org/api/books": (Data("{}".utf8), 200),
            "covers.openlibrary.org": (Data(), 404),
            "openlibrary.org/search.json": (Data(#"{"docs": []}"#.utf8), 200),
            "services.dnb.de": (Data(toxinRecord.utf8), 200),
            "googleapis.com": (Data(google.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        let result = try await lookup.metadata(isbn: "9783785728390")
        let metadata = try XCTUnwrap(result)
        XCTAssertEqual(metadata.title, "Toxin: Thriller", "Titel bleibt der der DNB")
        XCTAssertEqual(metadata.coverURL?.host, "books.google.com")
        XCTAssertEqual(metadata.coverURL?.scheme, "https")
    }

    func testGoogleIsAskedOnlyOnceWhenItAlreadyAnswered() async throws {
        let google = #"{"items": [{"volumeInfo": {"title": "Irgendwas"}}]}"#
        let client = StubClient(responses: [
            "openlibrary.org/api/books": (Data("{}".utf8), 200),
            "covers.openlibrary.org": (Data(), 404),
            "openlibrary.org/search.json": (Data(#"{"docs": []}"#.utf8), 200),
            "services.dnb.de": (Data("<x/>".utf8), 200),
            "googleapis.com": (Data(google.utf8), 200)
        ])
        let lookup = MetadataLookup(client: client, backoff: { _ in })

        _ = try await lookup.metadata(isbn: "9780000000000")
        let googleCalls = await client.requested.filter { $0.contains("googleapis.com") }
        XCTAssertEqual(googleCalls.count, 1, "Google darf nicht doppelt gefragt werden")
    }

    func testGooglePageCountZeroCountsAsUnknown() throws {
        let json = #"{"items": [{"volumeInfo": {"title": "T", "pageCount": 0}}]}"#
        XCTAssertNil(try XCTUnwrap(GoogleBooks.parse(Data(json.utf8))).pages)
    }

    // MARK: Hilfen

    private func record(title: String, creators: [String]) -> String {
        let creatorTags = creators.map { "<dc:creator>\($0)</dc:creator>" }.joined()
        return """
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <numberOfRecords>1</numberOfRecords><records><record><recordData>
        <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>\(title)</dc:title>\(creatorTags)
        </dc></recordData></record></records></searchRetrieveResponse>
        """
    }
}

/// Antworten nach Host — der Lookup fragt die Quellen nacheinander.
private actor StubClient: HTTPClient {
    private let responses: [String: (Data, Int)]
    private(set) var requested: [String] = []

    init(responses: [String: (Data, Int)]) {
        self.responses = responses
    }

    func get(_ url: URL) async throws -> (Data, Int) {
        requested.append(url.absoluteString)
        for (host, response) in responses where url.absoluteString.contains(host) {
            return response
        }
        return (Data(), 404)
    }
}
