import Foundation
import SwiftData

/// Trägt fehlende Verfasser über den Titel bei der DNB nach.
///
/// Der Verfasser ist kein Schmuck im Datensatz, sondern der **Anker jeder weiteren
/// Suche**: ohne ihn darf die Titelsuche gar nicht erst laufen, weil sie ohne Abgleich
/// beliebige Bücher liefert — „Flashback" allein bringt neun verschiedene. Am 2026-08-10
/// standen 30 der 114 coverlosen Bücher ohne Verfasser da und waren damit dauerhaft von
/// der Coverbeschaffung ausgeschlossen.
///
/// Die Regel ist die schärfste, die überhaupt geht: **ein Titel, ein Verfasser.** Nennen
/// die Treffer zum Titel mehr als einen Namen, bleibt das Feld leer. Lieber kein Verfasser
/// als der falsche — ein falscher zieht anschließend ein falsches Cover nach sich, und
/// dann stehen zwei Fehler im Datensatz statt einer Lücke.
@MainActor
public enum AuthorBackfill {

    public struct Report: Sendable, Equatable {
        public var checked = 0
        public var filled = 0
        public var total = 0
        /// Titel, zu denen der Katalog mehrere Verfasser nennt — bewusst übergangen.
        public var ambiguous = 0

        public init(checked: Int = 0, filled: Int = 0, total: Int = 0, ambiguous: Int = 0) {
            self.checked = checked
            self.filled = filled
            self.total = total
            self.ambiguous = ambiguous
        }

        public var isComplete: Bool { checked >= total }

        public var summary: String {
            let base = "geprüft=\(checked)/\(total) ergänzt=\(filled) mehrdeutig=\(ambiguous)"
            return isComplete ? base : "ABBRUCH — \(base), \(total - checked) Bücher ungefragt"
        }
    }

    /// „unknown author" steht im Bestand aus dem Delicious-Library-Import und ist so gut
    /// wie leer — nur unehrlicher, weil es ein ausgefülltes Feld vortäuscht.
    static func hasNoAuthor(_ author: String) -> Bool {
        let value = author.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || value == "unknown author" || value == "unknown" || value == "-"
    }

    @discardableResult
    public static func run(context: ModelContext,
                           lookup: MetadataLookup = MetadataLookup(),
                           pause: UInt64 = 1_000_000_000,
                           progress: ((Int, Int, String) -> Void)? = nil) async throws -> Report {
        let books = try context.fetch(FetchDescriptor<Book>())
            .filter { hasNoAuthor($0.author) && !$0.title.isEmpty && $0.title != "Unbekannter Titel" }
        var report = Report(total: books.count)

        for book in books {
            try Task.checkCancellation()
            report.checked += 1
            if let author = try? await lookup.soleAuthor(title: book.title) {
                book.author = author
                report.filled += 1
                try? context.save()
            } else {
                report.ambiguous += 1
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
