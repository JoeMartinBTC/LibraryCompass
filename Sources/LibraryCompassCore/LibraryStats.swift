import Foundation

/// Ein Balken der Bewertungsverteilung (5 → 1 Sterne).
public struct RatingBar: Sendable, Equatable {
    public let stars: Int
    public let count: Int
}

/// Zahlen der drei Statistik-Karten (README §5.4) — immer über den Gesamtbestand,
/// nicht über die gefilterte Ansicht.
public struct LibraryStats: Sendable, Equatable {
    public let total: Int
    public let readCount: Int
    public let ratedCount: Int
    public let averageRating: Double
    public let distribution: [RatingBar]

    public var unreadCount: Int { total - readCount }

    /// Leseanteil in Prozent, kaufmännisch gerundet.
    public var readPercent: Int {
        total == 0 ? 0 : Int((Double(readCount) / Double(total) * 100).rounded())
    }

    public init<B: BookFields>(books: [B]) {
        var read = 0
        var rated = 0
        var sum = 0
        var buckets = [Int](repeating: 0, count: 6)

        for book in books {
            if book.readDate != nil { read += 1 }
            let rating = book.rating
            if rating > 0 {
                rated += 1
                sum += rating
                if rating <= 5 { buckets[rating] += 1 }
            }
        }

        total = books.count
        readCount = read
        ratedCount = rated
        averageRating = rated == 0 ? 0 : Double(sum) / Double(rated)
        distribution = (1...5).reversed().map { RatingBar(stars: $0, count: buckets[$0]) }
    }

    /// „Zuletzt gelesen" — nur gelesene Bücher, neueste zuerst, Titel als Zweitschlüssel.
    public static func recentlyRead<B: BookFields>(_ books: [B], limit: Int = 4) -> [B] {
        books
            .filter { $0.readDate != nil }
            .sorted { a, b in
                let da = a.readDate ?? .distantPast, db = b.readDate ?? .distantPast
                if da != db { return da > db }
                return BookQuery.compare(a.title, b.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
