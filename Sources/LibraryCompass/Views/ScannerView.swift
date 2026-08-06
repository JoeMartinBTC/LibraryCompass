import AVFoundation
import SwiftUI
import LibraryCompassCore

/// Kamerabild mit Strichcode-Erkennung. Liest EAN-13 (die ISBN auf der Buchrückseite),
/// EAN-8 und QR — was kein Buch-Code ist, verwirft `ScannedCode`.
@MainActor
final class BarcodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {

    enum State: Equatable {
        case starting
        case running
        case denied
        case unavailable(String)
    }

    @Published private(set) var state: State = .starting
    /// Zuletzt erkannte ISBN — jede nur einmal je Sitzung, sonst feuert die Kamera Dauerfeuer.
    @Published private(set) var lastISBN: String?

    let session = AVCaptureSession()
    private var seen = Set<String>()
    private let queue = DispatchQueue(label: "de.storymaster.librarycompass.scanner")

    func start() async {
        guard state != .running else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        default:
            state = .denied
            return
        }

        guard let device = AVCaptureDevice.default(for: .video) else {
            state = .unavailable("Keine Kamera gefunden.")
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            state = .unavailable("Kamera lässt sich nicht öffnen.")
            return
        }

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            state = .unavailable("Strichcode-Erkennung nicht verfügbar.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Erst nach addOutput verfügbar — vorher ist die Liste leer.
        output.metadataObjectTypes = [.ean13, .ean8, .qr].filter {
            output.availableMetadataObjectTypes.contains($0)
        }
        session.commitConfiguration()

        let session = session
        queue.async { session.startRunning() }
        state = .running
    }

    func stop() {
        let session = session
        queue.async { session.stopRunning() }
        state = .starting
        seen.removeAll()
        lastISBN = nil
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput objects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        let codes = objects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        MainActor.assumeIsolated {
            for code in codes {
                guard let isbn = ScannedCode.isbn(from: code), !seen.contains(isbn) else { continue }
                seen.insert(isbn)
                lastISBN = isbn
                NSSound.beep()
                return
            }
        }
    }
}

/// Das Live-Bild der Kamera.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}
