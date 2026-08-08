import Foundation
import SwiftData

/// Trägt bei Bestandsbüchern ohne ISBN eine nach, sofern die Deutsche Nationalbibliothek
/// sie über Titel und Verfasser belegt.
///
/// Warum das eigene Arbeit ist und nicht Teil des Cover-Nachlaufs: eine fehlende ISBN und
/// ein fehlendes Bild sind zwei verschiedene Lücken. Die ISBN ist für sich wertvoll — und
/// erst sie öffnet die einzige ausgabegenaue Coverquelle (Amazon über ISBN-10). Beide
/// Läufe müssen getrennt wiederholbar sein; dieselbe Lehre wie „Metadaten-Treffer und
/// Cover-Treffer nicht koppeln".
@MainActor
public enum ISBNBackfill {

    public struct Report: Sendable, Equatable {
        public var checked = 0
        public var filled = 0
        public var total = 0

        public init(checked: Int = 0, filled: Int = 0, total: Int = 0) {
            self.checked = checked
            self.filled = filled
            self.total = total
        }

        public var isComplete: Bool { checked >= total }

        public var summary: String {
            let base = "geprüft=\(checked)/\(total) ergänzt=\(filled)"
            return isComplete ? base : "ABBRUCH — \(base), \(total - checked) Bücher ungefragt"
        }
    }

    @discardableResult
    public static func run(context: ModelContext,
                           lookup: MetadataLookup = MetadataLookup(),
                           pause: UInt64 = 1_000_000_000,
                           progress: ((Int, Int, String) -> Void)? = nil) async throws -> Report {
        // Ohne Autor gibt es nichts zu belegen — ein Titeltreffer allein reicht nicht.
        let books = try context.fetch(FetchDescriptor<Book>())
            .filter { $0.isbn.isEmpty && !$0.title.isEmpty && !$0.author.isEmpty }
        var report = Report(total: books.count)

        for book in books {
            try Task.checkCancellation()
            report.checked += 1
            if let isbn = try? await lookup.isbn(title: book.title, author: book.author) {
                book.isbn = isbn
                report.filled += 1
                try? context.save()
            }
            progress?(report.checked, report.total, book.title)
            if pause > 0, report.checked < report.total {
                try await Task.sleep(nanoseconds: pause)
            }
        }
        try? context.save()
        return report
    }
}
