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

    /// „Dieses Bild gehört **nicht** zu diesem Buch" — von Hand entschieden.
    ///
    /// Ohne dieses Gedächtnis ist jede Handkorrektur wertlos: am 2026-08-09 wurden drei
    /// falsche Cover zurückgenommen, und der nächste `--fetch-covers` am Morgen darauf
    /// holte zwei davon wieder. Die Kette findet dieselbe Quelle ja erneut.
    private var rejected: Set<String> = []
    private var didLoadRejections = false

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
        // Von Hand verworfen heißt: nie wieder. Sonst dreht der nächste Lauf jede
        // Korrektur zurück — am 2026-08-10 geschehen, zwei von drei Rücknahmen waren
        // nach einem `--fetch-covers` wieder da.
        if try isRejected(data, identity: owner) { return nil }

        let digest = Self.digest(of: data)
        if let existing = try ownerOfImage(digest), existing != owner { return nil }

        let name = fileName(for: stem, url: url)
        let target = try directory().appendingPathComponent(name)
        try data.write(to: target, options: .atomic)
        knownImages[digest] = owner
        return name
    }

    /// Merkt sich, dass dieses Bild nicht zu diesem Buch gehört — damit kein späterer
    /// Lauf es zurückholt. Ohne Bild (Buch hatte keine Datei) passiert nichts.
    public func reject(imageNamed name: String, for identity: String) throws {
        guard let url = fileURL(for: name), let data = try? Data(contentsOf: url) else { return }
        try loadRejections()
        let entry = "\(identity)\t\(Self.digest(of: data))"
        guard rejected.insert(entry).inserted else { return }
        try (rejected.sorted().joined(separator: "\n") + "\n")
            .write(to: try rejectionFile(), atomically: true, encoding: .utf8)
    }

    /// Hebt eine Sperre auf — wer ein Bild bewusst zuweist, hat seine frühere
    /// Ablehnung damit widerrufen.
    private func unreject(_ data: Data, identity: String) throws {
        try loadRejections()
        let entry = "\(identity)\t\(Self.digest(of: data))"
        guard rejected.remove(entry) != nil else { return }
        try (rejected.sorted().joined(separator: "\n") + "\n")
            .write(to: try rejectionFile(), atomically: true, encoding: .utf8)
    }

    /// Wurde dieses Bild für dieses Buch schon einmal von Hand verworfen?
    public func isRejected(_ data: Data, identity: String) throws -> Bool {
        try loadRejections()
        return rejected.contains("\(identity)\t\(Self.digest(of: data))")
    }

    private func rejectionFile() throws -> URL {
        try directory().appendingPathComponent("abgelehnte-cover.tsv")
    }

    private func loadRejections() throws {
        guard !didLoadRejections else { return }
        didLoadRejections = true
        guard let text = try? String(contentsOf: try rejectionFile(), encoding: .utf8) else { return }
        rejected = Set(text.split(separator: "\n").map(String.init).filter { $0.contains("\t") })
    }

    /// Legt ein bereits vorliegendes Bild ab — für von Hand geprüfte Cover.
    ///
    /// Derselbe Weg wie `download`, nur ohne Netz: gleicher Mindestgrößen-Test, gleicher
    /// Platzhalter-Wächter, gleicher Dateistamm. Ein zweiter Weg in denselben Ordner, der
    /// diese Prüfungen nicht mitnimmt, hebelt sie für alle auf.
    /// - Parameter trusted: Ein Mensch hat das Bild angesehen und zugewiesen.
    ///
    ///   Dann gelten die Wächter nicht. Sie ersetzen ein Urteil, das hier bereits
    ///   vorliegt: der Platzhalter-Wächter schließt aus dem *Verdacht*, zwei gleiche
    ///   Bilder seien ein Verlagsplatzhalter, und die Sperrliste hält eine frühere
    ///   automatische Fehlzuordnung fest. Beides ist schwächer als jemand, der das Cover
    ///   vor Augen hat. Eine bestehende Sperre für dieses Buch wird dabei aufgehoben —
    ///   sonst müsste man sie an anderer Stelle von Hand pflegen.
    ///
    ///   Die Mindestgröße bleibt auch hier: eine 43-Byte-Fehlanzeige ist kein Bild,
    ///   egal wer sie zuweist.
    public func store(_ data: Data,
                      stem: String,
                      identity: String? = nil,
                      extension ext: String = "jpg",
                      trusted: Bool = false) async throws -> String? {
        guard !stem.isEmpty, Self.isUsableImage(data) else { return nil }
        let owner = identity ?? stem
        if trusted {
            try unreject(data, identity: owner)
        } else {
            if try isRejected(data, identity: owner) { return nil }
            let digest = Self.digest(of: data)
            if let existing = try ownerOfImage(digest), existing != owner { return nil }
        }
        let digest = Self.digest(of: data)

        let name = "\(stem).\(ext.isEmpty ? "jpg" : ext)"
        try data.write(to: try directory().appendingPathComponent(name), options: .atomic)
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
