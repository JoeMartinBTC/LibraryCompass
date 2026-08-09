import Foundation
import SwiftData

/// Setzt oder entfernt Cover für einzeln benannte Bücher — der Weg für Bilder, die
/// von Hand geprüft wurden.
///
/// Der automatische Nachlauf (`CoverBackfill`) entscheidet selbst und liegt dabei
/// manchmal falsch: am 2026-08-09 brachte er sieben Bilder, drei davon zeigten ein
/// anderes Werk. Die Gegenprobe ist immer ein Mensch, der das Bild ansieht — und der
/// braucht einen Weg, sein Urteil einzutragen, ohne den Store von Hand zu öffnen.
///
/// Die Zuweisungsdatei ist eine Zeile je Buch, Tabulator getrennt:
///
/// ```
/// 9783958905733   /pfad/zum/bild.jpg      ← Cover setzen
/// 3893170065                              ← Cover entfernen (zweites Feld leer)
/// ```
///
/// Der Schlüssel ist die ISBN des Eintrags oder — bei Büchern ohne ISBN — der
/// Titel-Hash aus `CoverKey.stem`. Beides trifft genau einen Eintrag; wo es das nicht
/// tut, bricht der Lauf lieber ab, als zu raten.
@MainActor
public enum CoverAssignment {

    public struct Report: Sendable, Equatable {
        public var assigned = 0
        public var cleared = 0
        public var total = 0
        /// Zeilen, die kein oder mehr als ein Buch trafen — mit Grund.
        public var problems: [String] = []

        public init(assigned: Int = 0, cleared: Int = 0, total: Int = 0, problems: [String] = []) {
            self.assigned = assigned
            self.cleared = cleared
            self.total = total
            self.problems = problems
        }

        /// Wie bei den anderen Läufen: nur ein restlos verarbeiteter Lauf ist ein Erfolg.
        public var isComplete: Bool { problems.isEmpty && assigned + cleared == total }

        public var summary: String {
            let base = "zugewiesen=\(assigned) entfernt=\(cleared) von \(total)"
            return isComplete ? base : "ABBRUCH — \(base), \(problems.count) Zeilen ohne eindeutiges Buch"
        }
    }

    public struct Line: Equatable, Sendable {
        public let key: String
        /// `nil` heißt: Cover entfernen.
        public let imagePath: String?

        public init(key: String, imagePath: String?) {
            self.key = key
            self.imagePath = imagePath
        }
    }

    /// Leerzeilen und `#`-Kommentare werden übergangen, damit die Datei erklärbar bleibt.
    public static func parse(_ text: String) -> [Line] {
        text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { return nil }
            let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            return Line(key: key, imagePath: value.isEmpty ? nil : value)
        }
    }

    /// Welche Bücher trägt dieser Schlüssel? Über die kanonische ISBN, damit
    /// `344247776X` und `9783442477760` denselben Eintrag treffen.
    static func matches(key: String, in books: [Book]) -> [Book] {
        // Zuerst der Titel-Hash: `ISBN.normalized` behält alle Ziffern, und in `t-a1b2`
        // stecken welche — ohne diese Weiche gilt der Hash als ISBN und trifft nichts.
        if key.hasPrefix("t-") {
            return books.filter {
                CoverKey.stem(isbn: $0.isbn, title: $0.title, author: $0.author) == key
            }
        }
        let wanted = ISBN.normalized(key)
        if !wanted.isEmpty {
            let canonical = ISBN.canonical(wanted)
            return books.filter { !$0.isbn.isEmpty && ISBN.canonical($0.isbn) == canonical }
        }
        return books.filter {
            CoverKey.stem(isbn: $0.isbn, title: $0.title, author: $0.author) == key
        }
    }

    @discardableResult
    public static func apply(_ lines: [Line],
                             context: ModelContext,
                             cache: CoverCache = .shared,
                             progress: ((Int, Int, String) -> Void)? = nil) async throws -> Report {
        let books = try context.fetch(FetchDescriptor<Book>())
        var report = Report(total: lines.count)

        for (index, line) in lines.enumerated() {
            let found = matches(key: line.key, in: books)
            guard found.count == 1, let book = found.first else {
                report.problems.append("\(line.key): \(found.count) Bücher getroffen")
                progress?(index + 1, lines.count, line.key)
                continue
            }

            if let path = line.imagePath {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                guard CoverCache.isUsableImage(data) else {
                    report.problems.append("\(line.key): \(data.count) Byte sind kein Bild")
                    progress?(index + 1, lines.count, book.title)
                    continue
                }
                guard let stem = CoverKey.stem(isbn: book.isbn, title: book.title, author: book.author) else {
                    report.problems.append("\(line.key): Buch hat weder ISBN noch Titel")
                    progress?(index + 1, lines.count, book.title)
                    continue
                }
                let identity = CoverKey.identity(isbn: book.isbn, title: book.title, author: book.author)
                guard let name = try await cache.store(data, stem: stem, identity: identity,
                                                       extension: (path as NSString).pathExtension) else {
                    report.problems.append("\(line.key): Bild gehört bereits einem anderen Buch")
                    progress?(index + 1, lines.count, book.title)
                    continue
                }
                book.coverPath = name
                report.assigned += 1
            } else {
                // Die Bilddatei bleibt liegen. Sie kann zu einem zweiten Eintrag desselben
                // Buchs gehören (der Bestand führt Dubletten), und eine Karteileiche im
                // Ordner ist harmlos — ein gelöschtes Cover eines anderen Buchs nicht.
                book.coverPath = nil
                report.cleared += 1
            }
            try? context.save()
            progress?(index + 1, lines.count, book.title)
        }

        try? context.save()
        return report
    }
}
