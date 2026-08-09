import XCTest
@testable import LibraryCompassCore

/// Gemeldet am 2026-08-09: „Die Killerin — Isabella Rose" ließ sich nicht erfassen.
/// Grund: Amazon führt den Titel unter `B0BHG35KD6`, einer ASIN. `ISBN.normalized`
/// behält nur Ziffern und „X" — übrig blieb `0356`, und der Eintrag bekam eine ISBN,
/// die es nicht gibt.
final class AmazonReferenceTests: XCTestCase {

    func testASINIsRecognized() {
        XCTAssertTrue(AmazonReference.isASIN("B0BHG35KD6"))
        XCTAssertTrue(AmazonReference.isASIN("b0gns692yt"), "Kleinschreibung zählt auch")
    }

    /// Anti: Eine ISBN-10 ist keine ASIN, auch wenn sie zehn Zeichen hat.
    func testISBN10IsNotAnASIN() {
        XCTAssertFalse(AmazonReference.isASIN("3958905730"))
        XCTAssertFalse(AmazonReference.isASIN("344247776X"))
    }

    func testIdentifierIsPulledFromAProductURL() {
        let url = "https://www.amazon.de/Die-Killerin-Isabella-Rose-Band/dp/B0BHG35KD6/ref=sr_1_1"
        XCTAssertEqual(AmazonReference.identifier(inURL: url), "B0BHG35KD6")
    }

    func testIdentifierAlsoWorksForISBNProductPages() {
        let url = "https://www.amazon.de/Wie-einen-Drachen-t%C3%B6tet/dp/3958905730/ref=sr_1_1"
        XCTAssertEqual(AmazonReference.identifier(inURL: url), "3958905730")
    }

    /// Anti: Fremde Adressen werden nicht angefasst.
    func testNonAmazonURLYieldsNothing() {
        XCTAssertNil(AmazonReference.identifier(inURL: "https://example.com/dp/B0BHG35KD6"))
    }
}

/// Eine Eingabe, die keine ISBN ist, muss als solche erkannt werden — statt still zu
/// Bruchstücken zu zerfallen.
final class ISBNPlausibilityTests: XCTestCase {

    func testRealISBNsPass() {
        XCTAssertTrue(ISBN.isPlausible("9783958905733"))
        XCTAssertTrue(ISBN.isPlausible("3958905730"))
        XCTAssertTrue(ISBN.isPlausible("978-3-95890-573-3"), "Trennstriche stören nicht")
        XCTAssertTrue(ISBN.isPlausible("344247776X"), "Prüfziffer X zählt")
    }

    func testASINIsRejected() {
        XCTAssertFalse(ISBN.isPlausible("B0BHG35KD6"),
                       "sonst entsteht daraus die Phantom-ISBN 0356")
    }

    /// Anti: Was früher stillschweigend durchging, muss jetzt scheitern.
    func testGarbageIsRejected() {
        XCTAssertFalse(ISBN.isPlausible(""))
        XCTAssertFalse(ISBN.isPlausible("0356"))
        XCTAssertFalse(ISBN.isPlausible("9783958905730"), "falsche Prüfziffer")
        XCTAssertFalse(ISBN.isPlausible("Die Killerin"))
    }
}
