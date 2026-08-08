import XCTest
import SwiftData
@testable import LibraryCompassCore

/// 137 Bestandsbücher führen keine ISBN und bleiben deshalb ohne ausgabegenaues Cover.
/// Dieser Lauf schließt die Datenlücke — aber nur mit Beleg.
@MainActor
final class ISBNBackfillTests: XCTestCase {

    private func parts() -> (StubDNB, MetadataLookup) {
        let client = StubDNB()
        return (client, MetadataLookup(client: client, backoff: { _ in }))
    }

    func testFillsISBNWhenTheAuthorMatches() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "", title: "Der Junge aus dem Wald", author: "Coben, Harlan"))
        try context.save()
        let (_, lookup) = parts()

        let report = try await ISBNBackfill.run(context: context, lookup: lookup, pause: 0)

        XCTAssertEqual(report.total, 1)
        XCTAssertEqual(report.filled, 1)
        XCTAssertTrue(report.isComplete)
        let book = try XCTUnwrap(context.fetch(FetchDescriptor<Book>()).first)
        XCTAssertEqual(book.isbn, "9783442494040")
    }

    /// Anti: Ein Buch mit fremdem Autor darf keine ISBN erben — sonst zieht es
    /// anschließend auch noch ein falsches Cover.
    func testLeavesBookAloneWhenNoRecordMatchesTheAuthor() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "", title: "Der Junge aus dem Wald", author: "Winslow, Don"))
        try context.save()
        let (_, lookup) = parts()

        let report = try await ISBNBackfill.run(context: context, lookup: lookup, pause: 0)

        XCTAssertEqual(report.checked, 1)
        XCTAssertEqual(report.filled, 0)
        XCTAssertEqual(try XCTUnwrap(context.fetch(FetchDescriptor<Book>()).first).isbn, "")
    }

    /// Ohne Autor gibt es nichts zu belegen — solche Bücher werden gar nicht erst gefragt.
    func testSkipsBooksWithoutAuthor() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "", title: "Nur ein Titel", author: ""))
        try context.save()
        let (client, lookup) = parts()

        let report = try await ISBNBackfill.run(context: context, lookup: lookup, pause: 0)

        XCTAssertEqual(report.total, 0)
        let requested = await client.requested
        XCTAssertTrue(requested.isEmpty, requested.description)
    }

    func testSkipsBooksThatAlreadyHaveAnISBN() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "9783442494033", title: "Kill for me", author: "Cavanagh, Steve"))
        try context.save()
        let (client, lookup) = parts()

        let report = try await ISBNBackfill.run(context: context, lookup: lookup, pause: 0)

        XCTAssertEqual(report.total, 0)
        let requested = await client.requested
        XCTAssertTrue(requested.isEmpty, requested.description)
    }

    func testIncompleteReportIsFlaggedAsAbort() {
        let report = ISBNBackfill.Report(checked: 40, filled: 12, total: 113)
        XCTAssertFalse(report.isComplete)
        XCTAssertTrue(report.summary.uppercased().contains("ABBRUCH"), report.summary)
    }
}

/// Antwortet wie die DNB auf eine Titel-und-Person-Suche.
private actor StubDNB: HTTPClient {
    private(set) var requested: [String] = []

    func get(_ url: URL) async throws -> (Data, Int) {
        requested.append(url.absoluteString)
        guard url.absoluteString.contains("services.dnb.de") else { return (Data(), 404) }
        let xml = """
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
          <records>
            <record><recordData>
              <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Der Junge aus dem Wald : Thriller</dc:title>
                <dc:creator>Coben, Harlan [Verfasser]</dc:creator>
                <dc:identifier>978-3-442-49404-0 kart.</dc:identifier>
              </dc>
            </recordData></record>
          </records>
        </searchRetrieveResponse>
        """
        return (Data(xml.utf8), 200)
    }
}
