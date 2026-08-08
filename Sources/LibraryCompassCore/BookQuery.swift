import Foundation

/// Die vier Filterzeilen der Seitenleiste (README §5.1). Kein Genre — User-Entscheid 2026-08-04.
public enum LibraryFilter: String, CaseIterable, Sendable {
    case alle, gelesen, ungelesen, bewertet

    public var title: String {
        switch self {
        case .alle: "Alle Bücher"
        case .gelesen: "Gelesen"
        case .ungelesen: "Ungelesen"
        case .bewertet: "Bewertet"
        }
    }
}

/// Sortier-Optionen der Toolbar, Beschriftungen exakt wie in README §5.2.
public enum LibrarySort: String, CaseIterable, Sendable {
    case titel, autor, jahr, bewertung, zuletztGelesen, zuletztHinzugefügt, ohneCover

    public var title: String {
        switch self {
        case .titel: "Titel A–Z"
        case .autor: "Autor A–Z"
        // „Jahr" allein wurde als Erfassungsdatum gelesen — es ist das Erscheinungsjahr.
        case .jahr: "Erscheinungsjahr, neueste zuerst"
        case .bewertung: "Bewertung, beste zuerst"
        case .zuletztGelesen: "Zuletzt gelesen"
        case .zuletztHinzugefügt: "Zuletzt hinzugefügt"
        case .ohneCover: "Ohne Cover zuerst"
        }
    }
}

/// Zähler der Filterzeilen — unabhängig von Suche und Sortierung.
public struct FilterCounts: Sendable, Equatable {
    public init() {}

    public var alle = 0
    public var gelesen = 0
    public var ungelesen = 0
    public var bewertet = 0

    public subscript(filter: LibraryFilter) -> Int {
        switch filter {
        case .alle: alle
        case .gelesen: gelesen
        case .ungelesen: ungelesen
        case .bewertet: bewertet
        }
    }
}

/// Auswertung in der Reihenfolge Filter → Suche → Sortierung (README §7).
/// Das Limit setzt die Ansicht selbst, damit Nachladen nicht neu sortiert.
public struct BookQuery: Sendable, Equatable {
    public var filter: LibraryFilter
    public var search: String
    public var sort: LibrarySort

    public init(filter: LibraryFilter = .alle, search: String = "", sort: LibrarySort = .titel) {
        self.filter = filter
        self.search = search
        self.sort = sort
    }

    private static let german = Locale(identifier: "de_DE")

    /// Deutsche Collation, Groß-/Kleinschreibung egal (README §7).
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [.caseInsensitive], range: nil, locale: german)
    }

    public func apply<B: BookFields>(to books: [B]) -> [B] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var rows = books.filter { book in
            switch filter {
            case .alle: true
            case .gelesen: book.readDate != nil
            case .ungelesen: book.readDate == nil
            case .bewertet: book.rating > 0
            }
        }

        if !needle.isEmpty {
            rows = rows.filter { book in
                book.title.lowercased().contains(needle) || book.author.lowercased().contains(needle)
            }
        }

        return sorted(rows)
    }

    private func sorted<B: BookFields>(_ rows: [B]) -> [B] {
        switch sort {
        case .titel:
            return rows.sorted { Self.compare($0.title, $1.title) == .orderedAscending }
        case .autor:
            return rows.sorted { a, b in
                switch Self.compare(a.author, b.author) {
                case .orderedAscending: true
                case .orderedDescending: false
                case .orderedSame: Self.compare(a.title, b.title) == .orderedAscending
                }
            }
        case .jahr:
            return rows.sorted { a, b in
                let ya = a.year ?? Int.min, yb = b.year ?? Int.min
                if ya != yb { return ya > yb }
                return Self.compare(a.title, b.title) == .orderedAscending
            }
        case .bewertung:
            return rows.sorted { a, b in
                if a.rating != b.rating { return a.rating > b.rating }
                return Self.compare(a.title, b.title) == .orderedAscending
            }
        case .zuletztGelesen:
            return rows.sorted { a, b in
                let da = a.readDate?.timeIntervalSince1970 ?? -.greatestFiniteMagnitude
                let db = b.readDate?.timeIntervalSince1970 ?? -.greatestFiniteMagnitude
                if da != db { return da > db }
                return Self.compare(a.title, b.title) == .orderedAscending
            }
        case .zuletztHinzugefügt:
            // Das einzige Datum, das jedes Buch führt. „Zuletzt gelesen" hilft beim
            // frisch Erfassten nicht: ohne Lesedatum landet es ganz hinten — und genau
            // dieses Buch sucht man gerade.
            return rows.sorted { a, b in
                let da = a.addedDate.timeIntervalSince1970, db = b.addedDate.timeIntervalSince1970
                if da != db { return da > db }
                return Self.compare(a.title, b.title) == .orderedAscending
            }
        case .ohneCover:
            // Die bebilderten Bücher verschwinden nicht, sie rücken nach hinten — so
            // lassen sich die Lücken am Stück durchsehen, ohne den Bestand zu filtern.
            return rows.sorted { a, b in
                let ma = (a.coverPath ?? "").isEmpty, mb = (b.coverPath ?? "").isEmpty
                if ma != mb { return ma }
                return Self.compare(a.title, b.title) == .orderedAscending
            }
        }
    }

    /// Zähler für die Seitenleiste — immer über den Gesamtbestand.
    public func counts<B: BookFields>(for books: [B]) -> FilterCounts {
        var counts = FilterCounts()
        counts.alle = books.count
        for book in books {
            if book.readDate != nil { counts.gelesen += 1 } else { counts.ungelesen += 1 }
            if book.rating > 0 { counts.bewertet += 1 }
        }
        return counts
    }
}
