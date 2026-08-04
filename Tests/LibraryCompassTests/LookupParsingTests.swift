import XCTest
@testable import LibraryCompassCore

/// Parsen der freien Metadatenquellen — ohne Netz.
final class LookupParsingTests: XCTestCase {

    func testOpenLibraryResponseYieldsTitleAuthorYearPagesCover() throws {
        let json = """
        {"ISBN:9783442156917": {
            "title": "Der Schwarm",
            "authors": [{"name": "Frank Schätzing"}],
            "number_of_pages": 987,
            "publish_date": "March 2005",
            "cover": {"large": "https://covers.openlibrary.org/b/id/123-L.jpg"}
        }}
        """
        let metadata = try XCTUnwrap(OpenLibrary.parse(Data(json.utf8), isbn: "9783442156917"))
        XCTAssertEqual(metadata.title, "Der Schwarm")
        XCTAssertEqual(metadata.author, "Frank Schätzing")
        XCTAssertEqual(metadata.pages, 987)
        XCTAssertEqual(metadata.year, 2005)
        XCTAssertEqual(metadata.coverURL?.absoluteString, "https://covers.openlibrary.org/b/id/123-L.jpg")
    }

    func testOpenLibraryJoinsMultipleAuthors() throws {
        let json = """
        {"ISBN:1": {"title": "T", "authors": [{"name": "A. Autor"}, {"name": "B. Beispiel"}]}}
        """
        XCTAssertEqual(try XCTUnwrap(OpenLibrary.parse(Data(json.utf8), isbn: "1")).author,
                       "A. Autor, B. Beispiel")
    }

    func testOpenLibraryEmptyResponseIsMiss() throws {
        XCTAssertNil(OpenLibrary.parse(Data("{}".utf8), isbn: "9783442156917"))
    }

    func testGoogleBooksResponseYieldsMetadata() throws {
        let json = """
        {"totalItems": 1, "items": [{"volumeInfo": {
            "title": "Der Schwarm",
            "subtitle": "Roman",
            "authors": ["Frank Schätzing"],
            "publishedDate": "2004-03-01",
            "pageCount": 995,
            "imageLinks": {"thumbnail": "http://books.google.com/books?id=1&img=1"}
        }}]}
        """
        let metadata = try XCTUnwrap(GoogleBooks.parse(Data(json.utf8)))
        XCTAssertEqual(metadata.title, "Der Schwarm")
        XCTAssertEqual(metadata.author, "Frank Schätzing")
        XCTAssertEqual(metadata.year, 2004)
        XCTAssertEqual(metadata.pages, 995)
        XCTAssertEqual(metadata.coverURL?.scheme, "https", "Google liefert http — auf https heben")
    }

    func testGoogleBooksEmptyResponseIsMiss() {
        XCTAssertNil(GoogleBooks.parse(Data(#"{"totalItems": 0}"#.utf8)))
    }

    // MARK: Fallstricke aus BUILD-HANDOVER §9

    func testTinyImageDataCountsAsMiss() {
        // Open Library liefert 1×1-Pixel statt 404 — alles unter 1,5 KB ist kein Cover.
        XCTAssertFalse(CoverCache.isUsableImage(Data(repeating: 0, count: 1_400)))
        XCTAssertTrue(CoverCache.isUsableImage(Data(repeating: 0, count: 20_000)))
    }

    func testAuthorMatchAcceptsSameNameInAnyOrderAndCase() {
        XCTAssertTrue(AuthorMatch.matches("Frank Schätzing", "schätzing, frank"))
        XCTAssertTrue(AuthorMatch.matches("Don Winslow", "Winslow, Don"))
    }

    func testAuthorMatchRejectsDifferentAuthor() {
        // Live erlebt: Titelsuche „Broken" lieferte „Once Upon a Broken Heart".
        XCTAssertFalse(AuthorMatch.matches("Don Winslow", "Stephanie Garber"))
        XCTAssertFalse(AuthorMatch.matches("Don Winslow", ""))
    }

    func testISBNNormalisationStripsSeparators() {
        XCTAssertEqual(ISBN.normalized("978-3-442-15691-7"), "9783442156917")
        XCTAssertEqual(ISBN.normalized(" 3442156912 "), "3442156912")
        XCTAssertEqual(ISBN.normalized("3-442-15691-X"), "344215691X")
    }
}
