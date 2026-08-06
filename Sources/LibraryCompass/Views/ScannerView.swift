import AVFoundation
import SwiftUI
import LibraryCompassCore

/// Kamerabild mit Strichcode-Erkennung. Liest EAN-13 (die ISBN auf der Buchrückseite),
/// EAN-8 und QR — was kein Buch-Code ist, verwirft `ScannedCode`.
///
/// Mac-Kameras haben in aller Regel **keinen Autofokus** (live geprüft 2026-08-06:
/// alle drei Kameras dieser Maschine ohne). Nah gehalten wird der Code unscharf,
/// weiter weg zu klein. Dagegen hilft nur: höchste Auflösung fahren und das Buch
/// dort halten, wo die Kamera scharf stellt — meist 25–40 cm.
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
    @Published private(set) var cameras: [AVCaptureDevice] = []
    @Published private(set) var resolution: String = ""
    /// Gewählte Kamera; Wechsel startet die Sitzung neu.
    @Published var selectedCameraID: String = "" {
        didSet {
            guard oldValue != selectedCameraID, !oldValue.isEmpty else { return }
            Task { await restart() }
        }
    }

    let session = AVCaptureSession()
    private var seen = Set<String>()
    private let queue = DispatchQueue(label: "de.storymaster.librarycompass.scanner")

    /// Alle Kameras, die für einen Scan taugen — auch angeschlossene iPhones.
    private func availableCameras() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified).devices
    }

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

        cameras = availableCameras()
        guard !cameras.isEmpty else {
            state = .unavailable("Keine Kamera gefunden.")
            return
        }
        if selectedCameraID.isEmpty || !cameras.contains(where: { $0.uniqueID == selectedCameraID }) {
            selectedCameraID = preferredCamera(from: cameras)?.uniqueID ?? cameras[0].uniqueID
        }
        guard let device = cameras.first(where: { $0.uniqueID == selectedCameraID }) else {
            state = .unavailable("Kamera nicht mehr verfügbar.")
            return
        }
        configure(device)
    }

    /// Virtuelle Kameras (OBS und Co.) liefern kein Kamerabild — die kommen zuletzt.
    private func preferredCamera(from devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        let candidates = devices.map { device in
            CameraChoice.Candidate(name: device.localizedName,
                                   pixels: maxPixels(of: device),
                                   hasAutofocus: device.isFocusModeSupported(.continuousAutoFocus))
        }
        guard let best = CameraChoice.best(of: candidates) else { return nil }
        return devices.first { $0.localizedName == best.name }
    }

    private func maxPixels(of device: AVCaptureDevice) -> Int {
        var best = 0
        for format in device.formats {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            best = max(best, Int(size.width) * Int(size.height))
        }
        return best
    }

    private func configure(_ device: AVCaptureDevice) {
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            state = .unavailable("Kamera lässt sich nicht öffnen.")
            return
        }

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            state = .unavailable("Kamera lässt sich nicht öffnen.")
            return
        }
        session.addInput(input)

        // Mehr Pixel heißt: Der Code bleibt aus größerem Abstand lesbar — dort, wo
        // eine Kamera ohne Autofokus noch scharf zeichnet. Voreinstellung wäre oft 640×480.
        session.sessionPreset = .high
        useHighestFormat(device)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            state = .unavailable("Strichcode-Erkennung nicht verfügbar.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Erst nach addOutput gefüllt — vorher ist die Liste leer.
        output.metadataObjectTypes = [.ean13, .ean8, .qr].filter {
            output.availableMetadataObjectTypes.contains($0)
        }
        session.commitConfiguration()

        let session = session
        queue.async { session.startRunning() }
        state = .running
    }

    /// Das größte Format der Kamera fest einstellen — `sessionPreset` allein
    /// schöpft es nicht aus.
    private func useHighestFormat(_ device: AVCaptureDevice) {
        var best: AVCaptureDevice.Format?
        var bestPixels = 0
        for format in device.formats {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let pixels = Int(size.width) * Int(size.height)
            if pixels > bestPixels {
                bestPixels = pixels
                best = format
            }
        }
        guard let best, (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = best
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()

        let size = CMVideoFormatDescriptionGetDimensions(best.formatDescription)
        resolution = "\(size.width)×\(size.height)"
    }

    private func restart() async {
        stop()
        await start()
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
