import Foundation
import SwiftData

/// Setzt oder entfernt Verfasser für einzeln benannte Bücher.
///
/// Das Gegenstück zu `CoverAssignment` für das Feld, das jede weitere Suche trägt. Nötig
/// geworden am 2026-08-10: ein Nachlauf trug 80 Verfasser ein, von denen 40 sich nicht
/// belegen ließen und einige nachweislich falsch waren („Phantom" → „Matsuri", während
/// die DNB zu dem Titel 4921 Datensätze führt). Ohne einen Weg zurück bleibt so ein
/// Lauf für immer in den Daten stehen.
///
/// Format wie bei den Covern — eine Zeile je Buch, Tabulator getrennt, zweites Feld leer
/// heißt entfernen:
///
/// ```
/// 9783958905733   Chodorkowski, Michail
/// t-11eee9f8baba75f8
/// ```
@MainActor
public enum AuthorAssignment {

    public struct Report: Sendable, Equatable {
        public var assigned = 0
        public var cleared = 0
        public var total = 0
        public var problems: [String] = []

        public init(assigned: Int = 0, cleared: Int = 0, total: Int = 0, problems: [String] = []) {
            self.assigned = assigned
            self.cleared = cleared
            self.total = total
            self.problems = problems
        }

        public var isComplete: Bool { problems.isEmpty && assigned + cleared == total }

        public var summary: String {
            let base = "gesetzt=\(assigned) geleert=\(cleared) von \(total)"
            return isComplete ? base : "ABBRUCH — \(base), \(problems.count) Zeilen ohne eindeutiges Buch"
        }
    }

    @discardableResult
    public static func apply(_ lines: [CoverAssignment.Line],
                             context: ModelContext,
                             progress: ((Int, Int, String) -> Void)? = nil) throws -> Report {
        let books = try context.fetch(FetchDescriptor<Book>())
        var report = Report(total: lines.count)

        for (index, line) in lines.enumerated() {
            let found = CoverAssignment.matches(key: line.key, in: books)
            guard found.count == 1, let book = found.first else {
                report.problems.append("\(line.key): \(found.count) Bücher getroffen")
                progress?(index + 1, lines.count, line.key)
                continue
            }
            if let author = line.imagePath {          // zweites Feld = Verfasser
                book.author = author
                report.assigned += 1
            } else {
                book.author = ""
                report.cleared += 1
            }
            try? context.save()
            progress?(index + 1, lines.count, book.title)
        }
        try? context.save()
        return report
    }
}
