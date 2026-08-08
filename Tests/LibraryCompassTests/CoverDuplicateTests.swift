import XCTest
@testable import LibraryCompassCore

/// Am echten Bestand gefunden (2026-08-08): „Leadership by the Book" und „Swoosh" trugen
/// **dasselbe** Bild — den HarperCollins-Platzhalter „COVER TO BE REVEALED", 15.419 Byte.
/// Der Größencheck greift dort nicht: er fängt 43-Byte-Fehlanzeigen, kein vollwertiges JPEG.
///
/// Der allgemeine Wächter dagegen ist nicht „kenne alle Platzhalter", sondern:
/// **dasselbe Bild darf nicht zweimal vergeben werden.** Zwei verschiedene Bücher mit
/// bitgleichem Cover sind kein Zufall, sondern ein Platzhalter — und ein falsches Cover
/// wiegt schwerer als ein fehlendes.
final class CoverDuplicateTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-dup-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSecondBookWithTheSameImageGetsNothing() async throws {
        let client = FixedImageClient()
        let cache = CoverCache(client: client, directory: directory)
        let url = URL(string: "https://m.media-amazon.com/images/P/0688172393.01.LZZZZZZZ.jpg")!

        let first = try await cache.download(from: url, stem: "0688172393")
        XCTAssertEqual(first, "0688172393.jpg")

        let second = try await cache.download(from: url, stem: "0887306225")
        XCTAssertNil(second, "bitgleiches Bild für ein anderes Buch ist ein Platzhalter")

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files.count, 1, "die verworfene Datei darf nicht liegenbleiben: \(files)")
    }

    /// Derselbe Stamm darf sein eigenes Bild erneut schreiben — ein Wiederholungslauf
    /// ist keine Doublette.
    func testSameBookMayOverwriteItsOwnImage() async throws {
        let client = FixedImageClient()
        let cache = CoverCache(client: client, directory: directory)
        let url = URL(string: "https://example.invalid/x.jpg")!

        let first = try await cache.download(from: url, stem: "9783442494033")
        let again = try await cache.download(from: url, stem: "9783442494033")
        XCTAssertEqual(first, "9783442494033.jpg")
        XCTAssertEqual(again, "9783442494033.jpg")
    }

    /// Verschiedene Bilder bleiben unberührt.
    func testDifferentImagesAreBothKept() async throws {
        let cache = CoverCache(client: VaryingImageClient(), directory: directory)
        let one = try await cache.download(from: URL(string: "https://example.invalid/1.jpg")!, stem: "1111111111")
        let two = try await cache.download(from: URL(string: "https://example.invalid/2.jpg")!, stem: "2222222222")
        XCTAssertNotNil(one)
        XCTAssertNotNil(two)
    }

    /// Der Wächter muss auch greifen, wenn das erste Bild aus einem früheren Lauf stammt
    /// und nur noch als Datei vorliegt.
    func testRecognisesImagesFromEarlierRuns() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = directory.appendingPathComponent("0688172393.jpg")
        try Data(repeating: 42, count: 15_419).write(to: existing)

        let cache = CoverCache(client: FixedImageClient(), directory: directory)
        let result = try await cache.download(from: URL(string: "https://example.invalid/x.jpg")!,
                                              stem: "0887306225")
        XCTAssertNil(result)
    }
}

/// Liefert immer dasselbe Bild — wie ein Verlagsplatzhalter.
private actor FixedImageClient: HTTPClient {
    func get(_ url: URL) async throws -> (Data, Int) {
        (Data(repeating: 42, count: 15_419), 200)
    }
}

private actor VaryingImageClient: HTTPClient {
    private var counter = 0
    func get(_ url: URL) async throws -> (Data, Int) {
        counter += 1
        return (Data(repeating: UInt8(counter), count: 15_419), 200)
    }
}
