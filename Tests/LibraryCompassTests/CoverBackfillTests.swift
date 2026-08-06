import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Nachlauf für Bestandsbücher: Cover werden sonst nur beim Hinzufügen per ISBN
/// geladen, die importierten Bände blieben ohne Bild.
@MainActor
final class CoverBackfillTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-backfill-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try LibraryStore.inMemoryContainer())
    }

    private func makeParts() -> (StubClient, MetadataLookup, CoverCache) {
        let client = StubClient()
        return (client,
                MetadataLookup(client: client, backoff: { _ in }),
                CoverCache(client: client, directory: directory))
    }

    func testFillsCoverForBookWithISBN() async throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783442494033", title: "Kill for me", author: "Cavanagh, Steve"))
        try context.save()
        let (_, lookup, cache) = makeParts()

        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0)

        XCTAssertEqual(report.checked, 1)
        XCTAssertEqual(report.filled, 1)
        let book = try XCTUnwrap(LibraryStore.book(isbn: "9783442494033", in: context))
        // Die Datei heißt nach der ISBN des Buches, nicht nach der ISBN-10 der Bildadresse.
        XCTAssertEqual(book.coverPath, "9783442494033.jpg")
    }

    func testSkipsBooksThatAlreadyHaveACover() async throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783442494033", title: "Kill for me", coverPath: "vorhanden.jpg"))
        try context.save()
        let (client, lookup, cache) = makeParts()

        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0)

        XCTAssertEqual(report.checked, 0)
        XCTAssertEqual(report.filled, 0)
        let requested = await client.requested
        XCTAssertTrue(requested.isEmpty, "Bücher mit Bild dürfen keine Abfrage auslösen")
    }

    /// ~245 Bestandsbücher haben keine ISBN — für die bleibt nur Titel und Autor.
    func testUsesTitleSearchWhenISBNIsMissing() async throws {
        let context = try makeContext()
        context.insert(Book(isbn: "", title: "Kill for me", author: "Cavanagh, Steve"))
        try context.save()
        let (client, lookup, cache) = makeParts()

        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0)

        XCTAssertEqual(report.filled, 1)
        let requested = await client.requested
        XCTAssertTrue(requested.contains { $0.contains("openlibrary.org/search.json") }, requested.description)
        XCTAssertFalse(requested.contains { $0.contains("amazon") }, "ohne ISBN kein Amazon-Aufruf")
    }

    func testBooksWithoutTitleAndISBNAreLeftAlone() async throws {
        let context = try makeContext()
        context.insert(Book(isbn: "", title: "", author: ""))
        try context.save()
        let (_, lookup, cache) = makeParts()

        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0)
        XCTAssertEqual(report.checked, 1)
        XCTAssertEqual(report.filled, 0)
    }

    func testReportsProgressPerBook() async throws {
        let context = try makeContext()
        context.insert(Book(isbn: "9783442494033", title: "Eins"))
        context.insert(Book(isbn: "9783785728390", title: "Zwei"))
        try context.save()
        let (_, lookup, cache) = makeParts()

        var seen: [Int] = []
        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0) { done, total, _ in
            seen.append(done)
            XCTAssertEqual(total, 2)
        }
        XCTAssertEqual(seen, [1, 2])
        XCTAssertEqual(report.checked, 2)
    }
}

/// Antwortet wie die echten Quellen: Amazon liefert ein Bild, Open Library findet
/// über die Titelsuche eines, alles andere ist leer.
private actor StubClient: HTTPClient {
    private(set) var requested: [String] = []

    func get(_ url: URL) async throws -> (Data, Int) {
        let address = url.absoluteString
        requested.append(address)

        if address.contains("m.media-amazon.com") {
            return (Data(repeating: 9, count: 24_896), 200)
        }
        if address.contains("openlibrary.org/search.json") {
            let json = #"{"docs": [{"title": "Kill for me", "author_name": ["Steve Cavanagh"], "cover_i": 14597245}]}"#
            return (Data(json.utf8), 200)
        }
        if address.contains("covers.openlibrary.org") {
            return (Data(repeating: 7, count: 14_324), 200)
        }
        if address.contains("openlibrary.org/api/books") { return (Data("{}".utf8), 200) }
        return (Data(), 404)
    }
}
