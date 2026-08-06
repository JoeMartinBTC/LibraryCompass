import SwiftUI
import LibraryCompassCore

/// Strichcode scannen und das Buch sofort anlegen — der Lookup läuft wie beim
/// Eintippen der ISBN. Gescannte Bücher sammeln sich in der Liste, damit man
/// einen Stapel nacheinander vor die Kamera halten kann.
struct ScanSheet: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    @StateObject private var scanner = BarcodeScanner()

    var body: some View {
        SheetContainer(width: 520, topInset: 100) {
            VStack(alignment: .leading, spacing: Space.s4) {
                header
                camera
                if !model.scannedTitles.isEmpty { results }
                footer
            }
        }
        .task { await scanner.start() }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.lastISBN) { _, isbn in
            guard let isbn else { return }
            model.addScanned(isbn: isbn)
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(lc.accentGradient)
                .frame(width: 38, height: 38)
                .overlay { LineSymbol(name: "barcode.viewfinder", size: 17, weight: .medium).foregroundStyle(.white) }
                .shadow(color: lc.accent.opacity(0.4), radius: 9, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Buch scannen")
                    .lcType(.sheetTitle)
                    .foregroundStyle(lc.text)
                Text("Strichcode auf der Rückseite vor die Kamera halten.")
                    .lcType(.caption)
                    .foregroundStyle(lc.text2)
            }
        }
    }

    @ViewBuilder
    private var camera: some View {
        ZStack {
            switch scanner.state {
            case .running:
                CameraPreview(session: scanner.session)
            case .starting:
                hint("Kamera startet …")
            case .denied:
                hint("Kein Zugriff auf die Kamera. Systemeinstellungen → Datenschutz → Kamera.")
            case .unavailable(let reason):
                hint(reason)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(lc.brd2, lineWidth: 1)
        }
    }

    private func hint(_ text: String) -> some View {
        ZStack {
            Rectangle().fill(lc.glass)
            Text(text)
                .lcType(.caption)
                .foregroundStyle(lc.text2)
                .multilineTextAlignment(.center)
                .padding(Space.s4)
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(model.scannedTitles.count) erfasst")
                .lcType(.caption)
                .foregroundStyle(lc.text2)
            ForEach(model.scannedTitles.suffix(3), id: \.self) { title in
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(lc.text)
                    .lineLimit(1)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            if model.isLookingUp {
                Text("Daten werden geholt …")
                    .lcType(.caption)
                    .foregroundStyle(lc.text2)
            }
            Spacer()
            Button("Fertig") {
                scanner.stop()
                model.finishScanning()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(lc.accentInk)
            .padding(.horizontal, 16)
            .frame(height: Metrics.controlDialog)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(lc.accentGradient))
            .accessibilityIdentifier("btn.finishScan")
        }
    }
}
