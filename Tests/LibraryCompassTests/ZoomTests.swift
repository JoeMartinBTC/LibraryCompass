import XCTest
@testable import LibraryCompassCore

/// Design-Abnahme §11.7: zwei schnelle Klicks auf „+" ergeben zwei Zoom-Schritte.
final class ZoomTests: XCTestCase {

    func testTwoStepsInARowAddUp() {
        var zoom = 1.0
        zoom = Zoom.stepped(zoom, by: Zoom.step)
        zoom = Zoom.stepped(zoom, by: Zoom.step)
        XCTAssertEqual(zoom, 1.20, accuracy: 0.0001)
    }

    func testStepsAreClamped() {
        XCTAssertEqual(Zoom.stepped(1.70, by: Zoom.step), 1.70)
        XCTAssertEqual(Zoom.stepped(0.70, by: -Zoom.step), 0.70)
    }

    func testTrackMapsBothWays() {
        XCTAssertEqual(Zoom.fromTrack(0), 0.70, accuracy: 0.0001)
        XCTAssertEqual(Zoom.fromTrack(1), 1.70, accuracy: 0.0001)
        XCTAssertEqual(Zoom.trackFraction(1.20), 0.5, accuracy: 0.0001)
    }
}
