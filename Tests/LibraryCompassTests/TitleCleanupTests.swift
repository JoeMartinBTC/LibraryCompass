import XCTest
@testable import LibraryCompassCore

/// Titel sollen so dastehen, wie sie auf dem Buchrücken stehen. Katalogdaten
/// schleppen Ausgabevarianten, Verfasserangaben und Gattungszusätze mit.
final class TitleCleanupTests: XCTestCase {

    // MARK: Katalog-Ballast

    /// Der Fall aus der App (2026-08-06): So kam „Upgrade" von der DNB zurück.
    func testDropsBracketedVariantAndRepeatedTitle() {
        XCTAssertEqual(TitleCleanup.clean("[Upgrade] ; Upgrade: Roman"), "Upgrade")
    }

    func testDropsStatementOfResponsibility() {
        XCTAssertEqual(TitleCleanup.clean("Toxin : Thriller / Kathrin Lange, Susanne Thiele"), "Toxin")
    }

    func testDropsLongCatalogTail() {
        let raw = "[Kill for me, kill for you] ; Kill for me: Thriller: sie tötet deinen schlimmsten Feind ..."
        XCTAssertEqual(TitleCleanup.clean(raw), "Kill for me")
    }

    // MARK: Gattungsangaben

    func testDropsGenreSubtitle() {
        XCTAssertEqual(TitleCleanup.clean("Wer Lügen sät: Thriller"), "Wer Lügen sät")
        XCTAssertEqual(TitleCleanup.clean("Die Zeppelin-Verschwörung: Historischer Krimi"), "Die Zeppelin-Verschwörung")
        XCTAssertEqual(TitleCleanup.clean("Das Bitcoin-Komplott: Roman"), "Das Bitcoin-Komplott")
        XCTAssertEqual(TitleCleanup.clean("Der Fall Collini: Kriminalroman"), "Der Fall Collini")
    }

    func testGenreDetectionIgnoresCase() {
        XCTAssertEqual(TitleCleanup.clean("Stillhalten: ROMAN"), "Stillhalten")
        XCTAssertEqual(TitleCleanup.clean("Stillhalten: roman"), "Stillhalten")
    }

    // MARK: Was bleiben muss

    /// Echte Untertitel tragen Bedeutung — die dürfen nicht verschwinden.
    func testKeepsMeaningfulSubtitle() {
        XCTAssertEqual(TitleCleanup.clean("Sapiens: Eine kurze Geschichte der Menschheit"),
                       "Sapiens: Eine kurze Geschichte der Menschheit")
        XCTAssertEqual(TitleCleanup.clean("Dirty Money: Bcci : The Inside Story of the World's Sleaziest Bank"),
                       "Dirty Money: Bcci : The Inside Story of the World's Sleaziest Bank")
    }

    /// Aus dem echten Bestand: Hier ist „Geschichten" Teil einer Aufzählung,
    /// keine Gattungsangabe — der Titel darf nicht beschnitten werden.
    func testKeepsEnumerationWithSeveralDashes() {
        XCTAssertEqual(TitleCleanup.clean("Wäller Weihnacht. Gedichte - Brauchtum - Geschichten"),
                       "Wäller Weihnacht. Gedichte - Brauchtum - Geschichten")
    }

    /// Ein einzelner Gedankenstrich am Ende trägt dagegen oft die Gattung.
    func testDropsGenreAfterSingleDash() {
        XCTAssertEqual(TitleCleanup.clean("Selfies: Der siebte Fall für Carl Mørck – Thriller"),
                       "Selfies: Der siebte Fall für Carl Mørck")
    }

    func testKeepsPlainTitle() {
        XCTAssertEqual(TitleCleanup.clean("Der Schwarm"), "Der Schwarm")
        XCTAssertEqual(TitleCleanup.clean("Broken"), "Broken")
    }

    /// Ein Doppelpunkt gehört manchmal zum Titel selbst.
    func testKeepsTitleThatIsOnlyAColonPhrase() {
        XCTAssertEqual(TitleCleanup.clean("2001: Odyssee im Weltraum"), "2001: Odyssee im Weltraum")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(TitleCleanup.clean("  Der Schwarm  "), "Der Schwarm")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(TitleCleanup.clean(""), "")
        XCTAssertEqual(TitleCleanup.clean("   "), "")
    }

    /// Bliebe nach dem Kürzen nichts übrig, ist der Rohtitel besser als gar nichts.
    func testNeverReturnsEmptyForNonEmptyInput() {
        XCTAssertEqual(TitleCleanup.clean("Roman"), "Roman")
        XCTAssertEqual(TitleCleanup.clean(": Thriller"), ": Thriller")
    }
}
