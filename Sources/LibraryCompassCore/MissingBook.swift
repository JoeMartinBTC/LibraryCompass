import Foundation
import SwiftData

/// Ein Werk, das der Katalog dem Verfasser zuschreibt und das **nicht** im Regal steht.
///
/// Bewusst ein **eigener Typ** und nicht ein Merkmal am `Book`: eine Lücke ist kein Buch
/// dieser Bibliothek. Als Merkmal müsste jeder Zähler, jeder Export und jede Statistik
/// sie einzeln ausschließen — und die eine Stelle, die man dabei vergisst, zählt sie
/// still zum Bestand. `FetchDescriptor<Book>` sieht diesen Typ gar nicht erst.
@Model
public final class MissingBook: BookFields {
    public var isbn: String
    public var title: String
    public var author: String
    /// Dateiname im selben Cover-Cache wie beim Bestand.
    public var coverPath: String?
    public var year: Int?
    /// Wann dieser Lauf die Lücke gefunden hat.
    public var foundDate: Date

    public init(isbn: String = "",
                title: String = "",
                author: String = "",
                coverPath: String? = nil,
                year: Int? = nil,
                foundDate: Date = Date()) {
        self.isbn = isbn
        self.title = title
        self.author = author
        self.coverPath = coverPath
        self.year = year
        self.foundDate = foundDate
    }

    // MARK: BookFields
    //
    // Damit Cover-Ansicht, Sortierung und Suche dieselben Bausteine benutzen wie der
    // Bestand. Was eine Lücke nicht hat, hat sie auch nicht: keine Bewertung, kein
    // Lesedatum, kein Kommentar — sie gehört einem ja nicht.

    public var rating: Int { 0 }
    public var comment: String { "" }
    public var readDate: Date? { nil }
    public var addedDate: Date { foundDate }
    public var pages: Int? { nil }
}
