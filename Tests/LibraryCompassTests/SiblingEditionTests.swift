import XCTest
@testable import LibraryCompassCore

/// Gemeldet am 2026-08-09: „Wie man einen Drachen tötet" hatte bei Amazon sichtbar ein
/// Cover, der Nachlauf fand keines.
///
/// Im Bestand steht die **Hörbuchfassung** `9783863526191` (Hierax Medien) — dazu führt
/// Amazon kein Bild (43 Byte). Die Druckausgabe des Europa Verlags hat eine eigene ISBN
/// `3958905730`, und die liefert 22.606 Byte. Die beiden DNB-Datensätze sind untereinander
/// **nicht verknüpft**: das Feld 776 der Druckausgabe zeigt nur auf die Online-Ausgabe.
/// Wer von der gespeicherten ISBN ausgeht, erreicht die Geschwisterausgabe nie.
final class SiblingEditionTests: XCTestCase {

    /// Die echte Antwort der DNB auf `TIT=Wie man einen Drachen tötet and PER=Chodorkowski`,
    /// auf das Wesentliche gekürzt: Druckausgabe, zweite Druckausgabe, Hörbuch.
    private let drachen = """
    <?xml version="1.0" encoding="UTF-8"?>
    <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
    <records>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Wie man einen Drachen tötet : Handbuch für angehende Revolutionäre / Michail Chodorkowski</dc:title>
        <dc:creator>Chodorkovskij, Michail Borisovič [Verfasser]</dc:creator>
        <dc:creator>Kühl, Olaf [Übersetzer]</dc:creator>
        <dc:identifier>9783958905733</dc:identifier>
        <dc:format>104 Seiten</dc:format>
      </dc></recordData></record>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Wie man einen Drachen tötet : Handbuch für angehende Revolutionäre</dc:title>
        <dc:creator>Chodorkovskij, Michail Borisovič [Verfasser]</dc:creator>
        <dc:identifier>9783958905764</dc:identifier>
      </dc></recordData></record>
      <record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Wie man einen Drachen tötet : Handbuch für angehende Revolutionäre</dc:title>
        <dc:creator>Chodorkowski, Michail [Verfasser]</dc:creator>
        <dc:creator>Dupont, Oliver [Erzähler]</dc:creator>
        <dc:identifier>9783863526191</dc:identifier>
        <dc:format>1 CD, Lesung</dc:format>
      </dc></recordData></record>
    </records></searchRetrieveResponse>
    """.data(using: .utf8)!

    /// Der Fall, der den Ausbau ausgelöst hat.
    func testFindsThePrintEditionDespiteTransliteratedName() {
        let found = DNB.siblingISBNs(from: drachen,
                                     title: "Wie man einen Drachen tötet: Handbuch für angehende Revolutionäre",
                                     author: "Chodorkowski, Michail")
        XCTAssertTrue(found.contains("9783958905733"),
                      "Druckausgabe muss gefunden werden — „Chodorkovskij“ ist derselbe Verfasser")
    }

    /// Anti: Das Hörbuch bleibt draußen, sonst trägt der Roman das Cover der Lesung.
    func testAudiobookEditionIsExcluded() {
        let found = DNB.siblingISBNs(from: drachen,
                                     title: "Wie man einen Drachen tötet: Handbuch für angehende Revolutionäre",
                                     author: "Chodorkowski, Michail")
        XCTAssertFalse(found.contains("9783863526191"), "die Lesung ist keine Geschwisterausgabe des Buchs")
    }

    /// Anti: Ohne Verfasser im Bestand gibt es keine Geschwistersuche — der Anker fehlt.
    /// „Flashback" lieferte so neun verschiedene Bücher.
    func testWithoutAuthorNothingIsReturned() {
        XCTAssertTrue(DNB.siblingISBNs(from: drachen,
                                       title: "Wie man einen Drachen tötet",
                                       author: "").isEmpty)
    }

    /// Anti: Der Fehlgriff vom 2026-08-09. „Steve Jobs. Der Henry Ford der
    /// Computerindustrie" (Young, 1989) bekam das Cover von „Steve Jobs und die
    /// Erfolgsgeschichte von Apple" (Young/Simon, Fischer) — gleicher Verfasser,
    /// anderes Buch. Der vereinfachte Titel „Steve Jobs" passt auf beide.
    func testDifferentWorkBySameAuthorIsRejected() {
        let data = """
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <records><record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Steve Jobs und die Erfolgsgeschichte von Apple / Jeffrey Young, William L. Simon</dc:title>
          <dc:creator>Young, Jeffrey S. [Verfasser]</dc:creator>
          <dc:identifier>9783596185580</dc:identifier>
        </dc></recordData></record></records></searchRetrieveResponse>
        """.data(using: .utf8)!

        let found = DNB.siblingISBNs(from: data,
                                     title: "Steve Jobs. Der Henry Ford der Computerindustrie.",
                                     author: "Jeffrey S. Young")
        XCTAssertTrue(found.isEmpty, "anderer Untertitel heißt anderes Werk")
    }

    /// Der bewährte Fall bleibt: E-Book im Bestand, Druckausgabe trägt das Bild.
    func testEbookStillReachesItsPrintEdition() {
        let data = """
        <?xml version="1.0" encoding="UTF-8"?>
        <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <records><record><recordData><dc xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>In den Tod : Thriller / Sandra Grimm</dc:title>
          <dc:creator>Grimm, Sandra [Verfasser]</dc:creator>
          <dc:identifier>349206115X</dc:identifier>
        </dc></recordData></record></records></searchRetrieveResponse>
        """.data(using: .utf8)!

        XCTAssertEqual(DNB.siblingISBNs(from: data, title: "In den Tod", author: "Sandra Grimm"),
                       ["349206115X"])
    }
}

/// Der Titelvergleich für die Werkidentität — strenger als der für die Suche.
final class SameWorkTests: XCTestCase {

    func testCatalogueTitleMayCarryTheSubtitleTheEntryLacks() {
        XCTAssertTrue(TitleMatch.sameWork("Wie man einen Drachen tötet: Handbuch für angehende Revolutionäre",
                                          "Wie man einen Drachen tötet : Handbuch für angehende Revolutionäre / Michail Chodorkowski"))
    }

    /// Der Eintrag führt den Untertitel, der Katalogtitel schneidet ihn ab — trotzdem
    /// dasselbe Werk.
    func testEntryMayCarryTheSubtitleTheCatalogueLacks() {
        XCTAssertTrue(TitleMatch.sameWork("Montecrypto. Thriller", "Montecrypto / Tom Hillenbrand"))
    }

    /// Anti: gleicher Anfang, anderes Werk.
    func testDifferentContinuationIsADifferentWork() {
        XCTAssertFalse(TitleMatch.sameWork("Steve Jobs. Der Henry Ford der Computerindustrie.",
                                           "Steve Jobs und die Erfolgsgeschichte von Apple"))
        XCTAssertFalse(TitleMatch.sameWork("Depesche aus dem Jenseits", "Der Fälscher aus dem Jenseits"))
    }

    /// Anti: Leere Titel belegen nichts.
    func testEmptyTitlesNeverMatch() {
        XCTAssertFalse(TitleMatch.sameWork("", "Irgendwas"))
        XCTAssertFalse(TitleMatch.sameWork("Irgendwas", ""))
    }
}

/// Der Namensvergleich, der die Transliteration überlebt — und nicht mehr.
final class SurnameMatchTests: XCTestCase {

    func testTransliterationVariantsCount() {
        XCTAssertTrue(AuthorMatch.sameSurname("Chodorkowski", "Chodorkovskij"))
        XCTAssertTrue(AuthorMatch.sameSurname("Dostojewski", "Dostojewskij"))
    }

    func testIdenticalNamesAlwaysMatch() {
        XCTAssertTrue(AuthorMatch.sameSurname("Meyer", "Meyer"))
        XCTAssertTrue(AuthorMatch.sameSurname("Kühl", "Kuhl"), "Umlaut gefaltet")
    }

    /// Anti: Der gemeinsame Anfang allein genügt nicht — sonst wäre jeder längere Name
    /// mit gleichem Beginn derselbe Mensch.
    func testLongerNameWithSameBeginningIsRejected() {
        XCTAssertFalse(AuthorMatch.sameSurname("Meyer", "Meyerhoff"))
        XCTAssertFalse(AuthorMatch.sameSurname("Hillen", "Hillenbrand"))
    }

    /// Anti: Gleicher Anfang von wenigen Zeichen belegt nichts.
    func testDifferentPeopleStayDifferent() {
        XCTAssertFalse(AuthorMatch.sameSurname("Young", "Yourcenar"))
        XCTAssertFalse(AuthorMatch.sameSurname("Grimm", "Grisham"))
        XCTAssertFalse(AuthorMatch.sameSurname("Coben", "Cussler"))
    }

    /// Die bekannte Grenze, festgehalten statt verschwiegen: slawische Endungen für Mann
    /// und Frau bleiben ununterscheidbar. Der Titelabgleich steht daneben und trägt hier.
    func testKnownLimitIsDocumented() {
        XCTAssertTrue(AuthorMatch.sameSurname("Chodorkowski", "Chodorkowskaja"),
                      "erkannte Schwäche — siehe Kommentar an sameSurname")
    }
}
