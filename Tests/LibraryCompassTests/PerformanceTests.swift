import XCTest
import SwiftData
@testable import LibraryCompassCore

/// ISC-11: Filtern + Sortieren über den Vollbestand (1.780 Bücher) unter 100 ms.
final class PerformanceTests: XCTestCase {

    private func fullLibrary() throws -> [Book] {
        try Fixtures.requireFile(Fixtures.originalURL)
        let context = try Fixtures.freshContext()
        _ = try LibraryImporter.importFile(at: Fixtures.originalURL, into: context)
        return try context.fetch(FetchDescriptor<Book>())
    }

    func testFilterAndSortOverFullLibraryUnder100ms() throws {
        let books = try fullLibrary()
        XCTAssertEqual(books.count, 1780)

        // „ungelesen" bleibt nach dem Import leer, weil importierte Bücher als
        // gelesen gelten — die Abfrage muss trotzdem in der Zeit bleiben.
        let queries: [(query: BookQuery, expectsResults: Bool)] = [
            (BookQuery(filter: .alle, search: "der", sort: .titel), true),
            (BookQuery(filter: .bewertet, search: "sch", sort: .autor), true),
            (BookQuery(filter: .ungelesen, search: "", sort: .jahr), false),
            (BookQuery(filter: .alle, search: "", sort: .bewertung), true),
            (BookQuery(filter: .alle, search: "e", sort: .zuletztGelesen), true)
        ]

        for (query, expectsResults) in queries {
            let start = DispatchTime.now().uptimeNanoseconds
            let result = query.apply(to: books)
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            XCTAssertLessThan(seconds, 0.1,
                              "Filter+Sort (\(query.filter), \(query.sort)) dauerte \(seconds) s")
            if expectsResults { XCTAssertFalse(result.isEmpty) }
        }
    }

    func testStatsOverFullLibraryUnder100ms() throws {
        let books = try fullLibrary()
        let start = DispatchTime.now().uptimeNanoseconds
        let stats = LibraryStats(books: books)
        let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
        XCTAssertLessThan(seconds, 0.1, "Statistik dauerte \(seconds) s")
        XCTAssertEqual(stats.total, 1780)
    }
}
