import AppKit
import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers
import LibraryCompassCore

enum ViewMode: String {
    case grid, list
}

enum ActiveDialog: Equatable {
    case isbn
    case importer
    case scanner
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

    // MARK: Cover von Hand

    /// Rückmeldung zum letzten von Hand eingesetzten Cover.
    var coverMessage: String?

    /// Nimmt ein Bild an, das ein Mensch ausgesucht hat — aus dem Browser gezogen oder
    /// aus der Zwischenablage.
    ///
    /// Für 96 Bücher gibt es kein Cover bei einer Quelle, die die App abfragen darf:
    /// alte deutsche Ausgaben, die kein freier Katalog je erfasst hat, und
    /// Selbstverlagstitel ohne ISBN-10. Sichtbar sind die Bilder trotzdem — nur eben
    /// dort, wo ein Mensch nachsehen darf und ein Programm nicht.
    @discardableResult
    func setCover(from data: Data, for book: Book) async -> Bool {
        guard CoverCache.isUsableImage(data) else {
            coverMessage = "Das sind nur \(data.count) Byte — kein Bild."
            return false
        }
        guard let stem = CoverKey.stem(isbn: book.isbn, title: book.title, author: book.author) else {
            coverMessage = "Das Buch führt weder ISBN noch Titel."
            return false
        }
        let identity = CoverKey.identity(isbn: book.isbn, title: book.title, author: book.author)
        guard let name = try? await CoverCache.shared.store(data, stem: stem, identity: identity,
                                                           trusted: true) else {
            coverMessage = "Das Bild ließ sich nicht ablegen."
            return false
        }
        book.coverPath = name
        coverMessage = nil
        didEdit()
        return true
    }

    /// Wie `setCover(from:for:)`, aber über die Kennung des Buchs.
    ///
    /// Ein gezogenes Bild kommt aus einem Rückruf des Systems, also von einem anderen
    /// Ausführungsstrang. `Book` gehört dem Hauptstrang und darf ihn nicht verlassen —
    /// die Kennung schon.
    @discardableResult
    func setCover(from data: Data, forBookWith id: PersistentIdentifier) async -> Bool {
        guard let book = books.first(where: { $0.persistentModelID == id }) else { return false }
        return await setCover(from: data, for: book)
    }

    /// Bild aus der Zwischenablage — der zweite Weg neben dem Ziehen.
    @discardableResult
    func pasteCover(for book: Book) async -> Bool {
        let board = NSPasteboard.general
        // Erst die Datei-URL: ein aus dem Browser gesichertes Bild landet so auf dem
        // Board und behält seine Auflösung. `NSImage` aus dem Board ist oft die
        // heruntergerechnete Bildschirmfassung.
        if let urls = board.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first, let data = try? Data(contentsOf: url) {
            return await setCover(from: data, for: book)
        }
        if let image = NSImage(pasteboard: board),
           let tiff = image.tiffRepresentation,
           let data = NSBitmapImageRep(data: tiff)?.representation(using: .jpeg,
                                                                  properties: [.compressionFactor: 0.9]) {
            return await setCover(from: data, for: book)
        }
        coverMessage = "In der Zwischenablage ist kein Bild."
        return false
    }

    /// Öffnet Titel und Verfasser als Suche im Browser des Nutzers.
    ///
    /// Die App fragt Amazon **nicht** selbst ab: `amazon.de/robots.txt` schließt
    /// automatisierte Zugriffe aus. Ein Mensch, der nach seinen eigenen Büchern sucht,
    /// ist davon nicht betroffen — deshalb öffnet dieser Knopf nur die Seite.
    func searchCoverOnline(for book: Book) {
        guard let url = CoverSearch.url(title: book.title, author: book.author) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Löschen

    /// Buch, dessen Löschung noch bestätigt werden muss. `nil` heißt: keine Rückfrage offen.
    var pendingDeletion: Book?

    /// Entfernt einen Eintrag aus dem Bestand.
    ///
    /// Die Cover-Datei bleibt liegen. Der Bestand führt Dubletten desselben Buchs, und
    /// zwei Einträge können sich eine Bilddatei teilen — wer sie mitlöscht, nimmt dem
    /// verbliebenen Eintrag sein Cover. Eine Karteileiche im Ordner ist der billigere Fehler.
    func delete(_ book: Book) {
        if selection?.persistentModelID == book.persistentModelID { selection = nil }
        if pendingDeletion?.persistentModelID == book.persistentModelID { pendingDeletion = nil }
        context.delete(book)
        try? context.save()
        reload()
    }

    // MARK: Buch per ISBN anlegen

    /// Titel und Verfasser für ein Buch, das keine ISBN hat.
    var manualTitle = ""
    var manualAuthor = ""
    /// Steht auf `true`, wenn die Eingabe keine ISBN war — dann fragt der Dialog nach
    /// Titel und Verfasser, statt den Eintrag mit einer erfundenen ISBN anzulegen.
    var needsManualEntry = false

    @discardableResult
    func addBook(isbn rawISBN: String) -> Book? {
        let input = rawISBN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        // Eine eingefügte Amazon-Adresse trägt die Kennung im Pfad; sie kann eine ISBN-10
        // sein (dann geht es normal weiter) oder eine ASIN (dann gibt es keine ISBN).
        let isbn = AmazonReference.identifier(inURL: input) ?? input

        guard ISBN.isPlausible(isbn) else {
            needsManualEntry = true
            lookupMessage = AmazonReference.isASIN(isbn)
                ? "\(isbn) ist eine Amazon-Kennung, keine ISBN — dieses Buch hat keine. Titel und Verfasser eintragen."
                : "„\(input)“ ist keine gültige ISBN. Titel und Verfasser eintragen."
            return nil
        }

        let normalized = ISBN.normalized(isbn)

        // Dieselbe ISBN erneut eingeben heißt: nochmal nachschlagen, nicht verdoppeln.
        // Genau so repariert sich ein Eintrag, dessen Lookup beim ersten Mal scheiterte.
        if let existing = LibraryStore.book(isbn: normalized, in: context) {
            selection = existing
            Task { await fillMetadata(for: existing) }
            return existing
        }

        // Erfasst heißt gelesen — sonst fehlt dem Buch jedes Datum, unter dem man es
        // wiederfindet (Nutzerregel 2026-08-08).
        let book = NewBook.make(isbn: normalized)
        context.insert(book)
        try? context.save()
        reload()
        selection = book
        Task { await fillMetadata(for: book) }
        return book
    }

    /// Legt ein Buch ohne ISBN an — für E-Books und Selbstverlagstitel, die keine haben.
    /// Das Cover kann später nur über die Titelsuche kommen, und die braucht den
    /// Verfasser als Anker; ohne ihn wird kein Eintrag angelegt.
    @discardableResult
    func addBookManually(title rawTitle: String, author rawAuthor: String) -> Book? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = rawAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            lookupMessage = "Ohne Titel lässt sich das Buch nicht anlegen."
            return nil
        }
        guard !author.isEmpty else {
            lookupMessage = "Ohne Verfasser findet die Titelsuche später kein Cover — bitte eintragen."
            return nil
        }

        let book = NewBook.make(isbn: "")
        book.title = title
        book.author = author
        context.insert(book)
        try? context.save()
        reload()
        selection = book
        needsManualEntry = false
        lookupMessage = nil
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
               let stem = CoverKey.stem(isbn: book.isbn, title: book.title, author: book.author),
               let path = try? await CoverCache.shared.download(
                   from: coverURL, stem: stem,
                   identity: CoverKey.identity(isbn: book.isbn, title: book.title, author: book.author)) {
                book.coverPath = path
            }
            didEdit()
        } catch {
            lookupMessage = "Metadaten konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    // MARK: Scannen

    /// Titel der in dieser Sitzung gescannten Bücher — Rückmeldung im Scan-Dialog.
    private(set) var scannedTitles: [String] = []

    /// Ein gescannter Strichcode geht denselben Weg wie eine eingetippte ISBN:
    /// vorhandenes Buch wird aufgefrischt, neues angelegt und nachgeschlagen.
    func addScanned(isbn: String) {
        guard let book = addBook(isbn: isbn) else { return }
        let placeholder = book.title.isEmpty ? isbn : book.title
        scannedTitles.append(placeholder)
        Task { @MainActor in
            // Nach dem Lookup steht der richtige Titel — Anzeige nachziehen.
            await fillMetadata(for: book)
            if let index = scannedTitles.lastIndex(of: placeholder), !book.title.isEmpty {
                scannedTitles[index] = book.title
            }
        }
    }

    func finishScanning() {
        scannedTitles.removeAll()
        dialog = nil
    }

    // MARK: Export

    /// Bibliothek als CSV sichern — Speicherort wählt der Nutzer.
    func exportLibrary() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = LibraryExport.fileName
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try LibraryExport.csv(books).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("LibraryCompass Export: %@", error.localizedDescription)
        }
    }

    /// Alles ohne eigenes Gelesen-Datum bekommt das Erfassungsdatum.
    func markAllAsRead() {
        ReadDates.markAllAsRead(in: context)
        reload()
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
