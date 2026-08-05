import Foundation

/// Ein aus dem Delicious-Library-Export gelesenes Buch, noch ohne Store.
public struct ImportedBook: Sendable, Equatable {
    public var isbn: String
    public var title: String
    public var author: String
    public var rating: Int
    public var comment: String
    public var addedDate: Date
    public var year: Int?
    public var pages: Int?

    public init(isbn: String = "",
                title: String = "",
                author: String = "",
                rating: Int = 0,
                comment: String = "",
                addedDate: Date = Date(),
                year: Int? = nil,
                pages: Int? = nil) {
        self.isbn = isbn
        self.title = title
        self.author = author
        self.rating = rating
        self.comment = comment
        self.addedDate = addedDate
        self.year = year
        self.pages = pages
    }

    /// Duplikat-Erkennung: per ISBN; ohne ISBN per (Titel, Autor) — BUILD-HANDOVER §3.
    public var duplicateKey: String {
        DuplicateKey.make(isbn: isbn, title: title, author: author)
    }
}

/// Erzeugt den Schlüssel, über den Import und Bestand abgeglichen werden.
public enum DuplicateKey {
    public static func make(isbn: String, title: String, author: String) -> String {
        let trimmedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedISBN.isEmpty { return "i:" + trimmedISBN.lowercased() }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "ta:\(t)|\(a)"
    }
}

public struct ParseResult: Sendable {
    public var books: [ImportedBook]
    public var skippedNonBooks: Int
    public var errors: [String]
}

public enum ImportError: Error, LocalizedError {
    case notAPropertyList
    case unexpectedRootType

    public var errorDescription: String? {
        switch self {
        case .notAPropertyList: "Die Datei ist keine gültige Delicious-Library-Datei (kein plist)."
        case .unexpectedRootType: "Unerwarteter Aufbau: erwartet wird eine Liste von Einträgen."
        }
    }
}

/// Liest den Delicious-Library-Export (Apple-plist-XML) und bildet ihn auf die zehn Felder ab.
/// Die Quelldatei wird nur gelesen, nie verändert.
public enum DeliciousLibraryImport {

    public static func parse(url: URL) throws -> ParseResult {
        try parse(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public static func parse(data: Data) throws -> ParseResult {
        let raw: Any
        do {
            raw = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw ImportError.notAPropertyList
        }
        guard let entries = raw as? [[String: Any]] else { throw ImportError.unexpectedRootType }

        var books: [ImportedBook] = []
        books.reserveCapacity(entries.count)
        var skippedNonBooks = 0
        let errors: [String] = []

        for entry in entries {
            guard (entry["type"] as? String) == "Book" else {
                skippedNonBooks += 1
                continue
            }
            books.append(map(entry))
        }

        return ParseResult(books: books, skippedNonBooks: skippedNonBooks, errors: errors)
    }

    /// Mapping-Tabelle aus BUILD-HANDOVER §2.
    static func map(_ entry: [String: Any]) -> ImportedBook {
        let isbn = string(entry["isbn"]).isEmpty ? string(entry["ean"]) : string(entry["isbn"])
        var book = ImportedBook()
        book.isbn = isbn
        book.title = string(entry["title"])
        book.author = string(entry["creatorsCompositeString"])
        book.comment = multiline(entry["notes"])
        book.rating = rating(entry["rating"])
        book.addedDate = (entry["creationDate"] as? Date) ?? Date()
        book.year = year(from: entry["publishDate"])
        if let pages = entry["pages"] as? Int, pages > 0 { book.pages = pages }
        // readDate bleibt leer: `hasExperienced` wurde in Delicious Library nie gepflegt.
        return book
    }

    private static func string(_ value: Any?) -> String {
        guard let text = value as? String else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Notizen dürfen mehrzeilig sein — nur außen trimmen, Zeilenumbrüche bleiben.
    private static func multiline(_ value: Any?) -> String {
        guard let text = value as? String else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func rating(_ value: Any?) -> Int {
        let raw: Double
        switch value {
        case let number as Double: raw = number
        case let number as Int: raw = Double(number)
        default: return 0
        }
        return min(5, max(0, Int(raw.rounded())))
    }

    static func year(from value: Any?) -> Int? {
        guard let date = value as? Date else { return nil }
        return Calendar.current.component(.year, from: date)
    }
}
