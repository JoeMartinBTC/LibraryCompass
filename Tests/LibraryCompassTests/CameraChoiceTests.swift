import XCTest
@testable import LibraryCompassCore

/// Auf diesem Mac melden sich drei Kameras (live 2026-08-06): eine echte USB-Webcam
/// und zwei virtuelle (OBS, Pickle). `AVCaptureDevice.default` kann die virtuelle
/// erwischen — dann zeigt der Scanner ein Standbild statt des Buchs.
final class CameraChoiceTests: XCTestCase {

    private func camera(_ name: String, resolution: Int = 1_000_000, autofocus: Bool = false) -> CameraChoice.Candidate {
        CameraChoice.Candidate(name: name, pixels: resolution, hasAutofocus: autofocus)
    }

    func testPrefersRealCameraOverVirtualOne() {
        let best = CameraChoice.best(of: [camera("OBS Virtual Camera", resolution: 1920 * 1080),
                                          camera("USB Camera VID:1133 PID:2085", resolution: 1280 * 960)])
        XCTAssertEqual(best?.name, "USB Camera VID:1133 PID:2085")
    }

    func testKnowsTheCommonVirtualCameras() {
        for name in ["OBS Virtual Camera", "Pickle Camera", "Snap Camera", "mmhmm Camera"] {
            XCTAssertTrue(CameraChoice.isVirtual(name), name)
        }
        XCTAssertFalse(CameraChoice.isVirtual("USB Camera VID:1133 PID:2085"))
        XCTAssertFalse(CameraChoice.isVirtual("Studio Display Camera"))
    }

    /// Autofokus schlägt alles: nur damit wird ein Strichcode aus der Nähe scharf.
    func testPrefersAutofocusOverResolution() {
        let best = CameraChoice.best(of: [camera("USB Camera", resolution: 3840 * 2160),
                                          camera("iPhone von Joe", resolution: 1280 * 720, autofocus: true)])
        XCTAssertEqual(best?.name, "iPhone von Joe")
    }

    func testFallsBackToResolutionWhenNothingHasAutofocus() {
        let best = CameraChoice.best(of: [camera("Webcam A", resolution: 640 * 480),
                                          camera("Webcam B", resolution: 1280 * 960)])
        XCTAssertEqual(best?.name, "Webcam B")
    }

    func testUsesVirtualCameraOnlyWhenNothingElseIsThere() {
        let best = CameraChoice.best(of: [camera("OBS Virtual Camera")])
        XCTAssertEqual(best?.name, "OBS Virtual Camera")
    }

    func testEmptyListYieldsNothing() {
        XCTAssertNil(CameraChoice.best(of: []))
    }
}
