import Foundation
import Observation
import SwiftData
import LibraryCompassCore

enum ViewMode: String {
    case grid, list
}

enum ActiveDialog: Equatable {
    case isbn
    case importer
}

/// Zustand des Fensters (README §7, ohne Genre) plus Zugriff auf den Store.
/// Die gefilterte Liste wird gespeichert, nicht in jedem `body` neu berechnet.
@MainActor
@Observable
final class AppModel {

    // MARK: Bestand

    private(set) var books: [Book] = []
    private(set) var rows: [Book] = []
    private(set) var counts = FilterCounts()
    private(set) var stats = LibraryStats(books: [Book]())
    private(set) var recentlyRead: [Book] = []

    // MARK: Auswertung

    var filter: LibraryFilter = .alle {
        didSet { resetPaging(); rebuild() }
    }
    var search: String = "" {
        didSet { resetPaging(); rebuild() }
    }
    var sort: LibrarySort = .titel {
        didSet {
            UserDefaults.standard.set(sort.rawValue, forKey: "sort")
            resetPaging()
            rebuild()
        }
    }
    var viewMode: ViewMode = .grid {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "view") }
    }
    var limit = Metrics.pageSize
    var selection: Book?

    // MARK: Dialoge

    var dialog: ActiveDialog?
    var isbnInput = ""
    var isLookingUp = false
    var lookupMessage: String?

    var importFile: URL?
    var importEntryCount: Int?
    var importFileSize: Int64?
    var importProgress: Double = 0
    var importDone = 0
    var importTotal = 0
    var importFinished: ImportReport?
    var importRunning = false
    var importError: String?

    // MARK: Aufbau

    let context: ModelContext
    private let lookup: MetadataLookup

    init(context: ModelContext, lookup: MetadataLookup = MetadataLookup()) {
        self.context = context
        self.lookup = lookup
        if let raw = UserDefaults.standard.string(forKey: "sort"), let value = LibrarySort(rawValue: raw) {
            sort = value
        }
        if let raw = UserDefaults.standard.string(forKey: "view"), let value = ViewMode(rawValue: raw) {
            viewMode = value
        }
        reload()
    }

    /// Bestand frisch aus dem Store lesen und alles Abgeleitete neu rechnen.
    func reload() {
        books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        rebuild()
    }

    /// Nach einer Bearbeitung: sichern und Ableitungen aktualisieren.
    func didEdit() {
        try? context.save()
        rebuild()
    }

    private func resetPaging() {
        limit = Metrics.pageSize
    }

    private func rebuild() {
        let query = BookQuery(filter: filter, search: search, sort: sort)
        rows = query.apply(to: books)
        counts = query.counts(for: books)
        stats = LibraryStats(books: books)
        recentlyRead = LibraryStats.recentlyRead(books, limit: 4)
    }

    /// Sichtbarer Ausschnitt — das Grid lädt in Blöcken von 60 nach (README §6).
    var visibleRows: ArraySlice<Book> {
        rows.prefix(limit)
    }

    func loadMoreIfNeeded() {
        guard limit < rows.count else { return }
        limit += Metrics.pageSize
    }

    var screenTitle: String { filter.title }

    var countLine: String {
        "\(LCFormat.number(rows.count)) von \(LCFormat.number(books.count)) Titeln · \(sort.title)"
    }

    // MARK: Bearbeiten

    func setRating(_ rating: Int, for book: Book) {
        book.rating = min(5, max(0, rating))
        didEdit()
    }

    func setReadDate(_ date: Date?, for book: Book) {
        book.readDate = date
        didEdit()
    }

    func setComment(_ comment: String, for book: Book) {
        book.comment = comment
        didEdit()
    }

    // MARK: Buch per ISBN anlegen

    @discardableResult
    func addBook(isbn rawISBN: String) -> Book? {
        let isbn = rawISBN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isbn.isEmpty else { return nil }

        let normalized = ISBN.normalized(isbn)
        let book = Book(isbn: normalized, title: "", author: "", addedDate: Date())
        context.insert(book)
        try? context.save()
        reload()
        selection = book
        Task { await fillMetadata(for: book) }
        return book
    }

    @MainActor
    func fillMetadata(for book: Book) async {
        isLookingUp = true
        lookupMessage = nil
        defer { isLookingUp = false }

        guard !book.isbn.isEmpty else { return }
        do {
            guard let metadata = try await lookup.metadata(isbn: book.isbn) else {
                if book.title.isEmpty { book.title = "Unbekannter Titel" }
                lookupMessage = "Keine freien Metadaten zu dieser ISBN gefunden."
                didEdit()
                return
            }
            if !metadata.title.isEmpty { book.title = metadata.title }
            if !metadata.author.isEmpty { book.author = metadata.author }
            if book.year == nil { book.year = metadata.year }
            if book.pages == nil { book.pages = metadata.pages }
            if let coverURL = metadata.coverURL,
               let path = try? await CoverCache.shared.download(from: coverURL, isbn: book.isbn) {
                book.coverPath = path
            }
            didEdit()
        } catch {
            lookupMessage = "Metadaten konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    // MARK: Import

    func prepareImport(file: URL) {
        importFile = file
        importFinished = nil
        importError = nil
        importProgress = 0
        importDone = 0
        importTotal = 0
        importFileSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? nil
        importEntryCount = try? DeliciousLibraryImport.parse(url: file).books.count
    }

    @MainActor
    func runImport() async {
        guard let file = importFile, !importRunning else { return }
        importRunning = true
        importError = nil
        defer { importRunning = false }

        do {
            let report = try LibraryImporter.importFile(at: file, into: context) { done, total in
                Task { @MainActor in
                    self.importDone = done
                    self.importTotal = total
                    self.importProgress = total == 0 ? 0 : Double(done) / Double(total)
                }
            }
            importFinished = report
            importProgress = 1
            reload()
            NSLog("LibraryCompass Import: %@", report.summary)
            print(report.summary)
        } catch {
            importError = error.localizedDescription
        }
    }

    var importStatusLine: String {
        if let report = importFinished {
            let rated = books.filter { $0.rating > 0 }.count
            return "\(LCFormat.number(report.imported)) Bücher importiert · \(LCFormat.number(rated)) mit Bewertung"
        }
        if importRunning || importDone > 0 {
            return "\(LCFormat.number(importDone)) von \(LCFormat.number(importTotal)) Büchern"
        }
        return "Bereit"
    }
}
