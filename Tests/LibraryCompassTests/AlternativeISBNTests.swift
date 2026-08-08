import XCTest
@testable import LibraryCompassCore

/// Zwei Lücken, am echten Bestand belegt (2026-08-08):
///
/// 1. **Die gespeicherte ISBN ist die des E-Books.** „In den Tod" von Lucas Grimm steht mit
///    `9783492990172` im Bestand — Amazon führt dazu kein Bild (43 Byte). Die DNB kennt
///    dieselbe Ausgabe zusätzlich als Druck (`3-492-06115-X`, 319 Seiten), und dafür
///    liefert Amazon 43.707 Byte.
/// 2. **Bücher ohne Autor wurden nie gefragt.** „Das Poseidon-Komplott" führt im Bestand
///    keinen Autor; die DNB findet es über den Titel allein, eindeutig, mit
///    `978-3-442-37091-7` — genau der Ausgabe, die der Nutzer im Regal hat.
final class AlternativeISBNTests: XCTestCase {

    /// Ein Datensatz kann mehrere ISBNs führen (Druck und E-Book, kartoniert und gebunden).
    private let record = """
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>In den Tod : Thriller / Lucas Grimm</dc:title>
        <dc:creator>Grimm, Lucas [Verfasser]</dc:creator>
        <dc:identifier xsi:type="tel:ISBN">978-3-492-06115-5</dc:identifier>
        <dc:identifier xsi:type="tel:ISBN">3-492-06115-X</dc:identifier>
        <dc:identifier xsi:type="dnb:IDN">1264346158</dc:identifier>
        <dc:format>319 Seiten</dc:format>
      </dc></recordData></record>
    </records></searchRetrieveResponse>
    """

    func testRecordReportsAllOfItsISBNs() {
        let records = DNB.records(Data(record.utf8))
        XCTAssertEqual(records.first?.isbns, ["9783492061155", "349206115X"])
    }

    func testAlternativesAreCollectedForAMatchingRecord() {
        let found = DNB.isbns(from: Data(record.utf8), title: "In den Tod", author: "Grimm, Lucas")
        XCTAssertEqual(found, ["9783492061155", "349206115X"])
    }

    /// Anti: Fremder Verfasser liefert nichts — sonst wandert eine fremde ISBN ins Buch.
    func testAlternativesRejectAnotherAuthor() {
        XCTAssertTrue(DNB.isbns(from: Data(record.utf8), title: "In den Tod", author: "Winslow, Don").isEmpty)
    }

    // MARK: - Bücher ohne Autor

    private let single = """
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Das Poseidon-Komplott : Roman ; [Thriller] / Mike Lawson</dc:title>
        <dc:creator>Lawson, Mike [Verfasser]</dc:creator>
        <dc:identifier xsi:type="tel:ISBN">978-3-442-37091-7 kart. : EUR 8.95</dc:identifier>
        <dc:format>413 Seiten</dc:format>
      </dc></recordData></record>
    </records></searchRetrieveResponse>
    """

    /// Ohne Autor zählt der Beleg nur, wenn die Trefferliste **eindeutig** ist.
    func testTitleOnlyLookupAcceptsASingleMatch() {
        XCTAssertEqual(DNB.isbn(from: Data(single.utf8), title: "Das Poseidon-Komplott", author: ""),
                       "9783442370917")
    }

    /// Anti: Mehrere Treffer ohne Autor sind kein Beleg — dann bleibt das Buch ohne ISBN.
    func testTitleOnlyLookupRefusesWhenSeveralRecordsMatch() {
        let two = single.replacingOccurrences(
            of: "</records>",
            with: """
              <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Das Poseidon-Komplott : Hörspiel</dc:title>
                <dc:creator>Lawson, Mike [Verfasser]</dc:creator>
                <dc:identifier xsi:type="tel:ISBN">978-3-442-99999-6</dc:identifier>
                <dc:format>280 Seiten</dc:format>
              </dc></recordData></record>
            </records>
            """)
        XCTAssertNil(DNB.isbn(from: Data(two.utf8), title: "Das Poseidon-Komplott", author: ""))
    }

    /// Der Verfasser des belegten Datensatzes lässt sich mitnehmen — das Buch hat keinen.
    func testAuthorCanBeReadFromTheMatchedRecord() {
        XCTAssertEqual(DNB.author(from: Data(single.utf8), title: "Das Poseidon-Komplott", author: ""),
                       "Lawson, Mike")
    }
}
