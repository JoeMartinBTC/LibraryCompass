import XCTest
@testable import LibraryCompassCore

/// Eigener Google-Books-Schlüssel hebt die anonyme Tagesquote (live erlebt:
/// `429 Quota exceeded … 'Queries per day'`). Der Schlüssel gehört nie ins Repo.
final class GoogleBooksKeyTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-key-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func keyFile(_ contents: String) throws -> URL {
        let url = directory.appendingPathComponent("google-books-key.txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: URL

    func testURLWithoutKeyStaysUnchanged() {
        let url = GoogleBooks.volumesURL(isbn: "9783785728390", key: nil).absoluteString
        XCTAssertFalse(url.contains("key="), url)
        XCTAssertTrue(url.contains("q=isbn:9783785728390"), url)
    }

    func testURLCarriesKeyWhenPresent() {
        let url = GoogleBooks.volumesURL(isbn: "9783785728390", key: "AIzaTestKey").absoluteString
        XCTAssertTrue(url.contains("key=AIzaTestKey"), url)
        XCTAssertTrue(url.contains("isbn:9783785728390"), url)
    }

    // MARK: Herkunft des Schlüssels

    func testReadsKeyFromFile() throws {
        let file = try keyFile("AIzaFromFile")
        XCTAssertEqual(GoogleBooksKey.resolve(environment: [:], file: file), "AIzaFromFile")
    }

    func testTrimsWhitespaceAndNewlines() throws {
        let file = try keyFile("  AIzaFromFile\n")
        XCTAssertEqual(GoogleBooksKey.resolve(environment: [:], file: file), "AIzaFromFile")
    }

    func testEnvironmentBeatsFile() throws {
        let file = try keyFile("AIzaFromFile")
        let environment = ["GOOGLE_BOOKS_API_KEY": "AIzaFromEnvironment"]
        XCTAssertEqual(GoogleBooksKey.resolve(environment: environment, file: file), "AIzaFromEnvironment")
    }

    func testEmptyFileCountsAsNoKey() throws {
        let file = try keyFile("\n  \n")
        XCTAssertNil(GoogleBooksKey.resolve(environment: [:], file: file))
    }

    func testMissingFileCountsAsNoKey() {
        let missing = directory.appendingPathComponent("gibt-es-nicht.txt")
        XCTAssertNil(GoogleBooksKey.resolve(environment: [:], file: missing))
    }

    func testBlankEnvironmentValueFallsBackToFile() throws {
        let file = try keyFile("AIzaFromFile")
        XCTAssertEqual(GoogleBooksKey.resolve(environment: ["GOOGLE_BOOKS_API_KEY": "  "], file: file),
                       "AIzaFromFile")
    }

    // MARK: Verwendung im Lookup

    func testLookupSendsKeyToGoogleOnly() async throws {
        let client = RecordingClient()
        let lookup = MetadataLookup(client: client, backoff: { _ in }, apiKey: "AIzaTestKey")

        _ = try? await lookup.metadata(isbn: "9780000000000")

        let requested = await client.requested
        let google = requested.filter { $0.contains("googleapis.com") }
        XCTAssertFalse(google.isEmpty, "Google wurde nicht gefragt")
        XCTAssertTrue(google.allSatisfy { $0.contains("key=AIzaTestKey") }, google.description)
        XCTAssertFalse(requested.filter { $0.contains("openlibrary.org") }.contains { $0.contains("AIzaTestKey") },
                       "Der Schlüssel darf nur an Google gehen")
    }
}

/// Antwortet überall mit „nichts gefunden" und merkt sich die Adressen.
private actor RecordingClient: HTTPClient {
    private(set) var requested: [String] = []

    func get(_ url: URL) async throws -> (Data, Int) {
        requested.append(url.absoluteString)
        return (Data("{}".utf8), 200)
    }
}
