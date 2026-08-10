import XCTest
@testable import LibraryCompassCore

/// Echte Abfrage gegen die DNB — die Probe an lebenden Daten, die der Cover-Nachlauf
/// teuer gelehrt hat: Zählerstände belegen nichts, angesehen werden muss die Liste.
final class AuthorBibliographyLiveTests: XCTestCase {

    private func dnbReachable() async -> Bool {
        let client = URLSessionHTTPClient()
        guard let (_, status) = try? await client.get(DNB.personURL(person: "Frank Schätzing",
                                                                    maximumRecords: 1)) else { return false }
        return status == 200
    }

    func testBibliographyOfAKnownAuthor() async throws {
        guard await dnbReachable() else {
            throw XCTSkip("DNB-SRU nicht erreichbar — Quelle ausgefallen, nicht der Code.")
        }
        let result = try await MetadataLookup().bibliography(author: "Frank Schätzing")

        XCTAssertTrue(result.isComplete, "Trefferliste abgeschnitten: \(result.seen)/\(result.total)")
        XCTAssertGreaterThan(result.works.count, 5, "Zu wenige Werke: \(result.works.map(\.title))")

        // Eine Werkliste ist kürzer als die Trefferliste — sonst sind Ausgaben nicht
        // zusammengefallen und der Korb füllt sich mit demselben Buch in vier Fassungen.
        XCTAssertLessThan(result.works.count, result.total / 2,
                          "Ausgaben wurden nicht zu Werken zusammengefasst")

        let titles = result.works.map(\.title)
        XCTAssertTrue(titles.contains { $0.localizedCaseInsensitiveContains("Schwarm") },
                      "Der Schwarm fehlt: \(titles)")
        // Keine Lesung, keine Übersetzung, kein Teilband im Werkverzeichnis.
        for title in titles {
            XCTAssertFalse(title.localizedCaseInsensitiveContains("Hörbuch"), title)
            XCTAssertFalse(title.localizedCaseInsensitiveContains("Lesung"), title)
        }
        print("Werkliste (\(result.works.count) von \(result.total) Datensätzen):")
        for work in result.works { print("  \(work.year.map(String.init) ?? "----")  \(work.title)  \(work.isbn)") }
    }
}
