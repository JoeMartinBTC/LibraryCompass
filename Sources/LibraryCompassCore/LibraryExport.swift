import Foundation

/// Die Bibliothek als CSV — eine Zeile je Buch, alle zehn Felder.
/// Trennzeichen ist das Komma nach RFC 4180; das BOM am Anfang sorgt dafür, dass
/// Excel die Umlaute richtig anzeigt.
public enum LibraryExport {
    public static let header = "ISBN,Titel,Autor,Jahr,Seiten,Bewertung,Kommentar,Gelesen am,Erfasst am,Cover"
    public static let fileName = "LibraryCompass.csv"

    public static func csv(_ books: [some BookFields]) -> String {
        var lines = ["\u{FEFF}" + header]
        for book in books {
            lines.append([
                book.isbn,
                book.title,
                book.author,
                book.year.map(String.init) ?? "",
                book.pages.map(String.init) ?? "",
                String(book.rating),
                book.comment,
                book.readDate.map(day) ?? "",
                day(book.addedDate),
                book.coverPath ?? ""
            ].map(escaped).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Nur Komma, Anführungszeichen und Zeilenumbruch erzwingen Anführungszeichen.
    private static func escaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
