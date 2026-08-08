import Foundation

/// Cover liegen als Dateien in Application Support; im Modell steht nur der Dateiname.
public actor CoverCache {
    public static let shared = CoverCache()

    /// Open Library liefert 1×1-Pixel statt 404 — alles unter 1,5 KB ist kein Bild.
    public static let minimumImageBytes = 1_500

    private let client: HTTPClient
    private let directoryURL: URL?

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
    public func download(from url: URL, stem: String) async throws -> String? {
        guard !stem.isEmpty else { return nil }
        let (data, status) = try await client.get(url)
        guard status == 200, Self.isUsableImage(data) else { return nil }

        let name = fileName(for: stem, url: url)
        let target = try directory().appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        return name
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
