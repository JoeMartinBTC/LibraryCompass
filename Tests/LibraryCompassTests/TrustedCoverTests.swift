import XCTest
@testable import LibraryCompassCore

/// Für 96 Bücher gibt es kein Cover bei einer Quelle, die die App abfragen darf: alte
/// deutsche Ausgaben, die kein freier Katalog je erfasst hat, und Selbstverlagstitel ohne
/// ISBN-10. Sichtbar sind die Bilder trotzdem — nur dort, wo ein Mensch nachsehen darf
/// und ein Programm nicht (`amazon.de/robots.txt` schließt automatisierte Zugriffe aus).
///
/// Also nimmt die App das Bild von ihm entgegen. Und für ein Bild, das jemand vor Augen
/// hatte, gelten die Wächter nicht mehr: sie ersetzen ein Urteil, das hier vorliegt.
@MainActor
final class TrustedCoverTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-trusted-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var image: Data { Data(repeating: 5, count: 40_000) }

    /// Der Platzhalter-Wächter schließt aus dem *Verdacht*, zwei gleiche Bilder seien ein
    /// Verlagsplatzhalter. Wer das Bild ansieht, weiß es besser.
    func testHumanAssignmentOverridesTheDuplicateGuard() async throws {
        let cache = CoverCache(directory: directory)
        let first = try await cache.store(image, stem: "9783958905733", identity: "9783958905733")
        XCTAssertNotNil(first)

        let blocked = try await cache.store(image, stem: "9783442477760", identity: "9783442477760")
        XCTAssertNil(blocked, "automatisch bleibt es blockiert")

        let trusted = try await cache.store(image, stem: "9783442477760",
                                            identity: "9783442477760", trusted: true)
        XCTAssertEqual(trusted, "9783442477760.jpg")
    }

    /// Eine frühere Rücknahme ist ein automatisches Urteil. Weist jemand dasselbe Bild
    /// bewusst zu, ist die Sperre widerrufen — und muss auch aus der Liste verschwinden,
    /// sonst greift sie beim nächsten Lauf wieder.
    func testHumanAssignmentLiftsAnEarlierRejection() async throws {
        let cache = CoverCache(directory: directory)
        _ = try await cache.store(image, stem: "3485005959", identity: "9783485005951")
        try await cache.reject(imageNamed: "3485005959.jpg", for: "9783485005951")
        let rejectedNow = try await cache.isRejected(image, identity: "9783485005951")
        XCTAssertTrue(rejectedNow)

        let trusted = try await cache.store(image, stem: "3485005959",
                                            identity: "9783485005951", trusted: true)
        XCTAssertEqual(trusted, "3485005959.jpg")
        let stillRejected = try await cache.isRejected(image, identity: "9783485005951")
        XCTAssertFalse(stillRejected, "die Sperre ist widerrufen, nicht nur einmal übergangen")
    }

    /// Anti: Die Mindestgröße gilt weiter. Eine 43-Byte-Fehlanzeige ist kein Bild, egal
    /// wer sie zuweist — und beim Ziehen aus dem Browser landet so etwas leicht im Panel.
    func testMinimumSizeStillApplies() async throws {
        let cache = CoverCache(directory: directory)
        let tiny = try await cache.store(Data(repeating: 0, count: 43), stem: "9783958905733",
                                         identity: "9783958905733", trusted: true)
        XCTAssertNil(tiny)
    }

    /// Anti: Ohne Dateistamm gibt es nichts abzulegen.
    func testEmptyStemIsRejected() async throws {
        let cache = CoverCache(directory: directory)
        let nothing = try await cache.store(image, stem: "", trusted: true)
        XCTAssertNil(nothing)
    }
}

/// Die Suchadresse, die dem Nutzer geöffnet wird. Die App ruft sie nicht selbst ab —
/// `amazon.de/robots.txt` schließt automatisierte Zugriffe aus, ein Mensch ist davon
/// nicht betroffen.
final class CoverSearchTests: XCTestCase {

    func testTitleAndAuthorBecomeOneQuery() throws {
        let url = try XCTUnwrap(CoverSearch.url(title: "Der Sandmann", author: "Dawson, Mark"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "k" }?.value, "Der Sandmann Dawson, Mark")
        XCTAssertEqual(items.first { $0.name == "i" }?.value, "stripbooks",
                       "auf Bücher eingrenzen — sonst kommen Hörspiele und Filme")
    }

    /// Umlaute und Leerzeichen müssen in der Adresse kodiert ankommen.
    func testSpecialCharactersAreEncoded() throws {
        let url = try XCTUnwrap(CoverSearch.url(title: "Über Tyrannei", author: "Snyder"))
        XCTAssertTrue(url.absoluteString.contains("%C3%9Cber") || url.absoluteString.contains("%C3%BC"),
                      "Umlaut kodiert: \(url.absoluteString)")
        XCTAssertFalse(url.absoluteString.contains(" "))
    }

    /// Ein Buch ohne Verfasser wird trotzdem gesucht — der Nutzer sieht ja, was kommt.
    func testTitleAloneIsEnough() throws {
        let url = try XCTUnwrap(CoverSearch.url(title: "Montecrypto", author: ""))
        XCTAssertTrue(url.absoluteString.contains("Montecrypto"))
    }

    /// Anti: Ohne beides gibt es nichts zu suchen.
    func testNothingToSearchYieldsNil() {
        XCTAssertNil(CoverSearch.url(title: "", author: ""))
        XCTAssertNil(CoverSearch.url(title: "   ", author: "  "))
    }
}
