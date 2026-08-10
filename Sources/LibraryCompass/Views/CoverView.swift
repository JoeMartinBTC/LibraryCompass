import AppKit
import SwiftUI
import LibraryCompassCore

/// Die zwölf Juwelentöne für Cover-Platzhalter (TOKENS §2).
enum CoverTints {
    static let pairs: [(UInt32, UInt32)] = [
        (0x8B5CF6, 0x3B1A8E), (0xFF6B9D, 0x8E2A63), (0x3AC8E0, 0x175E8C), (0xFFB347, 0xB8531A),
        (0x56E39F, 0x177A5A), (0xC36BFF, 0x5B1E9E), (0xFF8A6B, 0xA83A5C), (0x6BA8FF, 0x243E9E),
        (0xE8C24F, 0x8A6516), (0xFF6BC1, 0x6E1E8E), (0x4FD8E8, 0x2E3FA8), (0xA0E85C, 0x3E7A18)
    ]

    /// Stabil aus dem Buch abgeleitet, damit ein Titel immer denselben Ton behält.
    static func gradient(seed: String) -> LinearGradient {
        var hash: UInt64 = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let pair = pairs[Int(hash % UInt64(pairs.count))]
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                              startPoint: UnitPoint(x: 0.10, y: 0),
                              endPoint: UnitPoint(x: 0.90, y: 1))
    }
}

/// Bilder aus dem Datei-Cache, einmal geladen und gemerkt.
@MainActor
final class CoverImages {
    static let shared = CoverImages()
    private var cache = NSCache<NSString, NSImage>()
    private var directory: URL?

    private init() {
        directory = try? LibraryStore.applicationSupportDirectory().appendingPathComponent("Covers", isDirectory: true)
    }

    func image(named name: String) -> NSImage? {
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let url = directory?.appendingPathComponent(name),
              let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

/// Cover im Verhältnis 2 : 3 — echtes Bild, sonst Verlauf mit Titel und Autor (README §5.5).
///
/// Nimmt `any BookFields` statt `Book`, damit die Lücken aus der Autorbibliografie
/// dieselbe Darstellung bekommen wie der Bestand. Gebraucht werden hier ohnehin nur
/// ISBN, Titel, Verfasser und Bildname.
struct CoverView: View {
    let book: any BookFields
    var width: CGFloat
    var radius: CGFloat = Radius.m
    var showsLabels = true
    var spineWidth: CGFloat = 6

    private var height: CGFloat { width * 1.5 }

    var body: some View {
        ZStack {
            if let name = book.coverPath, let image = CoverImages.shared.image(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                CoverTints.gradient(seed: book.isbn + book.title)
                spine
                if showsLabels { labels }
            }
            overlays
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var spine: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.30), .white.opacity(0.10)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: spineWidth)
            Spacer(minLength: 0)
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(book.title)
                .lcType(.coverTitle)
                .foregroundStyle(.white.opacity(0.97))
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .lineLimit(4)
                .padding(.leading, 7 * (width / 146))
            Spacer(minLength: 4)
            Text(book.author)
                .lcType(.coverAuthor)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(2)
                .padding(.leading, 7 * (width / 146))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13 * (width / 146))
        .padding(.vertical, 14 * (width / 146))
    }

    /// Glanz und Lesbarkeit — bleiben auch über einem echten Cover (TOKENS §2).
    private var overlays: some View {
        ZStack {
            LinearGradient(stops: [.init(color: .white.opacity(0.20), location: 0),
                                   .init(color: .clear, location: 0.40)],
                           startPoint: UnitPoint(x: 0.85, y: 0), endPoint: UnitPoint(x: 0.15, y: 1))
            LinearGradient(stops: [.init(color: .black.opacity(0.30), location: 0),
                                   .init(color: .clear, location: 0.38),
                                   .init(color: .clear, location: 0.66),
                                   .init(color: .black.opacity(0.30), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }
}
