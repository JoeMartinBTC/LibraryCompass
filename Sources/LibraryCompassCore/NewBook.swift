import Foundation

/// Ein neu erfasstes Buch — an einer Stelle gebaut, damit Scanner, ISBN-Dialog und
/// Import dieselbe Regel benutzen.
///
/// **Erfasst heißt gelesen** (Nutzerregel 2026-08-08: „Alle Bücher, die ich erfasse, sind
/// immer gelesen, sonst werden sie nicht erfasst"). Der Delicious-Library-Import hielt es
/// schon so — beim Erfassen von Hand fehlte es, und ein frisch aufgenommenes Buch stand
/// dadurch am Ende der Gelesen-Sortierung statt oben.
public enum NewBook {
    public static func make(isbn: String, addedDate: Date = Date()) -> Book {
        Book(isbn: isbn, title: "", author: "", readDate: addedDate, addedDate: addedDate)
    }
}
