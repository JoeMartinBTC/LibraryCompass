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
        /// Wie viele Bücher zu Beginn ohne Cover dastanden.
        public var total = 0

        public init(checked: Int = 0, filled: Int = 0, total: Int = 0) {
            self.checked = checked
            self.filled = filled
            self.total = total
        }

        /// Der Lauf vom 2026-08-08 endete bei 1188 von 1780 und meldete Exit 0 — seither
        /// weist ein unvollständiger Lauf sich selbst aus.
        public var isComplete: Bool { checked >= total }

        public var summary: String {
            let base = "geprüft=\(checked)/\(total) ergänzt=\(filled)"
            return isComplete ? base : "ABBRUCH — \(base), \(total - checked) Bücher ungefragt"
        }
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
        var report = Report(total: books.count)
        let total = books.count

        for book in books {
            // Ein abgebrochener Lauf darf nicht als „fertig" durchgehen.
            try Task.checkCancellation()
            report.checked += 1
            if let path = try? await coverPath(for: book, lookup: lookup, cache: cache) {
                book.coverPath = path
                report.filled += 1
                try? context.save()
            }
            progress?(report.checked, total, book.title)
            if pause > 0, report.checked < total {
                try await Task.sleep(nanoseconds: pause)
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
        guard let stem = CoverKey.stem(isbn: book.isbn, title: book.title, author: book.author) else { return nil }
        guard let url = await lookup.coverURL(isbn: book.isbn,
                                              title: book.title,
                                              author: book.author) else { return nil }
        let identity = CoverKey.identity(isbn: book.isbn, title: book.title, author: book.author)
        return try await cache.download(from: url, stem: stem, identity: identity)
    }
}
