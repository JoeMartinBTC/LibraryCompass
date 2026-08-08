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
