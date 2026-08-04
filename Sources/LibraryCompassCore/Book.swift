import Foundation
import SwiftData

/// Ein Buch — genau die zehn Felder aus BUILD-HANDOVER §2. Kein Sync, nur lokal.
@Model
public final class Book: BookFields {
    /// ISBN-10 oder ISBN-13; leer erlaubt (~245 Bestandsbücher haben keine).
    public var isbn: String
    public var title: String
    public var author: String
    /// Dateiname im Cover-Cache, `nil` solange kein Bild vorliegt.
    public var coverPath: String?
    /// Eigene Sternebewertung 0–5.
    public var rating: Int
    public var comment: String
    public var readDate: Date?
    public var addedDate: Date
    public var year: Int?
    public var pages: Int?

    public init(isbn: String = "",
                title: String = "",
                author: String = "",
                coverPath: String? = nil,
                rating: Int = 0,
                comment: String = "",
                readDate: Date? = nil,
                addedDate: Date = Date(),
                year: Int? = nil,
                pages: Int? = nil) {
        self.isbn = isbn
        self.title = title
        self.author = author
        self.coverPath = coverPath
        self.rating = rating
        self.comment = comment
        self.readDate = readDate
        self.addedDate = addedDate
        self.year = year
        self.pages = pages
    }
}
