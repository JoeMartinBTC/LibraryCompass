import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Der Dateistamm im Cover-Cache muss jedes Buch eindeutig treffen. Vorher lief der
/// Titel durch `ISBN.normalized` — bei Titeln ohne Ziffer blieb davon nichts übrig,
/// und 50 Bücher teilten sich die Datei `.jpg` (Befund 2026-08-08 am echten Bestand).
final class CoverKeyTests: XCTestCase {

    func testISBNBookUsesItsISBN() {
        XCTAssertEqual(CoverKey.stem(isbn: "978-3-442-49403-3", title: "Kill for me", author: "Cavanagh"),
                       "9783442494033")
    }

    func testTitleOnlyBooksNeverCollapseToEmpty() {
        let stem = try? XCTUnwrap(CoverKey.stem(isbn: "", title: "All the Devils", author: "Barry Eisler"))
        XCTAssertNotNil(stem)
        XCTAssertFalse((stem ?? "").isEmpty, "leerer Stamm erzeugt die Sammeldatei .jpg")
    }

    func testDifferentTitleOnlyBooksGetDifferentStems() throws {
        let one = try XCTUnwrap(CoverKey.stem(isbn: "", title: "All the Devils", author: "Barry Eisler"))
        let two = try XCTUnwrap(CoverKey.stem(isbn: "", title: "Die Chefs", author: "Hans Meier"))
        XCTAssertNotEqual(one, two)
    }

    /// Ein zweiter Lauf muss dieselbe Datei treffen, sonst wächst der Cache mit
    /// Karteileichen — deshalb Hash statt UUID.
    func testStemIsStableAcrossCalls() throws {
        let first = try XCTUnwrap(CoverKey.stem(isbn: "", title: "All the Devils", author: "Barry Eisler"))
        let second = try XCTUnwrap(CoverKey.stem(isbn: "", title: "All the Devils", author: "Barry Eisler"))
        XCTAssertEqual(first, second)
    }

    func testBookWithNeitherISBNNorTitleHasNoStem() {
        XCTAssertNil(CoverKey.stem(isbn: "", title: "", author: ""))
        XCTAssertNil(CoverKey.stem(isbn: "  ", title: "   ", author: " "))
    }

    /// Genau der Fall, der den Schaden anrichtete: Titel ohne jede Ziffer.
    func testTitleWithoutDigitsDoesNotProduceEmptyStem() throws {
        for title in ["All the Devils", "Die Chefs", "Sein letzter Auftrag"] {
            let stem = try XCTUnwrap(CoverKey.stem(isbn: "", title: title, author: "Autor"))
            XCTAssertFalse(stem.isEmpty, title)
        }
    }
}

/// Invariante statt Einmal-Messung: nach einem Nachlauf darf keine Cover-Datei von
/// zwei Büchern benutzt werden.
@MainActor
final class CoverCollisionTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-collision-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTwoBooksWithoutISBNDoNotShareOneFile() async throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "", title: "All the Devils", author: "Barry Eisler"))
        context.insert(Book(isbn: "", title: "Die Chefs", author: "Barry Eisler"))
        try context.save()

        let client = AnyCoverClient()
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        let cache = CoverCache(client: client, directory: directory)

        let report = try await CoverBackfill.run(context: context, lookup: lookup, cache: cache, pause: 0)
        XCTAssertEqual(report.filled, 2)

        let paths = try context.fetch(FetchDescriptor<Book>()).compactMap(\.coverPath)
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(Set(paths).count, 2, "beide Bücher zeigen auf dieselbe Datei: \(paths)")
        XCTAssertFalse(paths.contains(".jpg"), "leerer Dateistamm — genau der Bug vom 2026-08-08")
    }
}

/// Liefert zu jeder Titelsuche einen Treffer mit passendem Autor und ein Bild.
private actor AnyCoverClient: HTTPClient {
    func get(_ url: URL) async throws -> (Data, Int) {
        let address = url.absoluteString
        if address.contains("openlibrary.org/search.json") {
            let json = #"{"docs": [{"title": "Egal", "author_name": ["Barry Eisler"], "cover_i": 1}]}"#
            return (Data(json.utf8), 200)
        }
        if address.contains("covers.openlibrary.org") {
            return (Data(repeating: 7, count: 14_324), 200)
        }
        return (Data(), 404)
    }
}
