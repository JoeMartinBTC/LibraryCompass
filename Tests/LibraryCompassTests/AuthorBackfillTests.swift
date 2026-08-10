import XCTest
@testable import LibraryCompassCore

/// Am 2026-08-10 standen 30 der 114 coverlosen Bücher **ohne Verfasser** da. Das ist keine
/// kosmetische Lücke: ohne Verfasser darf die Titelsuche nicht laufen, weil ihr der Anker
/// fehlt — „Flashback" allein liefert neun verschiedene Bücher. Diese Bücher waren damit
/// dauerhaft von der Coverbeschaffung ausgeschlossen.
final class SoleAuthorTests: XCTestCase {

    /// Die Gesamtzahl gehört zur Antwort: die Regel verlangt die **vollständige**
    /// Trefferliste, sonst urteilt sie über einen Ausschnitt.
    private func response(_ records: String, total: Int? = nil) -> Data {
        let count = total ?? records.components(separatedBy: "<record>").count - 1
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <numberOfRecords>\(count)</numberOfRecords><records>
        \(records)
        </records></searchRetrieveResponse>
        """.data(using: .utf8)!
    }

    private func record(title: String, creators: [String]) -> String {
        let lines = creators.map { "<dc:creator>\($0)</dc:creator>" }.joined(separator: "\n")
        return """
        <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>\(title)</dc:title>
        \(lines)
        </dc></recordData></record>
        """
    }

    /// Mehrere Ausgaben desselben Werks sind mehrere Datensätze und trotzdem ein Verfasser.
    func testSeveralEditionsOfOneWorkYieldTheAuthor() {
        let data = response([
            record(title: "Montecrypto : Thriller / Tom Hillenbrand", creators: ["Hillenbrand, Tom [Verfasser]"]),
            record(title: "Montecrypto / Tom Hillenbrand", creators: ["Hillenbrand, Tom [Verfasser]"])
        ].joined(separator: "\n"))

        XCTAssertEqual(DNB.soleAuthor(from: data, title: "Montecrypto"), "Hillenbrand, Tom")
    }

    /// Schreibvarianten desselben Menschen zählen als einer.
    func testSpellingVariantsCountAsOnePerson() {
        let data = response([
            record(title: "Nur für dein Leben / Harlan Coben", creators: ["Coben, Harlan [Verfasser]"]),
            record(title: "Nur für dein Leben : Thriller", creators: ["Coben, Harlan [Verfasser]", "Steck, Johannes [Erzähler]"])
        ].joined(separator: "\n"))

        XCTAssertEqual(DNB.soleAuthor(from: data, title: "Nur für dein Leben"), "Coben, Harlan")
    }

    /// Anti: Der Kern der Sache. Nennen die Treffer zwei Menschen, bleibt das Feld leer —
    /// ein falscher Verfasser zieht anschließend ein falsches Cover nach sich.
    func testTwoDifferentAuthorsYieldNothing() {
        let data = response([
            record(title: "Feuermeer / Helga Zeiner", creators: ["Zeiner, Helga [Verfasser]"]),
            record(title: "Feuermeer / Clive Cussler", creators: ["Cussler, Clive [Verfasser]"])
        ].joined(separator: "\n"))

        XCTAssertNil(DNB.soleAuthor(from: data, title: "Feuermeer"))
    }

    /// Anti: Erzähler und Übersetzer belegen keinen Verfasser.
    func testNarratorAloneIsNotAnAuthor() {
        let data = response(record(title: "Irgendein Titel", creators: ["Dupont, Oliver [Erzähler]"]))
        XCTAssertNil(DNB.soleAuthor(from: data, title: "Irgendein Titel"))
    }

    /// Anti: Ein Datensatz zu einem anderen Titel zählt nicht mit.
    func testUnrelatedTitleIsIgnored() {
        let data = response(record(title: "Ganz was anderes / Max Muster",
                                   creators: ["Muster, Max [Verfasser]"]))
        XCTAssertNil(DNB.soleAuthor(from: data, title: "Montecrypto"))
    }

    func testEmptyResponseYieldsNothing() {
        XCTAssertNil(DNB.soleAuthor(from: response(""), title: "Montecrypto"))
    }
}

/// Welche Bücher der Nachlauf überhaupt anfasst.
@MainActor
final class AuthorBackfillSelectionTests: XCTestCase {

    /// „unknown author" kommt aus dem Delicious-Library-Import und ist so gut wie leer —
    /// nur unehrlicher, weil es ein ausgefülltes Feld vortäuscht.
    func testImportPlaceholdersCountAsMissing() {
        XCTAssertTrue(AuthorBackfill.hasNoAuthor(""))
        XCTAssertTrue(AuthorBackfill.hasNoAuthor("   "))
        XCTAssertTrue(AuthorBackfill.hasNoAuthor("unknown author"))
        XCTAssertTrue(AuthorBackfill.hasNoAuthor("Unknown Author"))
        XCTAssertTrue(AuthorBackfill.hasNoAuthor("-"))
    }

    /// Anti: Ein echter Verfasser wird nicht überschrieben.
    func testRealAuthorsAreLeftAlone() {
        XCTAssertFalse(AuthorBackfill.hasNoAuthor("Coben, Harlan"))
        XCTAssertFalse(AuthorBackfill.hasNoAuthor("Argon Verlag"),
                       "ein Verlag im Autorfeld ist falsch, aber nicht leer — das ist Joes Feld")
    }
}

/// Der Fehler vom 2026-08-10: Eindeutigkeit **innerhalb der ersten zehn Datensätze** ist
/// keine Eindeutigkeit. „Phantom" bekam so „Matsuri", während die DNB zu dem Wort 4921
/// Datensätze führt; „Falsche Schuld" bekam „Minninger" statt Patterson bei 65 Treffern.
/// Von 80 nachgetragenen Verfassern ließen sich 40 nicht belegen.
final class TruncatedResultTests: XCTestCase {

    private func response(total: Int, records: String) -> Data {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <numberOfRecords>\(total)</numberOfRecords><records>
        \(records)
        </records></searchRetrieveResponse>
        """.data(using: .utf8)!
    }

    private var oneRecord: String {
        """
        <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Phantom Tales of the Night / Matsuri</dc:title>
        <dc:creator>Matsuri [Verfasser]</dc:creator>
        </dc></recordData></record>
        """
    }

    /// Anti: Der gemeldete Fall. Ein Datensatz sichtbar, tausende vorhanden.
    func testTruncatedListNeverProvesUniqueness() {
        let data = response(total: 4921, records: oneRecord)
        XCTAssertNil(DNB.soleAuthor(from: data, title: "Phantom"),
                     "wer nur einen Ausschnitt sieht, darf über Eindeutigkeit nicht urteilen")
    }

    /// Ist die Liste vollständig, gilt das Urteil.
    func testCompleteListIsTrusted() {
        let data = response(total: 1, records: oneRecord)
        XCTAssertEqual(DNB.soleAuthor(from: data, title: "Phantom Tales of the Night"), "Matsuri")
    }

    /// Anti: Fehlt die Gesamtzahl, wird nichts angenommen.
    func testMissingTotalYieldsNothing() {
        let data = """
        <?xml version="1.0"?><searchRetrieveResponse><records>\(oneRecord)</records></searchRetrieveResponse>
        """.data(using: .utf8)!
        XCTAssertNil(DNB.soleAuthor(from: data, title: "Phantom Tales of the Night"))
    }

    func testNumberOfRecordsIsRead() {
        XCTAssertEqual(DNB.numberOfRecords(in: response(total: 65, records: "")), 65)
        XCTAssertNil(DNB.numberOfRecords(in: Data("kein XML".utf8)))
    }

    /// Co-Autoren desselben Buchs sind kein Widerspruch — „Operation Seewespe" führt
    /// Cussler und Morrison, und das ist ein Buch.
    func testCoAuthorsOfOneBookAreFine() {
        let rec = """
        <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Operation Seewespe : ein Juan-Cabrillo-Roman</dc:title>
        <dc:creator>Cussler, Clive [Verfasser]</dc:creator>
        <dc:creator>Morrison, Boyd [Verfasser]</dc:creator>
        </dc></recordData></record>
        """
        XCTAssertEqual(DNB.soleAuthor(from: response(total: 1, records: rec),
                                      title: "Operation Seewespe"), "Cussler, Clive")
    }
}
