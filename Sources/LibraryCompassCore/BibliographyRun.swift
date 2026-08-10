import Foundation
import SwiftData

/// Ein Knopfdruck in der Detailansicht: Werkliste des Verfassers holen, gegen den
/// Bestand halten, die Lücken als `MissingBook` ablegen und ihre Cover nachladen.
///
/// Sequenziell mit Pause wie der Cover-Nachlauf — Google drosselt anonyme Zugriffe,
/// und ein Schwall paralleler Anfragen bringt nur 429er.
@MainActor
public enum BibliographyRun {

    public struct Report: Sendable, Equatable {
        /// Werke, die der Katalog dem Verfasser zuschreibt.
        public var works = 0
        /// Davon nicht im Bestand.
        public var gaps = 0
        /// Davon mit Coverbild.
        public var covers = 0
        /// Hat der Lauf den Katalog zu Ende gelesen?
        public var isComplete = true

        public init(works: Int = 0, gaps: Int = 0, covers: Int = 0, isComplete: Bool = true) {
            self.works = works
            self.gaps = gaps
            self.covers = covers
            self.isComplete = isComplete
        }

        public var summary: String {
            let base = "\(works) Werke · \(gaps) Lücken · \(covers) mit Bild"
            return isComplete ? base : "unvollständig — \(base)"
        }
    }

    /// Lücken eines Verfassers, bereits im Store abgelegt.
    public static func gaps(author: String, in context: ModelContext) -> [MissingBook] {
        let all = (try? context.fetch(FetchDescriptor<MissingBook>())) ?? []
        return all.filter { AuthorBibliography.sameAuthor(author, $0.author) }
    }

    /// - Parameter pause: Wartezeit zwischen zwei Cover-Anfragen in Nanosekunden.
    @discardableResult
    public static func run(author: String,
                           context: ModelContext,
                           lookup: MetadataLookup = MetadataLookup(),
                           cache: CoverCache = .shared,
                           pause: UInt64 = 400_000_000,
                           progress: ((Int, Int, String) -> Void)? = nil) async throws -> Report {
        let person = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !person.isEmpty else { return Report() }

        let result = try await lookup.bibliography(author: person)
        let owned = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let missing = AuthorBibliography.gaps(works: result.works, owned: owned, author: person)

        // Der Lauf ersetzt die Lücken dieses Verfassers vollständig. Sonst bleibt ein
        // Werk als Lücke stehen, das seit dem letzten Lauf ins Regal gewandert ist.
        for stale in gaps(author: person, in: context) { context.delete(stale) }

        var report = Report(works: result.works.count,
                            gaps: missing.count,
                            isComplete: result.isComplete)

        for (index, work) in missing.enumerated() {
            try Task.checkCancellation()
            let entry = MissingBook(isbn: work.isbn,
                                    title: work.title,
                                    author: work.author,
                                    year: work.year)
            context.insert(entry)

            if let path = try? await coverPath(for: work, lookup: lookup, cache: cache) {
                entry.coverPath = path
                report.covers += 1
            }
            try? context.save()
            progress?(index + 1, missing.count, work.title)
            if pause > 0, index + 1 < missing.count {
                try await Task.sleep(nanoseconds: pause)
            }
        }
        try? context.save()
        return report
    }

    /// Dieselbe Cover-Kette wie für den Bestand — die Lücke hat eine ISBN, also greift
    /// sie ab der ersten Stufe.
    private static func coverPath(for work: BibliographyWork,
                                  lookup: MetadataLookup,
                                  cache: CoverCache) async throws -> String? {
        guard let stem = CoverKey.stem(isbn: work.isbn, title: work.title, author: work.author),
              let url = await lookup.coverURL(isbn: work.isbn,
                                              title: work.title,
                                              author: work.author) else { return nil }
        let identity = CoverKey.identity(isbn: work.isbn, title: work.title, author: work.author)
        return try await cache.download(from: url, stem: stem, identity: identity)
    }
}
