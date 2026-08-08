import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Der Lauf vom 2026-08-08 endete bei 1188 von 1780 Büchern und meldete trotzdem
/// Exit 0 — 592 Bücher wurden nie gefragt, ohne dass es jemand sah. Ein unvollständiger
/// Lauf muss sich selbst als solchen ausweisen.
@MainActor
final class CoverBackfillAbortTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-abort-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCompleteRunReportsComplete() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "9783442494033", title: "Eins"))
        context.insert(Book(isbn: "9783785728390", title: "Zwei"))
        try context.save()

        let client = SilentClient()
        let report = try await CoverBackfill.run(context: context,
                                                 lookup: MetadataLookup(client: client, backoff: { _ in }),
                                                 cache: CoverCache(client: client, directory: directory),
                                                 pause: 0)

        XCTAssertEqual(report.total, 2)
        XCTAssertEqual(report.checked, 2)
        XCTAssertTrue(report.isComplete)
        XCTAssertFalse(report.summary.uppercased().contains("ABBRUCH"))
    }

    /// Ein Report, der weniger geprüft hat als vorlagen, ist ein Abbruch — und sagt es.
    func testIncompleteReportIsFlaggedAsAbort() {
        let report = CoverBackfill.Report(checked: 1188, filled: 1032, total: 1780)
        XCTAssertFalse(report.isComplete)
        XCTAssertTrue(report.summary.uppercased().contains("ABBRUCH"), report.summary)
        XCTAssertTrue(report.summary.contains("1188"), report.summary)
        XCTAssertTrue(report.summary.contains("1780"), report.summary)
    }

    /// Wird der Lauf abgebrochen (Prozessende, Ctrl-C), darf er nicht still
    /// „fertig" zurückgeben.
    func testCancellationStopsTheRunAndThrows() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        for index in 0..<20 {
            context.insert(Book(isbn: "", title: "Titel \(index)", author: "Autor"))
        }
        try context.save()

        let client = SilentClient()
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        let cache = CoverCache(client: client, directory: directory)

        let task = Task { @MainActor in
            try await CoverBackfill.run(context: context, lookup: lookup, cache: cache,
                                        pause: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("abgebrochener Lauf muss werfen statt still fertig zu melden")
        } catch is CancellationError {
            // erwartet
        }
    }
}

/// Findet nie ein Cover — der Lauf soll trotzdem sauber durchzählen.
private actor SilentClient: HTTPClient {
    func get(_ url: URL) async throws -> (Data, Int) { (Data(), 404) }
}
