import Foundation
import SwiftData

/// Ergebnis eines Imports. `summary` ist die Zeile, die ISC-5 prüft.
public struct ImportReport: Sendable, Equatable {
    public var imported: Int
    public var skippedDuplicates: Int
    public var skippedNonBooks: Int
    public var errors: Int

    public init(imported: Int = 0, skippedDuplicates: Int = 0, skippedNonBooks: Int = 0, errors: Int = 0) {
        self.imported = imported
        self.skippedDuplicates = skippedDuplicates
        self.skippedNonBooks = skippedNonBooks
        self.errors = errors
    }

    public var summary: String { "imported=\(imported) errors=\(errors)" }
}

/// Schreibt einen Delicious-Library-Export in den Store. Idempotent: bereits
/// vorhandene Bücher (ISBN, sonst Titel+Autor) werden übersprungen, eigene
/// Bewertungen und Kommentare bleiben dadurch unangetastet.
public enum LibraryImporter {

    public static func importFile(at url: URL,
                                  into context: ModelContext,
                                  progress: ((Int, Int) -> Void)? = nil) throws -> ImportReport {
        let parsed = try DeliciousLibraryImport.parse(url: url)
        return try importBooks(parsed, into: context, progress: progress)
    }

    static func importBooks(_ parsed: ParseResult,
                            into context: ModelContext,
                            progress: ((Int, Int) -> Void)? = nil) throws -> ImportReport {
        var known = Set<String>()
        for book in try context.fetch(FetchDescriptor<Book>()) {
            known.insert(DuplicateKey.make(isbn: book.isbn, title: book.title, author: book.author))
        }

        var report = ImportReport(skippedNonBooks: parsed.skippedNonBooks, errors: parsed.errors.count)
        let total = parsed.books.count

        for (index, imported) in parsed.books.enumerated() {
            let key = imported.duplicateKey
            if known.contains(key) {
                report.skippedDuplicates += 1
            } else {
                known.insert(key)
                context.insert(Book(isbn: imported.isbn,
                                    title: imported.title,
                                    author: imported.author,
                                    rating: imported.rating,
                                    comment: imported.comment,
                                    addedDate: imported.addedDate,
                                    year: imported.year,
                                    pages: imported.pages))
                report.imported += 1
            }
            if (index + 1) % 100 == 0 { progress?(index + 1, total) }
        }
        progress?(total, total)

        try context.save()
        return report
    }
}
