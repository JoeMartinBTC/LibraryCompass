import XCTest
@testable import LibraryCompassCore

/// Mapping Delicious-Library-Eintrag → Buch (BUILD-HANDOVER §2/§3), ohne Store.
final class ImportMappingTests: XCTestCase {

    private func plist(_ entries: [[String: Any]]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
    }

    private func entry(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var dict: [String: Any] = [
            "type": "Book",
            "title": "Der Schwarm",
            "creatorsCompositeString": "Frank Schätzing",
            "isbn": "3442156912",
            "ean": "9783442156917",
            "rating": 4.0,
            "notes": "spannend",
            "pages": 995,
            "creationDate": Date(timeIntervalSince1970: 1_284_054_340)
        ]
        for (key, value) in overrides { dict[key] = value }
        return dict
    }

    func testMapsAllTenFields() throws {
        let publish = Date(timeIntervalSince1970: 1_109_804_580) // 2005
        let data = try plist([entry(["publishDate": publish])])

        let result = try DeliciousLibraryImport.parse(data: data)

        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.books.count, 1)
        let buch = try XCTUnwrap(result.books.first)
        XCTAssertEqual(buch.isbn, "3442156912")
        XCTAssertEqual(buch.title, "Der Schwarm")
        XCTAssertEqual(buch.author, "Frank Schätzing")
        XCTAssertEqual(buch.rating, 4)
        XCTAssertEqual(buch.comment, "spannend")
        XCTAssertEqual(buch.addedDate, Date(timeIntervalSince1970: 1_284_054_340))
        XCTAssertEqual(buch.year, Calendar.current.component(.year, from: publish))
        XCTAssertEqual(buch.pages, 995)
    }

    func testFallsBackToEanWhenIsbnMissing() throws {
        let data = try plist([entry(["isbn": ""])])
        let buch = try XCTUnwrap(try DeliciousLibraryImport.parse(data: data).books.first)
        XCTAssertEqual(buch.isbn, "9783442156917")
    }

    func testAcceptsBookWithoutIsbnAndWithoutTitle() throws {
        let data = try plist([entry(["isbn": "", "ean": "", "title": ""])])
        let result = try DeliciousLibraryImport.parse(data: data)
        XCTAssertEqual(result.books.count, 1, "Bücher ohne ISBN/Titel werden trotzdem übernommen")
        XCTAssertEqual(result.books.first?.isbn, "")
        XCTAssertEqual(result.books.first?.title, "")
    }

    func testSkipsNonBookEntries() throws {
        let data = try plist([entry(), entry(["type": "Gadget", "title": "Kindle"])])
        let result = try DeliciousLibraryImport.parse(data: data)
        XCTAssertEqual(result.books.count, 1)
        XCTAssertEqual(result.skippedNonBooks, 1)
        XCTAssertEqual(result.errors.count, 0)
    }

    func testRatingIsRoundedFromDoubleAndClamped() throws {
        let data = try plist([entry(["rating": 3.0]), entry(["rating": 0.0]), entry(["rating": 9.0])])
        let ratings = try DeliciousLibraryImport.parse(data: data).books.map(\.rating)
        XCTAssertEqual(ratings, [3, 0, 5])
    }

    func testPagesZeroBecomesNilAndYearMissingBecomesNil() throws {
        let data = try plist([entry(["pages": 0])])
        let buch = try XCTUnwrap(try DeliciousLibraryImport.parse(data: data).books.first)
        XCTAssertNil(buch.pages)
        XCTAssertNil(buch.year)
    }

    func testTrimsWhitespaceOfTextFields() throws {
        let data = try plist([entry(["title": "  Der Schwarm \n", "notes": "\nspannend\n",
                                     "creatorsCompositeString": " Frank Schätzing "])])
        let buch = try XCTUnwrap(try DeliciousLibraryImport.parse(data: data).books.first)
        XCTAssertEqual(buch.title, "Der Schwarm")
        XCTAssertEqual(buch.author, "Frank Schätzing")
        XCTAssertEqual(buch.comment, "spannend")
    }

    func testKeepsMultilineNotesIntact() throws {
        let data = try plist([entry(["notes": "Zeile 1\nZeile 2"])])
        XCTAssertEqual(try DeliciousLibraryImport.parse(data: data).books.first?.comment,
                       "Zeile 1\nZeile 2")
    }

    func testRejectsNonPlistData() {
        XCTAssertThrowsError(try DeliciousLibraryImport.parse(data: Data("kein plist".utf8)))
    }

    func testRejectsPlistThatIsNotAnArray() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .xml, options: 0)
        XCTAssertThrowsError(try DeliciousLibraryImport.parse(data: data))
    }

    // MARK: Duplikat-Schlüssel

    func testDuplicateKeyUsesIsbnWhenPresent() {
        let a = ImportedBook(isbn: "9783442156917", title: "Der Schwarm", author: "Schätzing")
        let b = ImportedBook(isbn: "9783442156917", title: "Anderer Titel", author: "Anderer Autor")
        XCTAssertEqual(a.duplicateKey, b.duplicateKey)
    }

    func testDuplicateKeyFallsBackToTitleAndAuthor() {
        let a = ImportedBook(isbn: "", title: "Der Schwarm", author: "Schätzing")
        let b = ImportedBook(isbn: "", title: "der schwarm", author: "schätzing")
        let c = ImportedBook(isbn: "", title: "Der Schwarm", author: "Jemand anders")
        XCTAssertEqual(a.duplicateKey, b.duplicateKey)
        XCTAssertNotEqual(a.duplicateKey, c.duplicateKey)
    }
}
