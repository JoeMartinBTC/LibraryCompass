import XCTest

/// Startet LibraryCompass wirklich und prüft sichtbare Elemente.
/// `--uitest` nutzt einen leeren Store mit Demo-Büchern — die echte Bibliothek bleibt unberührt.
final class LibraryCompassUITests: XCTestCase {

    private func launchedApp(state: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"] + (state.map { ["--state", $0] } ?? [])
        app.launch()
        return app
    }

    /// ISC-8: installiertes Bundle startet und zeigt die Bibliothek.
    func testLaunchShowsWindowAndLibrary() {
        let app = launchedApp()
        XCTAssertTrue(app.buttons["btn.addBook"].waitForExistence(timeout: 30), "Fenster/Hauptaktion nach Start nicht da")
        XCTAssertTrue(app.buttons["filter.alle"].waitForExistence(timeout: 15), "Filterzeile „Alle Bücher“ fehlt")
        XCTAssertTrue(app.buttons["filter.gelesen"].exists)
        XCTAssertTrue(app.buttons["filter.ungelesen"].exists)
        XCTAssertTrue(app.buttons["filter.bewertet"].exists)
        XCTAssertTrue(app.buttons["btn.import"].exists, "Import-Zeile fehlt")
        XCTAssertEqual(app.staticTexts["lbl.screenTitle"].value as? String, "Alle Bücher")
        XCTAssertGreaterThan(app.buttons.matching(identifier: "card.book").count, 0, "Keine Bücher im Grid")
    }

    /// ISC-12: jede Listenzeile zeigt ein Cover-Thumbnail.
    func testListRowsShowCoverThumbnails() {
        let app = launchedApp(state: "list")
        let rows = app.groups.matching(identifier: "row.book")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 30), "Keine Listenzeilen")

        let thumbs = app.images.matching(identifier: "thumb.cover")
        XCTAssertGreaterThan(thumbs.count, 0, "Kein Cover-Thumbnail in der Liste")
        XCTAssertEqual(thumbs.count, rows.count, "Jede Zeile braucht ein Cover-Thumbnail")
    }

    /// Detail-Panel und Leerzustand im echten Fenster.
    /// Die Zustände kommen per Startargument: In dieser Umgebung meldet die
    /// Fenster-Accessibility „Disabled“, echte Klicks werden dann nicht zugestellt.
    func testDetailPanelAndEmptyState() {
        let detail = launchedApp(state: "detail")
        XCTAssertTrue(detail.buttons["btn.star4"].waitForExistence(timeout: 30), "Detail-Panel fehlt")
        XCTAssertTrue(detail.buttons["btn.today"].exists, "Taste „Heute“ fehlt")
        XCTAssertTrue(detail.buttons["btn.closeDetail"].exists, "Schließen-Knopf fehlt")
        detail.terminate()

        let empty = launchedApp(state: "empty")
        XCTAssertTrue(empty.otherElements["state.empty"].waitForExistence(timeout: 30)
                      || empty.staticTexts["Keine Treffer"].waitForExistence(timeout: 5),
                      "Leerzustand fehlt")
        XCTAssertEqual(empty.staticTexts["lbl.count"].value as? String, "0 von 8 Titeln · Titel A–Z")
    }
}
