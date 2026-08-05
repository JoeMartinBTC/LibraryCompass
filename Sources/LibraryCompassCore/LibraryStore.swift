import Foundation
import SwiftData

/// Zugang zum lokalen SwiftData-Store. Kein CloudKit, kein Server.
public enum LibraryStore {
    public static let schema = Schema([Book.self])

    /// Store auf einer bestimmten Datei — für Tests und den UI-Testmodus.
    public static func container(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: schema,
                           configurations: ModelConfiguration(schema: schema, url: url))
    }

    /// Flüchtiger Store ohne Datei.
    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: schema,
                           configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    /// Der echte Store der App: `~/Library/Application Support/LibraryCompass/Library.store`.
    public static func defaultContainer() throws -> ModelContainer {
        try container(at: defaultStoreURL())
    }

    public static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
            .appendingPathComponent("LibraryCompass", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    public static func defaultStoreURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("Library.store")
    }

    /// Buch zu einer ISBN, unabhängig von Trennzeichen. Bücher ohne ISBN treffen nie,
    /// sonst würden die ~245 Bestandsbücher ohne ISBN alle als dasselbe Buch gelten.
    public static func book(isbn rawISBN: String, in context: ModelContext) -> Book? {
        let isbn = ISBN.normalized(rawISBN)
        guard !isbn.isEmpty else { return nil }
        var descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.isbn == isbn })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
