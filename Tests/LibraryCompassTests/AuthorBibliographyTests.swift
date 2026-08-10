import XCTest
import SwiftData
@testable import LibraryCompassCore

/// Die Werkliste eines Verfassers und der Abgleich mit dem Bestand.
///
/// Alle Datensätze sind nach der echten Antwort der DNB zu `PER=Frank Schätzing`
/// gebaut (Probe vom 2026-08-10, 323 Treffer) — samt der Fälle, die dort für Ärger
/// sorgen: Vorwort statt Verfasserschaft, eine Lesung ohne jedes Wort im Titel und
/// die slowakische Übersetzung.
final class AuthorBibliographyTests: XCTestCase {

    private func records(_ body: String) -> [DNB.Record] {
        DNB.records(Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
          <numberOfRecords>9</numberOfRecords>
          <records>\(body)</records>
        </searchRetrieveResponse>
        """.utf8))
    }

    private func record(title: String, creators: [String], isbn: String?,
                        language: String = "ger", type: String? = nil,
                        date: String = "2004") -> String {
        let creatorTags = creators.map { "<dc:creator>\($0)</dc:creator>" }.joined()
        let isbnTag = isbn.map { "<dc:identifier>\($0)</dc:identifier>" } ?? ""
        let typeTag = type.map { "<dc:type>\($0)</dc:type>" } ?? ""
        return """
        <record><recordData>
          <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title>\(creatorTags)
            <dc:date>\(date)</dc:date>
            <dc:language>\(language)</dc:language>\(isbnTag)\(typeTag)
          </dc>
        </recordData></record>
        """
    }

    private var schwarm: String {
        record(title: "Der Schwarm : Roman / Frank Schätzing",
               creators: ["Schätzing, Frank [Verfasser]"],
               isbn: "978-3-462-03374-8", date: "2004")
    }

    private var limit: String {
        record(title: "Limit : Roman / Frank Schätzing",
               creators: ["Schätzing, Frank [Verfasser]"],
               isbn: "978-3-462-04131-6", date: "2009")
    }

    // MARK: Was zählt als Werk

    func testWorksKeepPrintEditionsOfTheAuthor() {
        let works = AuthorBibliography.works(in: records(schwarm + limit), author: "Frank Schätzing")
        XCTAssertEqual(works.map(\.title), ["Der Schwarm", "Limit"])
        XCTAssertEqual(works.first?.year, 2004)
        XCTAssertEqual(works.first?.isbn, "9783462033748")
    }

    /// „Die Juden von Cölln" ist von Wilhelm Jensen — Schätzing hat das Vorwort geschrieben.
    func testForewordIsNotHisWork() {
        let foreword = record(title: "Die Juden von Cölln : ein historischer Roman / Wilhelm Jensen ; mit einem Vorwort von Frank Schätzing",
                              creators: ["Jensen, Wilhelm [Verfasser]", "Schätzing, Frank [Mitwirkender]"],
                              isbn: "978-3-462-00000-9")
        let works = AuthorBibliography.works(in: records(foreword), author: "Frank Schätzing")
        XCTAssertTrue(works.isEmpty, "Vorwort zählt als eigenes Werk: \(works)")
    }

    /// Der Hörverlag führt „Tod und Teufel / Frank Schätzing" ohne ein einziges Wort,
    /// das auf eine Lesung hindeutet. Nur die Rolle des Erzählers verrät sie.
    func testNarratedEditionIsNotAGap() {
        let reading = record(title: "Tod und Teufel / Frank Schätzing",
                             creators: ["Schätzing, Frank [Verfasser]", "Kaminski, Stefan [Erzähler]"],
                             isbn: "978-3-8445-2362-1", date: "2016")
        let works = AuthorBibliography.works(in: records(reading), author: "Frank Schätzing")
        XCTAssertTrue(works.isEmpty, "Lesung im Werkverzeichnis: \(works)")
    }

    func testForeignTranslationIsSkipped() {
        let slovak = record(title: "[Breaking News] ; Bleskové správy / Frank Schätzing",
                            creators: ["Schätzing, Frank [Verfasser]"],
                            isbn: "978-80-566-1234-7", language: "slo")
        let works = AuthorBibliography.works(in: records(slovak), author: "Frank Schätzing")
        XCTAssertTrue(works.isEmpty, "Slowakische Ausgabe als Werk: \(works)")
    }

    func testRecordWithoutISBNIsSkipped() {
        let fragment = record(title: "Part two", creators: ["Schätzing, Frank [Verfasser]"], isbn: nil)
        XCTAssertTrue(AuthorBibliography.works(in: records(fragment), author: "Frank Schätzing").isEmpty)
    }

    func testOnlineOnlyEditionIsSkipped() {
        let ebook = record(title: "Limit / Frank Schätzing",
                           creators: ["Schätzing, Frank [Verfasser]"],
                           isbn: "978-3-462-30000-0", type: "Online-Ressource")
        XCTAssertTrue(AuthorBibliography.works(in: records(ebook), author: "Frank Schätzing").isEmpty)
    }

    /// Vier Ausgaben, ein Werk — und die älteste gibt Jahr und ISBN vor.
    func testEditionsOfOneWorkCollapseToTheOldest() {
        let paperback = record(title: "Der Schwarm : Roman / Frank Schätzing",
                               creators: ["Schätzing, Frank [Verfasser]"],
                               isbn: "978-3-596-51655-1", date: "2015")
        let works = AuthorBibliography.works(in: records(schwarm + paperback), author: "Frank Schätzing")
        XCTAssertEqual(works.count, 1)
        XCTAssertEqual(works.first?.year, 2004)
    }

    // MARK: Abgleich mit dem Bestand

    func testOwnedWorkIsNoGapEvenWithAnotherISBN() {
        let works = AuthorBibliography.works(in: records(schwarm + limit), author: "Frank Schätzing")
        // Im Regal steht die Taschenbuchausgabe: anderer Untertitel, andere Nummer.
        let owned = [Book(isbn: "9783596516551", title: "Der Schwarm. Roman", author: "Frank Schätzing")]
        let gaps = AuthorBibliography.gaps(works: works, owned: owned, author: "Frank Schätzing")
        XCTAssertEqual(gaps.map(\.title), ["Limit"])
    }

    /// Der Bestand führt den Titel anders — die ISBN schließt die Lücke trotzdem.
    func testOwnedWorkIsNoGapWhenTheISBNMatches() {
        let works = AuthorBibliography.works(in: records(schwarm), author: "Frank Schätzing")
        let owned = [Book(isbn: "978-3-462-03374-8", title: "Schwarm, Der", author: "Frank Schätzing")]
        XCTAssertTrue(AuthorBibliography.gaps(works: works, owned: owned, author: "Frank Schätzing").isEmpty)
    }

    /// Der Bestand schreibt den Namen, wie er beim Erfassen anfiel: „Coben  Harlan" —
    /// umgekehrte Reihenfolge, kein Komma, zwei Leerzeichen. `DNB.surname` liest daraus
    /// den Nachnamen „Harlan"; das Buch galt damit nicht als eines von Coben, und
    /// „Ich finde dich" stand als Lücke im Korb, obwohl es gelesen im Regal steht
    /// (gemeldet 2026-08-10, am echten Store belegt).
    func testOwnedBookWithInvertedNameWithoutCommaStillCounts() {
        let record = record(title: "Ich finde dich : Thriller / Harlan Coben",
                            creators: ["Coben, Harlan [Verfasser]"],
                            isbn: "978-3-442-20435-9", date: "2014")
        let works = AuthorBibliography.works(in: records(record), author: "Coben, Harlan")
        XCTAssertEqual(works.count, 1)

        let owned = [Book(isbn: "9783442497812", title: "Ich finde dich", author: "Coben  Harlan")]
        XCTAssertTrue(AuthorBibliography.gaps(works: works, owned: owned, author: "Coben, Harlan").isEmpty,
                      "Vorhandenes Buch steht als Lücke im Korb")
    }

    /// Und andersherum: der Knopf wird auf genau diesem Buch gedrückt. Dann ist die
    /// verunglückte Schreibweise die **Suchgrundlage** — auch dann muss die Werkliste stehen.
    func testWorksAreFoundWhenTheStoredNameIsMalformed() {
        let works = AuthorBibliography.works(in: records(schwarm), author: "Schätzing  Frank")
        XCTAssertEqual(works.map(\.title), ["Der Schwarm"])
    }

    /// Ein gleichnamiger Titel eines **anderen** Verfassers darf keine Lücke schließen.
    func testSameTitleByAnotherAuthorDoesNotCloseTheGap() {
        let works = AuthorBibliography.works(in: records(limit), author: "Frank Schätzing")
        let owned = [Book(isbn: "9780000000001", title: "Limit", author: "Jean Ferry")]
        XCTAssertEqual(AuthorBibliography.gaps(works: works, owned: owned, author: "Frank Schätzing").count, 1)
    }
}

/// Der Lückenkorb liegt im selben Store, ist aber kein Bestand.
final class MissingBookTests: XCTestCase {

    func testGapsAreInvisibleToTheBookFetch() throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "9783462033748", title: "Der Schwarm", author: "Frank Schätzing"))
        try context.save()
        let before = try context.fetch(FetchDescriptor<Book>()).count

        context.insert(MissingBook(isbn: "9783462041312", title: "Limit", author: "Frank Schätzing", year: 2009))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, before,
                       "Eine Lücke ist im Bestand gelandet")
        XCTAssertEqual(try context.fetch(FetchDescriptor<MissingBook>()).count, 1)
    }

    /// Die Lücke bringt keine Bewertung und kein Lesedatum mit — sie gehört einem nicht.
    func testGapHasNoOwnFields() {
        let entry = MissingBook(isbn: "9783462041312", title: "Limit", author: "Frank Schätzing")
        XCTAssertEqual(entry.rating, 0)
        XCTAssertNil(entry.readDate)
        XCTAssertTrue(entry.comment.isEmpty)
    }

    /// Der Export schreibt den Bestand — Lücken haben darin nichts verloren.
    func testExportDoesNotSeeGaps() throws {
        let context = ModelContext(try LibraryStore.inMemoryContainer())
        context.insert(Book(isbn: "9783462033748", title: "Der Schwarm", author: "Frank Schätzing"))
        context.insert(MissingBook(isbn: "9783462041312", title: "Limit", author: "Frank Schätzing"))
        try context.save()

        let csv = LibraryExport.csv(try context.fetch(FetchDescriptor<Book>()))
        XCTAssertTrue(csv.contains("Der Schwarm"))
        XCTAssertFalse(csv.contains("Limit"), "Lücke im Export")
    }
}

/// Die Trefferliste wird zu Ende gelesen — oder der Lauf weist sich als unvollständig aus.
final class BibliographyPagingTests: XCTestCase {

    func testPersonURLAsksForTheWholeName() throws {
        let url = DNB.personURL(person: "Frank Schätzing", startRecord: 101)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "query" }?.value, "PER=Frank Schätzing")
        XCTAssertEqual(items.first { $0.name == "startRecord" }?.value, "101")
        XCTAssertEqual(items.first { $0.name == "maximumRecords" }?.value, "100")
    }

    func testPagesAreAssembledUntilTheCatalogIsExhausted() async throws {
        let client = PagingClient(total: 250)
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        let result = try await lookup.bibliography(author: "Frank Schätzing")

        XCTAssertEqual(result.seen, 250)
        XCTAssertEqual(result.total, 250)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.works.count, 250, "Jeder Datensatz ist hier ein eigenes Werk")
        await XCTAssertEqualAsync(await client.pages, [1, 101, 201])
    }

    /// Stößt der Lauf an die Obergrenze, darf er die gekürzte Liste nicht als ganze ausgeben.
    func testTruncatedRunReportsItself() async throws {
        let client = PagingClient(total: 250)
        let lookup = MetadataLookup(client: client, backoff: { _ in })
        let result = try await lookup.bibliography(author: "Frank Schätzing", maximumTotal: 100)

        XCTAssertEqual(result.seen, 100)
        XCTAssertEqual(result.total, 250)
        XCTAssertFalse(result.isComplete, "Ein abgeschnittener Lauf gilt als vollständig")
    }
}

private func XCTAssertEqualAsync<T: Equatable>(_ lhs: @autoclosure () async -> T,
                                               _ rhs: T,
                                               file: StaticString = #filePath,
                                               line: UInt = #line) async {
    let value = await lhs()
    XCTAssertEqual(value, rhs, file: file, line: line)
}

/// Antwortet wie die DNB: höchstens 100 Datensätze je Seite, `startRecord` eins-basiert.
private actor PagingClient: HTTPClient {
    let total: Int
    private(set) var pages: [Int] = []

    init(total: Int) { self.total = total }

    func get(_ url: URL) async throws -> (Data, Int) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let start = Int(items.first { $0.name == "startRecord" }?.value ?? "1") ?? 1
        pages.append(start)

        let count = max(0, min(100, total - start + 1))
        let body = (0..<count).map { offset -> String in
            let number = start + offset
            return """
            <record><recordData>
              <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Werk \(number) / Frank Schätzing</dc:title>
                <dc:creator>Schätzing, Frank [Verfasser]</dc:creator>
                <dc:date>2004</dc:date>
                <dc:language>ger</dc:language>
                <dc:identifier>\(isbn(number))</dc:identifier>
              </dc>
            </recordData></record>
            """
        }.joined()

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
          <numberOfRecords>\(total)</numberOfRecords>
          <records>\(body)</records>
        </searchRetrieveResponse>
        """
        return (Data(xml.utf8), 200)
    }

    /// ISBN-13 mit gerechneter Prüfziffer — der Parser verwirft alles andere.
    private func isbn(_ number: Int) -> String {
        let body = "978" + String(format: "%09d", number)
        let digits = body.compactMap { $0.wholeNumberValue }
        let sum = digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        return body + String((10 - sum % 10) % 10)
    }
}
