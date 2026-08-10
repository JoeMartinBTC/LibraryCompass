import AppKit
import Foundation
import SwiftData
import LibraryCompassCore

/// Schreibt den Bestand als kleine Website in einen Ordner — Katalog plus Miniaturen.
///
/// Der Anlass ist eine Frage im Buchladen: **habe ich das schon?** Dafür ist eine eigene
/// iPhone-App zu viel Apparat. Eine Seite, die der Browser zum Home-Bildschirm legt,
/// beantwortet sie genauso — und der Barcode-Scanner steckt im Browser schon drin.
///
/// Die Cover werden auf 160 Pixel Breite gerechnet: aus 63 MB werden rund 16 MB, und
/// mehr braucht niemand, um ein Buch am Umschlag wiederzuerkennen.
@MainActor
enum WebExport {

    /// Breite der Miniaturen. Auf einem Telefon mit dreifacher Auflösung ist ein Cover in
    /// der Trefferliste keine 60 Punkte breit — 160 Pixel sind also reichlich.
    static let thumbnailWidth = 160

    struct Report {
        var books = 0
        var covers = 0
        var skipped = 0
        var bytes = 0

        var summary: String {
            "Katalog=\(books) Bücher · Cover=\(covers) (\(bytes / 1024) KB)"
                + (skipped > 0 ? " · \(skipped) ohne Bilddatei" : "")
        }
    }

    static func run(into directory: String) async -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        let context = ModelContext(container)
        guard let books = try? context.fetch(FetchDescriptor<Book>()) else {
            FileHandle.standardError.write(Data("Bestand nicht lesbar\n".utf8))
            return false
        }

        let target = URL(fileURLWithPath: directory, isDirectory: true)
        let coverTarget = target.appendingPathComponent("cover", isDirectory: true)
        var report = Report(books: books.count)

        do {
            try FileManager.default.createDirectory(at: coverTarget, withIntermediateDirectories: true)

            let catalogue = LibraryWeb.catalogue(books, date: Date())
            let json = try LibraryWeb.json(catalogue)
            try json.write(to: target.appendingPathComponent("katalog.json"), options: .atomic)
            print("katalog.json: \(json.count / 1024) KB")

            for name in LibraryWeb.coverFiles(catalogue) {
                guard let source = await CoverCache.shared.fileURL(for: name),
                      let data = try? Data(contentsOf: source),
                      let image = NSImage(data: data) else {
                    report.skipped += 1
                    continue
                }
                // Schon vorhandene Miniaturen bleiben liegen: der Export läuft nach jeder
                // Erfassung erneut, und 1826 Bilder neu zu rechnen dauert unnötig lang.
                let file = coverTarget.appendingPathComponent(name)
                if let existing = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   existing > 0 {
                    report.covers += 1
                    report.bytes += existing
                    continue
                }
                guard let small = thumbnail(image) else {
                    report.skipped += 1
                    continue
                }
                try small.write(to: file, options: .atomic)
                report.covers += 1
                report.bytes += small.count
            }

            print(report.summary)
            fflush(stdout)
            return true
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — Export gescheitert: \(error)\n".utf8))
            return false
        }
    }

    /// Auf `thumbnailWidth` gerechnet, als JPEG. Hochkant bleibt hochkant — die Höhe
    /// folgt dem Seitenverhältnis, sonst werden schmale Bände gestaucht.
    private static func thumbnail(_ image: NSImage) -> Data? {
        guard let source = image.representations.first else { return nil }
        let width = CGFloat(thumbnailWidth)
        let scale = width / CGFloat(source.pixelsWide)
        let height = (CGFloat(source.pixelsHigh) * scale).rounded()

        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(width), pixelsHigh: Int(height),
                                            bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.78])
    }
}
