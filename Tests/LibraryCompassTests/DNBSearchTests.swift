import XCTest
@testable import LibraryCompassCore

/// ISBN nachschlagen für Bestandsbücher, die keine führen. Ohne ISBN gibt es keinen
/// Zugriff auf die einzige ausgabegenaue Coverquelle (Amazon über ISBN-10).
final class DNBSearchTests: XCTestCase {

    func testSearchURLAsksForTitleAndPerson() throws {
        let url = DNB.searchURL(title: "Der gesetzlose Richter", author: "Seeck, Max")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "query" }?.value)
        XCTAssertTrue(query.contains("TIT="), query)
        XCTAssertTrue(query.contains("PER="), query)
        XCTAssertTrue(query.contains("Der gesetzlose Richter"), query)
        XCTAssertTrue(url.absoluteString.hasPrefix("https://services.dnb.de/sru/dnb"), url.absoluteString)
    }

    /// Der Katalog nennt den Autor als „Nachname, Vorname" — gesucht wird mit dem
    /// Nachnamen, sonst verfehlt die Personensuche.
    func testSearchURLUsesSurnameForPerson() throws {
        let url = DNB.searchURL(title: "Erstschlag", author: "Brown, Dale")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "query" }?.value)
        XCTAssertTrue(query.contains("PER=Brown"), query)
    }
}

/// Eine SRU-Antwort enthält mehrere Datensätze — Ausgaben, Übersetzungen, Hörbücher.
/// Sie dürfen nicht zu einem Topf verschmolzen werden, sonst wandert die ISBN des
/// Hörbuchs an den Roman.
final class DNBRecordTests: XCTestCase {

    /// Gekürzt nach dem echten Aufbau der Antwort zu „Der Junge aus dem Wald".
    private let response = """
    <?xml version="1.0" encoding="UTF-8"?>
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
      <numberOfRecords>3</numberOfRecords>
      <records>
        <record><recordData>
          <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>[The boy from the woods] ; Der Junge aus dem Wald : Thriller</dc:title>
            <dc:creator>Coben, Harlan [Verfasser]</dc:creator>
            <dc:identifier>978-3-442-49404-0 kart. : EUR 16.00</dc:identifier>
          </dc>
        </recordData></record>
        <record><recordData>
          <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Die grosse Harlan Coben Box : Lesungen</dc:title>
            <dc:creator>Bierstedt, Detlef [Erzähler]</dc:creator>
            <dc:identifier>978-3-8371-5555-6 Hörbuch</dc:identifier>
          </dc>
        </recordData></record>
        <record><recordData>
          <dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Der Junge aus dem Wald</dc:title>
            <dc:creator>Kwisinski, Gunnar [Übersetzer]</dc:creator>
            <dc:identifier>urn:nbn:de:101:1-2022102122032</dc:identifier>
          </dc>
        </recordData></record>
      </records>
    </searchRetrieveResponse>
    """

    func testEachRecordKeepsItsOwnFields() throws {
        let records = DNB.records(Data(response.utf8))
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].isbn, "9783442494040")
        XCTAssertEqual(records[1].isbn, "9783837155556")
        XCTAssertNil(records[2].isbn, "eine URN ist keine ISBN")
        XCTAssertTrue(records[0].hasAuthor("Coben, Harlan"))
        XCTAssertFalse(records[1].hasAuthor("Coben, Harlan"), "Erzähler ist kein Verfasser")
    }

    func testPicksTheISBNOfTheMatchingAuthor() {
        XCTAssertEqual(DNB.isbn(from: Data(response.utf8), title: "Der Junge aus dem Wald", author: "Coben, Harlan"),
                       "9783442494040")
    }

    /// Anti: Der Treffer mit passendem Titel, aber fremdem Verfasser, zählt nicht.
    func testRejectsRecordsOfAnotherAuthor() {
        XCTAssertNil(DNB.isbn(from: Data(response.utf8), title: "Der Junge aus dem Wald", author: "Winslow, Don"))
    }

    /// Anti: Ohne Verfasserrolle kein Beleg — sonst erbt der Roman das Hörbuch.
    func testNarratorAloneIsNotAMatch() {
        XCTAssertNil(DNB.isbn(from: Data(response.utf8), title: "Der Junge aus dem Wald", author: "Bierstedt, Detlef"))
    }

    /// Anti: falsche Prüfziffer wird verworfen, sonst zieht Amazon irgendeine Artikelnummer.
    func testRejectsISBNWithBrokenCheckDigit() {
        let broken = response.replacingOccurrences(of: "978-3-442-49404-0", with: "978-3-442-49404-1")
        XCTAssertNil(DNB.isbn(from: Data(broken.utf8), title: "Der Junge aus dem Wald", author: "Coben, Harlan"))
    }

    /// Ohne Autor zählt der Beleg, wenn die Trefferliste eindeutig ist — hier bleibt nach
    /// Titel-, Druck- und ISBN-Prüfung genau ein Datensatz übrig (Hörbuchbox und
    /// URN-Eintrag fallen weg). Bücher ohne Autor kämen sonst nie zu einer ISBN.
    func testEmptyAuthorIsAcceptedWhenExactlyOneRecordQualifies() {
        XCTAssertEqual(DNB.isbn(from: Data(response.utf8), title: "Der Junge aus dem Wald", author: ""),
                       "9783442494040")
    }
}
