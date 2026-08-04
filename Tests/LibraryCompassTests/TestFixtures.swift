import XCTest
import CryptoKit
import SwiftData
@testable import LibraryCompassCore

/// Gemeinsame Pfade und Helfer für die Tests gegen die echten Delicious-Library-Exporte.
/// Die Dateien liegen bewusst außerhalb des Repos (private Daten, `.gitignore` deckt `*.xml`).
enum Fixtures {
    static let sampleURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/Library Export 2026-07-17 Kopie.xml")

    static let originalURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/Library Export 2026-07-17.xml")

    static func requireFile(_ url: URL) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "Testdatei fehlt: \(url.path)")
    }

    static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func freshContext() throws -> ModelContext {
        ModelContext(try LibraryStore.inMemoryContainer())
    }
}
