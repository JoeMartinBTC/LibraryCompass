import Foundation

/// Der Bestand als Datei für den Taschen-Viewer.
///
/// Zweck ist eine einzige Frage, unterwegs im Laden: **habe ich das schon?** Dafür braucht
/// es weder Bearbeiten noch Nachschlagen noch Cover-Beschaffung — nur Titel, Verfasser,
/// ISBN und ob das Buch gelesen ist.
///
/// Der Katalog ist winzig: 1840 Bücher sind 220 KB, gzip-komprimiert 75 KB. Die Cover
/// dagegen wiegen 63 MB — als 160-Pixel-Miniaturen noch rund 16 MB. Deshalb sind sie
/// getrennt: der Katalog kommt in einem Rutsch, die Bilder holt die Seite einzeln nach.
///
/// ⚠️ Die erzeugte Datei **ist** der private Bestand. Sie gehört nicht ins Repo und nicht
/// an eine öffentlich erratbare Adresse.
public enum LibraryWeb {

    /// Ein Eintrag, auf das Nötige gekürzt. Die Schlüssel sind einbuchstabig, weil sie
    /// sich 1840-mal wiederholen.
    public struct Entry: Codable, Equatable, Sendable {
        public let t: String        // Titel
        public let a: String        // Verfasser
        public let i: String        // ISBN, kanonisch (ISBN-13), leer wenn keine
        public let y: Int?          // Jahr
        public let r: Int           // Bewertung 0–5
        public let g: Bool          // gelesen
        public let c: String?       // Cover-Dateiname, nil wenn keins

        public init(book: some BookFields) {
            t = book.title
            a = book.author
            i = book.isbn.isEmpty ? "" : ISBN.canonical(book.isbn)
            y = book.year
            r = book.rating
            g = book.readDate != nil
            c = (book.coverPath?.isEmpty ?? true) ? nil : book.coverPath
        }
    }

    public struct Catalogue: Codable, Equatable, Sendable {
        public let version: Int
        /// Wann der Export lief. Die Seite zeigt es an, damit niemand einem alten Stand
        /// vertraut, ohne es zu merken — bei „habe ich das schon?" wäre das der ganze Fehler.
        public let exported: String
        public let count: Int
        public let books: [Entry]
    }

    /// Nach Titel sortiert: die Seite zeigt ohne eigenes Sortieren an.
    public static func catalogue(_ books: [some BookFields], date: Date) -> Catalogue {
        // Titellose Einträge ans Ende: sie stünden sonst ganz oben und wären das
        // Erste, was die Seite zeigt — als hätte die Bibliothek lauter leere Zeilen.
        let entries = books
            .map(Entry.init)
            .sorted {
                switch ($0.t.isEmpty, $1.t.isEmpty) {
                case (false, true): return true
                case (true, false): return false
                default: return $0.t.localizedCaseInsensitiveCompare($1.t) == .orderedAscending
                }
            }
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withFullDate]
        return Catalogue(version: 1, exported: stamp.string(from: date),
                         count: entries.count, books: entries)
    }

    /// Kompakt und stabil sortiert: zwei Exporte desselben Bestands ergeben dieselbe Datei.
    public static func json(_ catalogue: Catalogue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(catalogue)
    }

    /// Welche Cover der Viewer braucht — ohne Doppelte, in der Reihenfolge des Katalogs.
    public static func coverFiles(_ catalogue: Catalogue) -> [String] {
        var seen = Set<String>()
        return catalogue.books.compactMap(\.c).filter { seen.insert($0).inserted }
    }
}
