import XCTest
@testable import LibraryCompassCore

/// Was die Kamera liefert, ist erst einmal irgendein Strichcode. Nur Buch-Codes
/// dürfen durch — sonst landet die EAN einer Müslipackung als Buch im Regal.
final class ScanTests: XCTestCase {

    // MARK: Buch-Codes

    func testAcceptsEAN13WithBooklandPrefix978() {
        XCTAssertEqual(ScannedCode.isbn(from: "9783442494033"), "9783442494033")
    }

    func testAcceptsEAN13WithBooklandPrefix979() {
        // 979er sind gültige Buch-Codes (Musikalien und neuere Titel).
        XCTAssertEqual(ScannedCode.isbn(from: "9791234567896"), "9791234567896")
    }

    func testAcceptsISBN10FromOlderBooks() {
        XCTAssertEqual(ScannedCode.isbn(from: "3442156912"), "3442156912")
    }

    func testIgnoresSeparatorsAndWhitespace() {
        XCTAssertEqual(ScannedCode.isbn(from: " 978-3-442-49403-3 "), "9783442494033")
    }

    // MARK: Alles andere

    /// Lebensmittel und Konsumgüter tragen ebenfalls EAN-13 — nur eben kein 978/979.
    func testRejectsOrdinaryProductBarcode() {
        XCTAssertNil(ScannedCode.isbn(from: "4006381333931"))
    }

    func testRejectsWrongCheckDigit() {
        XCTAssertNil(ScannedCode.isbn(from: "9783442494039"))
        XCTAssertNil(ScannedCode.isbn(from: "3442156913"))
    }

    func testRejectsNonsense() {
        XCTAssertNil(ScannedCode.isbn(from: ""))
        XCTAssertNil(ScannedCode.isbn(from: "hallo"))
        XCTAssertNil(ScannedCode.isbn(from: "12345"))
        XCTAssertNil(ScannedCode.isbn(from: "123456789012345678"))
    }

    /// Das Zusatzfeld hinter dem Strichcode (Preisangabe) darf nicht mitzählen.
    func testRejectsEAN13WithAddOn() {
        XCTAssertNil(ScannedCode.isbn(from: "978344249403300590"))
    }

    // MARK: QR-Codes

    /// Manche Verlage kleben QR-Codes mit einer Adresse aufs Buch.
    func testReadsISBNOutOfQRCodeURL() {
        XCTAssertEqual(ScannedCode.isbn(from: "https://example.org/buch/9783442494033"), "9783442494033")
        XCTAssertEqual(ScannedCode.isbn(from: "ISBN 978-3-442-49403-3"), "9783442494033")
    }

    func testIgnoresURLWithoutISBN() {
        XCTAssertNil(ScannedCode.isbn(from: "https://example.org/impressum"))
    }
}
