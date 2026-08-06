import Foundation
import SwiftData

/// Holt Cover für Bücher, die schon im Bestand sind. Beim Import kommen keine
/// Bilder mit, und der ISBN-Dialog lädt nur für das eine neue Buch.
///
/// Läuft bewusst **sequenziell mit Pause**: Google drosselt anonyme Zugriffe pro Tag,
/// und ein Schwall paralleler Anfragen bringt nur 429er.
@MainActor
public enum CoverBackfill {

    public struct Report: Sendable, Equatable {
        public var checked = 0
        public var filled = 0
        public var summary: String { "geprüft=\(checked) ergänzt=\(filled)" }
    }

    /// - Parameter pause: Wartezeit zwischen zwei Büchern in Nanosekunden.
    @discardableResult
    public static func run(context: ModelContext,
                           lookup: MetadataLookup = MetadataLookup(),
                           cache: CoverCache = .shared,
                           pause: UInt64 = 1_000_000_000,
                           progress: ((Int, Int, String) -> Void)? = nil) async throws -> Report {
        let books = try context.fetch(FetchDescriptor<Book>())
            .filter { ($0.coverPath ?? "").isEmpty }
        var report = Report()
        let total = books.count

        for book in books {
            report.checked += 1
            if let path = try? await coverPath(for: book, lookup: lookup, cache: cache) {
                book.coverPath = path
                report.filled += 1
                try? context.save()
            }
            progress?(report.checked, total, book.title)
            if pause > 0, report.checked < total {
                try? await Task.sleep(nanoseconds: pause)
            }
        }
        try? context.save()
        return report
    }

    /// Mit ISBN läuft die volle Kette (Amazon zuerst), ohne ISBN bleibt nur die
    /// Titelsuche mit Autor-Abgleich.
    private static func coverPath(for book: Book,
                                  lookup: MetadataLookup,
                                  cache: CoverCache) async throws -> String? {
        guard !book.isbn.isEmpty || !book.title.isEmpty else { return nil }
        guard let url = await lookup.coverURL(isbn: book.isbn,
                                              title: book.title,
                                              author: book.author) else { return nil }
        return try await cache.download(from: url, isbn: book.isbn.isEmpty ? book.title : book.isbn)
    }
}
