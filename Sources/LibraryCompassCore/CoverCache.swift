import Foundation
import CryptoKit

/// Cover liegen als Dateien in Application Support; im Modell steht nur der Dateiname.
public actor CoverCache {
    public static let shared = CoverCache()

    /// Open Library liefert 1×1-Pixel statt 404 — alles unter 1,5 KB ist kein Bild.
    public static let minimumImageBytes = 1_500

    private let client: HTTPClient
    private let directoryURL: URL?

    /// Prüfsumme eines Bildes → Dateistamm, dem es gehört.
    private var knownImages: [String: String] = [:]
    private var didIndexDirectory = false

    public init(client: HTTPClient = URLSessionHTTPClient(), directory: URL? = nil) {
        self.client = client
        self.directoryURL = directory
    }

    public static func isUsableImage(_ data: Data) -> Bool {
        data.count >= minimumImageBytes
    }

    public func directory() throws -> URL {
        if let directoryURL {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        }
        let url = try LibraryStore.applicationSupportDirectory().appendingPathComponent("Covers", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Lädt ein Cover und legt es ab. Ergebnis ist der Dateiname für `Book.coverPath`.
    ///
    /// `stem` kommt aus `CoverKey.stem` und ist pro Buch eindeutig. Früher stand hier die
    /// ISBN, und der Nachlauf reichte bei ISBN-losen Büchern den Titel durch — der lief
    /// durch `ISBN.normalized` und blieb leer, worauf 50 Bücher sich die Datei `.jpg`
    /// teilten (Befund am echten Bestand 2026-08-08).
    /// - Parameter identity: Welches **Buch** gemeint ist (kanonische ISBN, sonst der
    ///   Titel-Hash). Der Dateistamm folgt der Schreibweise des Eintrags, die Identität
    ///   der Ausgabe — sonst hält der Platzhalter-Wächter zwei Erfassungen desselben
    ///   Buchs für zwei verschiedene Bücher und verweigert der zweiten ihr Cover.
    public func download(from url: URL, stem: String, identity: String? = nil) async throws -> String? {
        guard !stem.isEmpty else { return nil }
        let owner = identity ?? stem
        let (data, status) = try await client.get(url)
        guard status == 200, Self.isUsableImage(data) else { return nil }

        // Zwei verschiedene Bücher mit bitgleichem Cover sind kein Zufall, sondern ein
        // Verlagsplatzhalter. Am echten Bestand: „Leadership by the Book" und „Swoosh"
        // trugen beide das HarperCollins-Bild „COVER TO BE REVEALED" — 15.419 Byte, also
        // weit über der Mindestgröße. Ein falsches Cover wiegt schwerer als ein fehlendes.
        let digest = Self.digest(of: data)
        if let existing = try ownerOfImage(digest), existing != owner { return nil }

        let name = fileName(for: stem, url: url)
        let target = try directory().appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        knownImages[digest] = owner
        return name
    }

    /// Wem gehört dieses Bild bereits? Der Index wird beim ersten Bedarf aus dem
    /// Cache-Ordner aufgebaut, damit der Wächter auch Bilder früherer Läufe kennt.
    private func ownerOfImage(_ digest: String) throws -> String? {
        if !didIndexDirectory {
            didIndexDirectory = true
            let base = try directory()
            let files = (try? FileManager.default.contentsOfDirectory(at: base,
                                                                     includingPropertiesForKeys: nil)) ?? []
            for file in files {
                guard let data = try? Data(contentsOf: file) else { continue }
                // Dateien tragen die Schreibweise ihres Eintrags; für den Vergleich zählt
                // die kanonische Form, sonst gilt `344247776X.jpg` als anderes Buch
                // als `9783442477760.jpg`.
                let name = file.deletingPathExtension().lastPathComponent
                knownImages[Self.digest(of: data)] = name.hasPrefix("t-") ? name : ISBN.canonical(name)
            }
        }
        return knownImages[digest]
    }

    private static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func fileURL(for name: String) -> URL? {
        guard let base = try? directory() else { return nil }
        return base.appendingPathComponent(name)
    }

    private func fileName(for stem: String, url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        return "\(stem).\(ext)"
    }
}
