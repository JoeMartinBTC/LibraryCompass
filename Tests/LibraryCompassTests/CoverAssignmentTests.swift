import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Der Nachlauf entscheidet selbst und liegt manchmal falsch: am 2026-08-09 brachte er
/// sieben Cover, drei zeigten ein anderes Werk („Der Fälscher aus dem Jenseits" statt
/// „Depesche aus dem Jenseits"). Die Korrektur von Hand braucht einen Weg in den Store,
/// der dieselben Wächter durchläuft wie der automatische Lauf.
@MainActor
final class CoverAssignmentParseTests: XCTestCase {

    func testReadsKeyAndImagePath() {
        let lines = CoverAssignment.parse("9783958905733\t/tmp/bild.jpg")
        XCTAssertEqual(lines, [.init(key: "9783958905733", imagePath: "/tmp/bild.jpg")])
    }

    /// Ein leeres zweites Feld nimmt ein falsches Cover zurück.
    func testEmptySecondFieldMeansRemoval() {
        XCTAssertEqual(CoverAssignment.parse("3893170065\t"), [.init(key: "3893170065", imagePath: nil)])
        XCTAssertEqual(CoverAssignment.parse("3893170065"), [.init(key: "3893170065", imagePath: nil)])
    }

    func testSkipsBlankLinesAndComments() {
        let text = """
        # Cover-Korrektur 2026-08-09

        9783958905733\t/tmp/a.jpg
        """
        XCTAssertEqual(CoverAssignment.parse(text).count, 1)
    }

    /// Dateipfade dürfen Leerzeichen enthalten — getrennt wird nur am ersten Tabulator.
    func testPathWithSpacesSurvives() {
        let lines = CoverAssignment.parse("123\t/tmp/mein bild.jpg")
        XCTAssertEqual(lines.first?.imagePath, "/tmp/mein bild.jpg")
    }
}

@MainActor
final class CoverAssignmentApplyTests: XCTestCase {

    private var directory: URL!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lc-assign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try LibraryStore.inMemoryContainer()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func image(_ byte: UInt8) throws -> String {
        let url = directory.appendingPathComponent("quelle-\(byte).jpg")
        try Data(repeating: byte, count: 40_000).write(to: url)
        return url.path
    }

    func testAssignsCoverToTheNamedBook() async throws {
        let context = ModelContext(container)
        let book = Book(isbn: "9783958905733", title: "Wie man einen Drachen tötet", author: "Chodorkowski")
        context.insert(book)

        let cache = CoverCache(directory: directory.appendingPathComponent("cache"))
        let report = try await CoverAssignment.apply(
            [.init(key: "9783958905733", imagePath: try image(1))], context: context, cache: cache)

        XCTAssertEqual(report.assigned, 1)
        XCTAssertTrue(report.isComplete)
        XCTAssertEqual(book.coverPath, "9783958905733.jpg")
    }

    /// Der Schlüssel darf die andere Schreibweise derselben Ausgabe sein.
    func testISBN10KeyFindsTheISBN13Entry() async throws {
        let context = ModelContext(container)
        let book = Book(isbn: "9783442477760", title: "Cobra", author: "Forsyth")
        context.insert(book)

        let cache = CoverCache(directory: directory.appendingPathComponent("cache"))
        let report = try await CoverAssignment.apply(
            [.init(key: "344247776X", imagePath: try image(2))], context: context, cache: cache)

        XCTAssertEqual(report.assigned, 1)
        XCTAssertEqual(book.coverPath, "9783442477760.jpg", "Dateistamm folgt dem Eintrag")
    }

    func testEmptyPathRemovesTheWrongCover() async throws {
        let context = ModelContext(container)
        let book = Book(isbn: "3485005959", title: "Depesche aus dem Jenseits",
                        author: "Pierre Bellemare", coverPath: "3485005959.jpg")
        context.insert(book)

        let report = try await CoverAssignment.apply(
            [.init(key: "3485005959", imagePath: nil)], context: context,
            cache: CoverCache(directory: directory.appendingPathComponent("cache")))

        XCTAssertEqual(report.cleared, 1)
        XCTAssertNil(book.coverPath)
    }

    /// Bücher ohne ISBN werden über den Titel-Hash angesprochen.
    func testBookWithoutISBNIsAddressedByStem() async throws {
        let context = ModelContext(container)
        let book = Book(isbn: "", title: "Missing. New York", author: "Winslow",
                        coverPath: "t-alt.jpg")
        context.insert(book)
        let stem = try XCTUnwrap(CoverKey.stem(isbn: "", title: "Missing. New York", author: "Winslow"))

        let report = try await CoverAssignment.apply(
            [.init(key: stem, imagePath: nil)], context: context,
            cache: CoverCache(directory: directory.appendingPathComponent("cache")))

        XCTAssertEqual(report.cleared, 1)
        XCTAssertNil(book.coverPath)
    }

    /// Anti: Trifft ein Schlüssel kein Buch, wird nichts geraten — der Lauf meldet Abbruch.
    func testUnknownKeyIsReportedAndFailsTheRun() async throws {
        let context = ModelContext(container)
        context.insert(Book(isbn: "9783958905733", title: "A", author: "B"))

        let report = try await CoverAssignment.apply(
            [.init(key: "9780000000002", imagePath: try image(3))], context: context,
            cache: CoverCache(directory: directory.appendingPathComponent("cache")))

        XCTAssertEqual(report.assigned, 0)
        XCTAssertFalse(report.isComplete)
        XCTAssertEqual(report.problems.count, 1)
    }

    /// Anti: Der Platzhalter-Wächter gilt auch hier — dasselbe Bild nicht an zwei Bücher.
    func testSameImageForTwoBooksIsRejected() async throws {
        let context = ModelContext(container)
        context.insert(Book(isbn: "9783958905733", title: "A", author: "X"))
        context.insert(Book(isbn: "9783442477760", title: "B", author: "Y"))

        let path = try image(4)
        let cache = CoverCache(directory: directory.appendingPathComponent("cache"))
        let report = try await CoverAssignment.apply(
            [.init(key: "9783958905733", imagePath: path),
             .init(key: "9783442477760", imagePath: path)], context: context, cache: cache)

        XCTAssertEqual(report.assigned, 1)
        XCTAssertEqual(report.problems.count, 1, "das zweite Buch bekommt den Platzhalter nicht")
    }

    /// Anti: Zu kleine Dateien sind kein Bild — Amazons Fehlanzeige hat 43 Byte.
    func testTinyFileIsNotAnImage() async throws {
        let context = ModelContext(container)
        context.insert(Book(isbn: "9783958905733", title: "A", author: "X"))
        let url = directory.appendingPathComponent("winzig.jpg")
        try Data(repeating: 0, count: 43).write(to: url)

        let report = try await CoverAssignment.apply(
            [.init(key: "9783958905733", imagePath: url.path)], context: context,
            cache: CoverCache(directory: directory.appendingPathComponent("cache")))

        XCTAssertEqual(report.assigned, 0)
        XCTAssertFalse(report.isComplete)
    }
}

/// Zwei Einträge desselben Buchs führen dieselbe ISBN in zwei Schreibweisen — dann trifft
/// ein Schlüssel über die ISBN beide, und keiner von beiden lässt sich korrigieren.
/// Am 2026-08-10 an „Falsche Schuld. Private London" aufgelaufen: `3442481163` und
/// `9783442481163`, und der falsche Verfasser blieb stehen.
@MainActor
final class DuplicateAddressingTests: XCTestCase {

    func testTitleHashAddressesOneEntryOfADuplicatePair() throws {
        let container = try LibraryStore.inMemoryContainer()
        let context = ModelContext(container)
        let ten = Book(isbn: "3442481163", title: "Falsche Schuld. Private London", author: "Falsch")
        let thirteen = Book(isbn: "9783442481163", title: "Private London - falsche Schuld",
                            author: "James Patterson")
        context.insert(ten)
        context.insert(thirteen)
        let books = [ten, thirteen]

        let byISBN = CoverAssignment.matches(key: "3442481163", in: books)
        XCTAssertEqual(byISBN.count, 2, "über die ISBN sind beide gemeint")

        let key = try XCTUnwrap(CoverKey.titleHash(title: ten.title, author: ten.author))
        let byHash = CoverAssignment.matches(key: key, in: books)
        XCTAssertEqual(byHash.count, 1)
        XCTAssertEqual(byHash.first?.author, "Falsch", "der Titel-Hash trifft genau einen")
    }

    /// Anti: Der Titel-Hash bleibt für Bücher ohne ISBN, was er war.
    func testTitleHashStillWorksWithoutISBN() throws {
        let container = try LibraryStore.inMemoryContainer()
        let context = ModelContext(container)
        let book = Book(isbn: "", title: "Ohne Nummer", author: "Jemand")
        context.insert(book)
        let key = try XCTUnwrap(CoverKey.stem(isbn: "", title: "Ohne Nummer", author: "Jemand"))
        XCTAssertEqual(CoverAssignment.matches(key: key, in: [book]).count, 1)
    }
}
