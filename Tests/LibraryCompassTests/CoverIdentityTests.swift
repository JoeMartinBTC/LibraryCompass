import XCTest
@testable import LibraryCompassCore

/// Der Platzhalter-Wächter („dasselbe Bild nie an zwei Bücher") traf einen Fall, für den
/// er nicht gedacht war: **dasselbe Buch, zweimal erfasst.** „Cobra" von Forsyth steht
/// zweimal im Bestand — einmal als ISBN-10 `344247776X`, einmal als ISBN-13
/// `9783442477760`. Beide bezeichnen dieselbe Ausgabe, Amazon liefert dasselbe Bild, und
/// der zweite Eintrag blieb deshalb ohne Cover.
///
/// Die Unterscheidung ist nicht „gleiches Bild", sondern **„gleiches Buch"**.
final class CoverIdentityTests: XCTestCase {

    func testISBN10AndISBN13OfTheSameEditionShareOneIdentity() {
        let ten = CoverKey.identity(isbn: "344247776X", title: "Cobra", author: "Forsyth")
        let thirteen = CoverKey.identity(isbn: "9783442477760", title: "Cobra", author: "Forsyth")
        XCTAssertEqual(ten, thirteen)
        XCTAssertEqual(ten, "9783442477760", "kanonisch ist die ISBN-13")
    }

    func testDifferentBooksHaveDifferentIdentities() {
        XCTAssertNotEqual(CoverKey.identity(isbn: "9783442494033", title: "A", author: "X"),
                          CoverKey.identity(isbn: "9783442477760", title: "B", author: "Y"))
    }

    /// Ohne ISBN bleibt der Titel-Hash die Kennung — zwei verschiedene Bücher bleiben
    /// dadurch unterscheidbar.
    func testTitleOnlyBooksKeepTheirHashIdentity() {
        let one = CoverKey.identity(isbn: "", title: "All the Devils", author: "Eisler")
        let two = CoverKey.identity(isbn: "", title: "Die Chefs", author: "Eisler")
        XCTAssertNotNil(one)
        XCTAssertNotEqual(one, two)
    }

    /// Der Dateistamm bleibt die ISBN in der Schreibweise des Buchs — bestehende
    /// Cover-Dateien behalten ihren Namen, es gibt keine Umbenennungsaktion.
    func testStemStaysInTheBooksOwnNotation() {
        XCTAssertEqual(CoverKey.stem(isbn: "344247776X", title: "Cobra", author: "Forsyth"), "344247776X")
        XCTAssertEqual(CoverKey.stem(isbn: "9783442477760", title: "Cobra", author: "Forsyth"), "9783442477760")
    }
}

/// Der Wächter muss weiter greifen, wo er soll — und nicht mehr, wo er nicht soll.
final class CoverIdentityCacheTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-ident-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Der Fall „Cobra": zwei Einträge desselben Buchs dürfen dasselbe Bild bekommen.
    func testSameBookInTwoNotationsBothGetTheCover() async throws {
        let cache = CoverCache(client: SameImageClient(), directory: directory)
        let url = URL(string: "https://m.media-amazon.com/images/P/344247776X.01.LZZZZZZZ.jpg")!

        let first = try await cache.download(from: url, stem: "344247776X", identity: "9783442477760")
        let second = try await cache.download(from: url, stem: "9783442477760", identity: "9783442477760")

        XCTAssertEqual(first, "344247776X.jpg")
        XCTAssertEqual(second, "9783442477760.jpg", "derselbe Titel darf sein Bild zweimal bekommen")
    }

    /// Anti: Der Platzhalter bleibt blockiert — verschiedene Bücher, gleiches Bild.
    func testDifferentBooksStillRejected() async throws {
        let cache = CoverCache(client: SameImageClient(), directory: directory)
        let url = URL(string: "https://example.invalid/placeholder.jpg")!

        let first = try await cache.download(from: url, stem: "0688172393", identity: "9780688172398")
        let second = try await cache.download(from: url, stem: "0887306225", identity: "9780887306228")

        XCTAssertNotNil(first)
        XCTAssertNil(second, "HarperCollins-Platzhalter muss weiter abgewiesen werden")
    }
}

private actor SameImageClient: HTTPClient {
    func get(_ url: URL) async throws -> (Data, Int) {
        (Data(repeating: 11, count: 64_540), 200)
    }
}
