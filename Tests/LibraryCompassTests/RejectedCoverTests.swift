import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Am 2026-08-09 wurden drei falsche Cover von Hand zurückgenommen. Der `--fetch-covers`
/// am nächsten Morgen holte zwei davon wieder — die Kette findet dieselbe Quelle ja
/// erneut. Eine Korrektur, die der nächste Lauf zurückdreht, ist keine Korrektur.
@MainActor
final class RejectedCoverTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-reject-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRejectedImageIsNotDownloadedAgain() async throws {
        let cache = CoverCache(client: SameImageClient(), directory: directory)
        let url = URL(string: "https://m.media-amazon.com/images/P/3485005959.01.LZZZZZZZ.jpg")!

        let first = try await cache.download(from: url, stem: "3485005959", identity: "9783485005951")
        XCTAssertEqual(first, "3485005959.jpg")

        try await cache.reject(imageNamed: "3485005959.jpg", for: "9783485005951")

        let again = try await cache.download(from: url, stem: "3485005959", identity: "9783485005951")
        XCTAssertNil(again, "das verworfene Bild darf nicht zurückkommen")
    }

    /// Die Sperre gilt **einem Bild**, nicht dem Buch. Sonst wäre ein Buch nach einer
    /// Rücknahme für immer coverlos — und der Sinn der Rücknahme ist ja, Platz für das
    /// richtige Bild zu machen.
    func testTheBookCanStillGetADifferentCover() async throws {
        let cache = CoverCache(client: SameImageClient(), directory: directory)
        _ = try await cache.download(from: URL(string: "https://example.invalid/falsch.jpg")!,
                                     stem: "3485005959", identity: "9783485005951")
        try await cache.reject(imageNamed: "3485005959.jpg", for: "9783485005951")

        let right = try await cache.store(Data(repeating: 99, count: 44_000),
                                          stem: "3485005959", identity: "9783485005951")
        XCTAssertEqual(right, "3485005959.jpg", "das richtige Cover muss weiterhin zuweisbar sein")
    }

    /// Die Sperre überlebt den Prozess — sie liegt neben den Covern.
    func testRejectionSurvivesANewCacheInstance() async throws {
        let first = CoverCache(client: SameImageClient(), directory: directory)
        _ = try await first.download(from: URL(string: "https://example.invalid/a.jpg")!,
                                     stem: "3485005959", identity: "9783485005951")
        try await first.reject(imageNamed: "3485005959.jpg", for: "9783485005951")

        let second = CoverCache(client: SameImageClient(), directory: directory)
        let again = try await second.download(from: URL(string: "https://example.invalid/a.jpg")!,
                                              stem: "3485005959", identity: "9783485005951")
        XCTAssertNil(again, "die Sperre steht in einer Datei, nicht im Arbeitsspeicher")
    }

    /// Die Rücknahme über `--apply-covers` trägt die Sperre selbst ein — von Hand
    /// nachzupflegen wäre eine Regel, die man vergisst.
    func testClearingACoverRecordsTheRejection() async throws {
        let container = try LibraryStore.inMemoryContainer()
        let context = ModelContext(container)
        let cache = CoverCache(client: SameImageClient(), directory: directory)

        // Ein Bild, das dem Buch bereits zugewiesen ist.
        let name = try await cache.store(Data(repeating: 7, count: 30_000),
                                         stem: "3485005959", identity: "9783485005951")
        let book = Book(isbn: "3485005959", title: "Depesche aus dem Jenseits",
                        author: "Pierre Bellemare", coverPath: name)
        context.insert(book)

        _ = try await CoverAssignment.apply([.init(key: "3485005959", imagePath: nil)],
                                            context: context, cache: cache)
        XCTAssertNil(book.coverPath)

        let back = try await cache.store(Data(repeating: 7, count: 30_000),
                                         stem: "3485005959", identity: "9783485005951")
        XCTAssertNil(back, "nach der Rücknahme darf dasselbe Bild nicht wieder abgelegt werden")
    }
}

private actor SameImageClient: HTTPClient {
    func get(_ url: URL) async throws -> (Data, Int) {
        (Data(repeating: 42, count: 30_000), 200)
    }
}
