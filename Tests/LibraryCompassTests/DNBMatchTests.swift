import XCTest
@testable import LibraryCompassCore

/// Am echten Bestand aufgedeckt (2026-08-08): Der Autor-Abgleich allein reicht nicht.
/// Zwei Fehlgriffe aus dem ersten Lauf über 174 Bücher sind hier als Test festgehalten.
final class DNBMatchTests: XCTestCase {

    /// 🔴 „Neid" von Arne Dahl bekam `9783869522548` — das ist die Hörbuchfassung
    /// („Neid : 8 CDs"). Hörbücher führen den Autor ebenfalls als `[Verfasser]`,
    /// der Rollenwächter greift also nicht. Ein Tonträger hat ein anderes Cover
    /// und eine andere ISBN als das Buch im Regal.
    private func audiobook(title: String, format: String = "") -> DNB.Record {
        DNB.Record(title: title,
                   creators: ["Dahl, Arne [Verfasser]"],
                   identifiers: ["978-3-86952-254-8"],
                   formats: format.isEmpty ? [] : [format])
    }

    func testRejectsAudioEditionByTitle() {
        XCTAssertFalse(audiobook(title: "Neid : 8 CDs").isPrint)
        XCTAssertFalse(audiobook(title: "Neid : Hörbuch").isPrint)
        XCTAssertFalse(audiobook(title: "Neid, 1 MP3-CD").isPrint)
        XCTAssertFalse(audiobook(title: "Neid : Lesung").isPrint)
    }

    func testRejectsAudioEditionByFormat() {
        XCTAssertFalse(audiobook(title: "Neid", format: "8 CDs (600 Min.)").isPrint)
        XCTAssertFalse(audiobook(title: "Neid", format: "1 MP3-CD").isPrint)
    }

    func testAcceptsPrintEdition() {
        XCTAssertTrue(audiobook(title: "Neid : Roman", format: "480 Seiten").isPrint)
    }

    /// 🔴 „The Fatal Conceit: The Errors of Socialism" von Hayek bekam die ISBN von
    /// „Die verhängnisvolle Anmassung" — der deutschen Ausgabe. Der Autor passte, der
    /// Titel wurde nie geprüft, und die DNB-Suche ist unscharf.
    func testRejectsRecordWhoseTitleDoesNotMatch() {
        XCTAssertFalse(TitleMatch.matches("The Fatal Conceit: The Errors of Socialism",
                                          "Die verhängnisvolle Anmassung : die Irrtümer des Sozialismus"))
    }

    /// Der Katalogtitel schleppt Originaltitel, Gattung und Verfasserangabe mit —
    /// das darf den Abgleich nicht scheitern lassen.
    func testAcceptsCatalogTitleAroundTheRealOne() {
        XCTAssertTrue(TitleMatch.matches("Exekution", "[The fix] ; Exekution : Thriller / David Baldacci"))
        XCTAssertTrue(TitleMatch.matches("Der goldene Zirkel", "[The lost order] ; Der goldene Zirkel : Thriller"))
        XCTAssertTrue(TitleMatch.matches("1918 - Aufstand für die Freiheit: Die Revolution der Besonnenen",
                                         "1918 - Aufstand für die Freiheit : die Revolution der Besonnenen"))
        XCTAssertTrue(TitleMatch.matches("Tote leben länger", "Tote leben länger : Thriller / James Douglas"))
    }

    /// Anti: Ein Teiltreffer im Wortsinn reicht nicht — sonst passt „Neid" auf
    /// „Neid und Missgunst in der Antike".
    func testShortTitleDoesNotMatchLongerUnrelatedOne() {
        XCTAssertFalse(TitleMatch.matches("Neid", "Neidhart von Reuental : eine Biographie"))
    }

    func testEmptyTitlesNeverMatch() {
        XCTAssertFalse(TitleMatch.matches("", "Irgendwas"))
        XCTAssertFalse(TitleMatch.matches("Irgendwas", ""))
    }

    /// Der gesamte Wächter zusammen: passender Verfasser, passender Titel, Druckausgabe.
    func testISBNSelectionRequiresAllThreeGuards() {
        let xml = """
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
          <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Neid : 8 CDs</dc:title>
            <dc:creator>Dahl, Arne [Verfasser]</dc:creator>
            <dc:identifier>978-3-86952-254-8</dc:identifier>
          </dc></recordData></record>
          <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Neid : Roman</dc:title>
            <dc:creator>Dahl, Arne [Verfasser]</dc:creator>
            <dc:identifier>978-3-492-30427-6</dc:identifier>
            <dc:format>480 Seiten</dc:format>
          </dc></recordData></record>
        </records></searchRetrieveResponse>
        """
        // Die Hörbuchfassung steht zuerst und muss übersprungen werden.
        XCTAssertEqual(DNB.isbn(from: Data(xml.utf8), title: "Neid", author: "Dahl, Arne"),
                       "9783492304276")
    }

    /// 🔴 Dritter Fehlgriff aus dem echten Lauf: `<dc:identifier>http://d-nb.info/1264340478/34`
    /// wurde als ISBN-10 übernommen. **DNB-Katalognummern sind zehnstellig und
    /// mod-11-geprüft — sie bestehen die ISBN-10-Prüfziffernrechnung zwangsläufig.**
    /// Eine Prüfziffer belegt also nicht, dass die Nummer eine ISBN ist.
    func testCatalogueNumberInAURLIsNotAnISBN() {
        for raw in ["http://d-nb.info/1264340478/34",
                    "https://d-nb.info/1369593880",
                    "urn:nbn:de:101:1-2022102122032"] {
            XCTAssertNil(DNB.Record.firstISBN(in: raw), raw)
        }
    }

    /// Zur Sicherheit die Gegenprobe: die Katalognummern rechnen sich als ISBN-10 auf.
    func testThoseCatalogueNumbersWouldPassTheCheckDigit() {
        XCTAssertTrue(AmazonCover.isValidISBN10("1264340478"))
        XCTAssertTrue(AmazonCover.isValidISBN10("136958542X"))
    }

    func testPlainISBNInIdentifierStillWorks() {
        XCTAssertEqual(DNB.Record.firstISBN(in: "978-3-442-49404-0 kart. : EUR 16.00"), "9783442494040")
        XCTAssertEqual(DNB.Record.firstISBN(in: "0-415-00820-4"), "0415008204")
    }

    /// 🔴 Der eigentliche Grund für die Katalognummern: die DNB **kennzeichnet** jeden
    /// Bezeichner per Attribut — `xsi:type="tel:ISBN"` gegen `xsi:type="dnb:IDN"`.
    /// Der Parser warf die Attribute weg, und danach war eine nackte Katalognummer von
    /// einer nackten ISBN nicht mehr zu unterscheiden. Es gab nie Anlass zu raten.
    private let typedResponse = """
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Vergeltung : Roman</dc:title>
        <dc:creator>Brown, Dale [Verfasser]</dc:creator>
        <dc:identifier xsi:type="dnb:IDN">1264346158</dc:identifier>
        <dc:format>512 Seiten</dc:format>
      </dc></recordData></record>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Vergeltung : Roman</dc:title>
        <dc:creator>Brown, Dale [Verfasser]</dc:creator>
        <dc:identifier xsi:type="tel:ISBN">978-3-442-49404-0 Broschur : EUR 12.00</dc:identifier>
        <dc:identifier xsi:type="dnb:IDN">125759740X</dc:identifier>
        <dc:format>512 Seiten</dc:format>
      </dc></recordData></record>
    </records></searchRetrieveResponse>
    """

    func testOnlyIdentifiersTypedAsISBNCount() {
        let records = DNB.records(Data(typedResponse.utf8))
        XCTAssertEqual(records.count, 2)
        XCTAssertNil(records[0].isbn, "dnb:IDN ist eine Katalognummer, keine ISBN")
        XCTAssertEqual(records[1].isbn, "9783442494040")
    }

    /// Der Datensatz ohne ISBN darf nicht ersatzweise seine Katalognummer hergeben —
    /// genau so kamen 18 falsche Nummern in den Bestand.
    func testRecordWithoutISBNYieldsNothingRatherThanItsIDN() {
        XCTAssertEqual(DNB.isbn(from: Data(typedResponse.utf8), title: "Vergeltung", author: "Brown, Dale"),
                       "9783442494040")
    }

    /// 🔴 Vierter Fehlgriff, am echten Bestand gefunden: „Fifty-Fifty" von Cavanagh bekam
    /// die ISBN der **Komplizin**. Deren Katalogtitel trägt eine Werbezeile mit —
    /// „vom Autor der SPIEGEL-Bestseller THIRTEEN und FIFTY FIFTY" —, und die Suche nach
    /// der Wortfolge *irgendwo* im Titel fand sie dort. Der Titel muss **vorn** stehen.
    func testBlurbInsideACatalogTitleIsNotAMatch() {
        let blurb = "[The accomplice] ; Die Komplizin – Ihr Mann ist ein Serienkiller : "
            + "Thriller. - Der neue Thriller vom Autor der SPIEGEL-Bestseller THIRTEEN und "
            + "FIFTY FIFTY / Steve Cavanagh"
        XCTAssertFalse(TitleMatch.matches("Fifty-Fifty", blurb))
    }

    func testRealTitleAtTheFrontStillMatches() {
        XCTAssertTrue(TitleMatch.matches("Fifty-Fifty",
            "Fifty-Fifty : der fünfte Fall für Eddie Flynn : Thriller / Steve Cavanagh"))
    }

    /// Der Originaltitel in eckigen Klammern zählt ebenfalls — unter ihm laufen
    /// umbenannte Neuauflagen desselben Werks.
    func testBracketedOriginalTitleCounts() {
        XCTAssertTrue(TitleMatch.matches("Nie wieder keine Ahnung: Politik, Wirtschaft und Weltgeschehen",
            "[Nie wieder keine Ahnung] ; Das Buch, das (fast) alles erklärt : Sachbuch"))
    }

    func testNoPrintEditionMeansNoISBN() {
        let xml = """
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><records>
          <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Neid : 8 CDs</dc:title>
            <dc:creator>Dahl, Arne [Verfasser]</dc:creator>
            <dc:identifier>978-3-86952-254-8</dc:identifier>
          </dc></recordData></record>
        </records></searchRetrieveResponse>
        """
        XCTAssertNil(DNB.isbn(from: Data(xml.utf8), title: "Neid", author: "Dahl, Arne"))
    }
}
