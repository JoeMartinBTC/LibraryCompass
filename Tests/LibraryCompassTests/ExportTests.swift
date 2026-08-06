import XCTest
@testable import LibraryCompassCore

/// CSV-Export der Bibliothek — soll sich in Numbers und Excel ohne Nacharbeit öffnen.
final class ExportTests: XCTestCase {

    private struct Row: BookFields {
        var isbn = ""
        var title = ""
        var author = ""
        var coverPath: String?
        var rating = 0
        var comment = ""
        var readDate: Date?
        var addedDate = Date(timeIntervalSince1970: 1_700_000_000)
        var year: Int?
        var pages: Int?
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        return formatter.date(from: text)!
    }

    func testHeaderNamesEveryField() {
        let csv = LibraryExport.csv([Row]())
        let header = csv.split(separator: "\n").first.map(String.init) ?? ""
        XCTAssertEqual(header.replacingOccurrences(of: "\u{FEFF}", with: ""),
                       "ISBN,Titel,Autor,Jahr,Seiten,Bewertung,Kommentar,Gelesen am,Erfasst am,Cover")
    }

    func testStartsWithByteOrderMarkSoExcelShowsUmlauts() {
        XCTAssertTrue(LibraryExport.csv([Row]()).hasPrefix("\u{FEFF}"))
    }

    func testWritesOneLinePerBook() {
        let books = [Row(isbn: "9783442494033", title: "Kill for me", author: "Cavanagh, Steve"),
                     Row(isbn: "9783785728390", title: "Toxin", author: "Lange, Kathrin")]
        let lines = LibraryExport.csv(books).split(separator: "\n")
        XCTAssertEqual(lines.count, 3, "Kopfzeile plus zwei Bücher")
    }

    func testFieldsAppearInOrder() {
        let book = Row(isbn: "9783442494033", title: "Kill for me", author: "Cavanagh, Steve",
                       coverPath: "9783442494033.jpg", rating: 4, comment: "spannend",
                       readDate: date("2026-03-01"), addedDate: date("2024-11-14"),
                       year: 2026, pages: 508)
        let line = LibraryExport.csv([book]).split(separator: "\n")[1]
        XCTAssertEqual(String(line),
                       "9783442494033,Kill for me,\"Cavanagh, Steve\",2026,508,4,spannend,2026-03-01,2024-11-14,9783442494033.jpg")
    }

    func testEmptyValuesStayEmpty() {
        let line = LibraryExport.csv([Row(title: "Ohne alles")]).split(separator: "\n")[1]
        XCTAssertEqual(String(line), ",Ohne alles,,,,0,,,2023-11-14,")
    }

    // MARK: Maskierung

    func testQuotesFieldsWithComma() {
        let line = LibraryExport.csv([Row(title: "Eins, zwei, drei")]).split(separator: "\n")[1]
        XCTAssertTrue(line.contains("\"Eins, zwei, drei\""), String(line))
    }

    func testDoublesQuotesInsideFields() {
        let line = LibraryExport.csv([Row(title: "Der \"Fall\"")]).split(separator: "\n")[1]
        XCTAssertTrue(line.contains("\"Der \"\"Fall\"\"\""), String(line))
    }

    func testKeepsLineBreaksInsideQuotedField() {
        let csv = LibraryExport.csv([Row(title: "Titel", comment: "Zeile 1\nZeile 2")])
        XCTAssertTrue(csv.contains("\"Zeile 1\nZeile 2\""), csv)
    }

    func testSemicolonNeedsNoQuotes() {
        let line = LibraryExport.csv([Row(title: "A; B")]).split(separator: "\n")[1]
        XCTAssertTrue(line.contains("A; B"), String(line))
        XCTAssertFalse(line.contains("\"A; B\""), String(line))
    }
}
