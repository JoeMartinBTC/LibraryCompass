import XCTest
@testable import LibraryCompassCore

/// Die Titelbereinigung gegen die echten Exportdaten — hier zeigt sich, ob die
/// Regel im Großen trägt und nichts kaputt macht. Geprüft wird das Test-Sample
/// (108 Bücher, der Stand, mit dem gestartet wird) und der Vollbestand.
final class TitleCleanupOriginalTests: XCTestCase {

    func testCleanupNeverEmptiesATitleOfTheRealLibrary() throws {
        try Fixtures.requireFile(Fixtures.originalURL)
        let raw = try DeliciousLibraryImport.parse(url: Fixtures.originalURL)

        var emptied = 0
        for book in raw.books where !book.title.isEmpty {
            if TitleCleanup.clean(book.title).isEmpty { emptied += 1 }
        }
        XCTAssertEqual(emptied, 0, "Bereinigung darf keinen Titel verschlucken")
    }

    /// Kein Titel darf länger werden, und die Kürzung muss ein Präfix bleiben —
    /// so kann die Regel den Titel nicht verfälschen, nur beschneiden.
    func testCleanedTitleIsAlwaysAPrefixOfTheOriginal() throws {
        try Fixtures.requireFile(Fixtures.originalURL)
        let raw = try DeliciousLibraryImport.parse(url: Fixtures.originalURL)

        var offenders: [String] = []
        for book in raw.books where !book.title.isEmpty {
            let cleaned = TitleCleanup.clean(book.title)
            let source = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !source.hasPrefix(cleaned) { offenders.append("\(source) → \(cleaned)") }
        }
        XCTAssertEqual(offenders, [], "Bereinigung darf nur kürzen, nicht umschreiben")
    }

    /// Das Sample sind die 108 Bücher, mit denen geprüft wird, bevor der volle
    /// Bestand kommt. Hier muss die Bereinigung sichtbar richtig arbeiten.
    func testSampleTitlesSurviveCleanup() throws {
        try Fixtures.requireFile(Fixtures.sampleURL)
        let raw = try DeliciousLibraryImport.parse(url: Fixtures.sampleURL)

        var changed: [(String, String)] = []
        for book in raw.books where !book.title.isEmpty {
            let source = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = TitleCleanup.clean(source)
            XCTAssertFalse(cleaned.isEmpty, "Titel verschluckt: \(source)")
            XCTAssertTrue(source.hasPrefix(cleaned), "umgeschrieben statt gekürzt: \(source) -> \(cleaned)")
            if cleaned != source { changed.append((source, cleaned)) }
        }
        print("Sample: \(raw.books.count) Bücher · bereinigt: \(changed.count)")
        for (before, after) in changed {
            print("  [\(before)] -> [\(after)]")
        }
    }

    /// Rein informativ: Wie viele Titel ändern sich überhaupt, und wie sehen sie aus?
    func testReportsHowManyTitlesChange() throws {
        try Fixtures.requireFile(Fixtures.originalURL)
        let raw = try DeliciousLibraryImport.parse(url: Fixtures.originalURL)

        var changed: [(String, String)] = []
        for book in raw.books where !book.title.isEmpty {
            let cleaned = TitleCleanup.clean(book.title)
            if cleaned != book.title.trimmingCharacters(in: .whitespacesAndNewlines) {
                changed.append((book.title, cleaned))
            }
        }
        print("Titel gesamt: \(raw.books.count) · bereinigt: \(changed.count)")
        for (before, after) in changed.prefix(15) {
            print("  [\(before)] -> [\(after)]")
        }
        XCTAssertLessThan(changed.count, raw.books.count / 2,
                          "Wenn die Hälfte aller Titel angefasst wird, greift die Regel zu weit")
    }
}
