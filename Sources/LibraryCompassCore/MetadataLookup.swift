import Foundation

/// Ergebnis eines ISBN-Lookups aus einer freien Quelle.
public struct BookMetadata: Sendable, Equatable {
    public var title: String
    public var author: String
    public var year: Int?
    public var pages: Int?
    public var coverURL: URL?

    public init(title: String = "", author: String = "", year: Int? = nil,
                pages: Int? = nil, coverURL: URL? = nil) {
        self.title = title
        self.author = author
        self.year = year
        self.pages = pages
        self.coverURL = coverURL
    }

    public var isEmpty: Bool { title.isEmpty && author.isEmpty }
}

public enum ISBN {
    /// Trennzeichen entfernen, Prüfziffer „X" behalten.
    public static func normalized(_ raw: String) -> String {
        raw.uppercased().filter { $0.isNumber || $0 == "X" }
    }
}

/// Autor-Abgleich für den Titelsuche-Fallback (BUILD-HANDOVER §4/§9).
public enum AuthorMatch {
    public static func matches(_ lhs: String, _ rhs: String) -> Bool {
        let a = tokens(lhs), b = tokens(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return !a.intersection(b).isEmpty && a.intersection(b).count >= min(a.count, b.count)
    }

    private static func tokens(_ value: String) -> Set<String> {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
        return Set(folded.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count > 1 })
    }
}

/// Aus dem gespeicherten Titel den Teil machen, mit dem sich suchen lässt.
/// DNB-Titel schleppen Ausgabevarianten und Untertitel mit:
/// „[Kill for me, kill for you] ; Kill for me: Thriller: sie tötet …" → „Kill for me".
public enum SearchTitle {
    public static func simplify(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Steht die Variante in eckigen Klammern vorweg, gilt der Teil dahinter.
        if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
            let after = value[value.index(after: close)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;·/"))
            value = after.isEmpty
                ? String(value[value.index(after: value.startIndex)..<close])
                : after
        }

        // Mehrere Fassungen stehen durch Semikolon getrennt — die erste genügt.
        if let semicolon = value.range(of: " ; ") {
            value = String(value[..<semicolon.lowerBound])
        }
        // Untertitel hinter dem Doppelpunkt hilft bei der Suche nicht.
        if let colon = value.range(of: ":") {
            value = String(value[..<colon.lowerBound])
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public protocol HTTPClient: Sendable {
    /// Liefert Rumpf und HTTP-Status.
    func get(_ url: URL) async throws -> (Data, Int)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("LibraryCompass/0.1 (privat)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// Open Library — primäre Quelle, kein API-Key.
public enum OpenLibrary {
    public static func booksURL(isbn: String) -> URL {
        URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&jscmd=data&format=json")!
    }

    public static func coverURL(isbn: String) -> URL {
        URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")!
    }

    /// Cover einer Ausgabe, die Open Library nur über die Suche kennt (`cover_i`).
    public static func coverURL(coverID: Int) -> URL {
        URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")!
    }

    public static func searchURL(title: String, author: String = "") -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        var items = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "limit", value: "5")
        ]
        if !author.isEmpty { items.insert(URLQueryItem(name: "author", value: author), at: 1) }
        components.queryItems = items
        return components.url!
    }

    public static func parse(_ data: Data, isbn: String) -> BookMetadata? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = root["ISBN:\(isbn)"] as? [String: Any] else { return nil }

        var metadata = BookMetadata()
        metadata.title = (entry["title"] as? String) ?? ""
        if let authors = entry["authors"] as? [[String: Any]] {
            metadata.author = authors.compactMap { $0["name"] as? String }.joined(separator: ", ")
        }
        metadata.pages = entry["number_of_pages"] as? Int
        metadata.year = yearFromText(entry["publish_date"] as? String)
        if let cover = entry["cover"] as? [String: Any],
           let large = (cover["large"] ?? cover["medium"]) as? String {
            metadata.coverURL = URL(string: large)
        }
        return metadata.isEmpty ? nil : metadata
    }

    /// Autor-Namen aus der Titelsuche (nur für den Abgleich, nicht als Metadaten).
    /// `coverID` ist der verlässlichere Weg zum Bild: viele Treffer führen gar keine ISBN.
    public static func searchResults(_ data: Data) -> [(title: String, author: String, isbn: String?, coverID: Int?)] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = root["docs"] as? [[String: Any]] else { return [] }
        return docs.map { doc in
            (title: (doc["title"] as? String) ?? "",
             author: ((doc["author_name"] as? [String]) ?? []).joined(separator: ", "),
             isbn: (doc["isbn"] as? [String])?.first,
             coverID: doc["cover_i"] as? Int)
        }
    }

    static func yearFromText(_ text: String?) -> Int? {
        guard let text else { return nil }
        guard let match = text.range(of: "[0-9]{4}", options: .regularExpression) else { return nil }
        return Int(text[match])
    }
}

/// Google Books — Fallback. Anonym drosselt Google aggressiv (429), deshalb
/// sequenziell mit Backoff und ohne Parallelzugriff (BUILD-HANDOVER §4/§9).
public enum GoogleBooks {
    public static func volumesURL(isbn: String, key: String? = nil) -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [URLQueryItem(name: "q", value: "isbn:\(isbn)")]
        if let key, !key.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "key", value: key))
        }
        return components.url!
    }

    /// Suche über Titel und Autor statt über die ISBN — für Ausgaben, die unter
    /// ihrer ISBN kein Bild führen.
    public static func searchURL(title: String, author: String, key: String? = nil) -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        var items = [URLQueryItem(name: "q", value: "intitle:\"\(title)\" inauthor:\"\(author)\"")]
        if let key, !key.isEmpty { items.append(URLQueryItem(name: "key", value: key)) }
        components.queryItems = items
        return components.url!
    }

    /// Alle Treffer mit Autor und Bild — für den Abgleich, nicht als Metadaten.
    public static func searchResults(_ data: Data) -> [(title: String, author: String, coverURL: URL?)] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let info = item["volumeInfo"] as? [String: Any] else { return nil }
            return (title: (info["title"] as? String) ?? "",
                    author: ((info["authors"] as? [String]) ?? []).joined(separator: ", "),
                    coverURL: coverURL(from: info))
        }
    }

    static func coverURL(from info: [String: Any]) -> URL? {
        guard let links = info["imageLinks"] as? [String: Any],
              let raw = (links["thumbnail"] ?? links["smallThumbnail"]) as? String else { return nil }
        return URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
    }

    public static func parse(_ data: Data) -> BookMetadata? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]],
              let info = items.first?["volumeInfo"] as? [String: Any] else { return nil }

        var metadata = BookMetadata()
        metadata.title = (info["title"] as? String) ?? ""
        metadata.author = ((info["authors"] as? [String]) ?? []).joined(separator: ", ")
        // Google schickt bei unbekanntem Umfang `pageCount: 0` — das ist keine Angabe.
        metadata.pages = (info["pageCount"] as? Int).flatMap { $0 > 0 ? $0 : nil }
        metadata.year = OpenLibrary.yearFromText(info["publishedDate"] as? String)
        if let links = info["imageLinks"] as? [String: Any],
           let raw = (links["thumbnail"] ?? links["smallThumbnail"]) as? String {
            metadata.coverURL = URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
        }
        return metadata.isEmpty ? nil : metadata
    }
}

/// Cover von Amazon — der einzige Weg, der **ausgabegenau** ist: die Adresse führt
/// über die ISBN-10, also genau die Ausgabe, die im Regal steht. Freie Quellen
/// liefern für deutsche Titel oft die englische Ausgabe oder gar nichts.
///
/// Achtung: Der Endpunkt nimmt jede ASIN, nicht nur Bücher. `1234567890` (falsche
/// Prüfziffer, aber gültige ASIN) lieferte live ein Foto von Bremsscheiben. Deshalb
/// wird nur mit geprüfter ISBN-10 angefragt.
public enum AmazonCover {
    /// Antwortet Amazon mit wenigen Bytes, gibt es zu dieser ISBN kein Bild.
    public static func url(isbn: String) -> URL? {
        guard let key = isbn10(from: isbn) else { return nil }
        return URL(string: "https://m.media-amazon.com/images/P/\(key).01.LZZZZZZZ.jpg")
    }

    /// Vorhandene ISBN-10 durchreichen, ISBN-13 mit 978-Präfix umrechnen.
    /// Prüfziffer muss stimmen, sonst wird gar nicht erst gefragt.
    public static func isbn10(from raw: String) -> String? {
        let value = ISBN.normalized(raw)
        if value.count == 10 { return isValidISBN10(value) ? value : nil }
        guard value.count == 13, value.hasPrefix("978"), isValidISBN13(value) else { return nil }

        let core = String(value.dropFirst(3).dropLast())
        let sum = core.enumerated().reduce(0) { total, pair in
            total + (10 - pair.offset) * Int(String(pair.element)).orZero
        }
        let remainder = (11 - sum % 11) % 11
        return core + (remainder == 10 ? "X" : String(remainder))
    }

    static func isValidISBN10(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        var sum = 0
        for (index, character) in value.enumerated() {
            let digit: Int
            if character == "X" {
                guard index == 9 else { return false }
                digit = 10
            } else {
                guard let value = Int(String(character)) else { return false }
                digit = value
            }
            sum += (10 - index) * digit
        }
        return sum % 11 == 0
    }

    static func isValidISBN13(_ value: String) -> Bool {
        guard value.count == 13, value.allSatisfy(\.isNumber) else { return false }
        let sum = value.enumerated().reduce(0) { total, pair in
            total + Int(String(pair.element)).orZero * (pair.offset % 2 == 0 ? 1 : 3)
        }
        return sum % 10 == 0
    }
}

private extension Optional where Wrapped == Int {
    var orZero: Int { self ?? 0 }
}

/// Herkunft des Google-Books-Schlüssels. Der Schlüssel steht in einer Datei neben
/// dem Store, nie im Repo: `~/Library/Application Support/LibraryCompass/google-books-key.txt`.
/// Für Skripte und Tests sticht die Umgebungsvariable `GOOGLE_BOOKS_API_KEY`.
public enum GoogleBooksKey {
    public static let environmentVariable = "GOOGLE_BOOKS_API_KEY"
    public static let fileName = "google-books-key.txt"

    /// Der Schlüssel dieser Maschine, oder `nil` — dann fragt die App Google anonym.
    public static func current() -> String? {
        resolve(environment: ProcessInfo.processInfo.environment, file: try? defaultFileURL())
    }

    public static func defaultFileURL() throws -> URL {
        try LibraryStore.applicationSupportDirectory().appendingPathComponent(fileName)
    }

    static func resolve(environment: [String: String], file: URL?) -> String? {
        if let value = clean(environment[environmentVariable]) { return value }
        guard let file, let contents = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return clean(contents)
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// Deutsche Nationalbibliothek über SRU — kein API-Key, Pflichtexemplar-Katalog.
/// Nötig, weil Open Library deutsche Ausgaben oft nicht kennt und Google Books
/// anonym pro Tag drosselt (live 2026-08-05: `{}` bzw. 429 zu 9783785728390).
/// Cover liefert die DNB nicht — dafür bleiben Open Library und Google zuständig.
public enum DNB {
    public static func searchURL(isbn: String) -> URL {
        var components = URLComponents(string: "https://services.dnb.de/sru/dnb")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.1"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            URLQueryItem(name: "query", value: "NUM=\(isbn)"),
            URLQueryItem(name: "recordSchema", value: "oai_dc"),
            URLQueryItem(name: "maximumRecords", value: "1")
        ]
        return components.url!
    }

    public static func parse(_ data: Data) -> BookMetadata? {
        let fields = DublinCoreFields.parse(data)
        guard let rawTitle = fields["title"]?.first, !rawTitle.isEmpty else { return nil }

        var metadata = BookMetadata()
        metadata.title = title(from: rawTitle)
        metadata.author = author(from: fields["creator"] ?? [])
        metadata.year = OpenLibrary.yearFromText(fields["date"]?.first)
        metadata.pages = pages(from: fields["format"] ?? [])
        return metadata.isEmpty ? nil : metadata
    }

    /// „Toxin : Thriller / Kathrin Lange" → „Toxin".
    /// Der Katalogtitel trägt Ausgabevariante, Verfasserangabe und Gattung mit sich.
    static func title(from raw: String) -> String {
        TitleCleanup.clean(raw.replacingOccurrences(of: " : ", with: ": "))
    }

    /// „Lange, Kathrin [Verfasser]" → „Lange, Kathrin". Verfasser haben Vorrang;
    /// nennt der Datensatz keinen, bleiben Herausgeber oder Übersetzer übrig.
    static func author(from creators: [String]) -> String {
        let entries = creators.map { entry -> (name: String, role: String) in
            let role = entry.range(of: "\\[[^\\]]+\\]", options: .regularExpression)
                .map { String(entry[$0].dropFirst().dropLast()) } ?? ""
            let name = entry.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (name, role)
        }.filter { !$0.name.isEmpty }

        let authors = entries.filter { $0.role.hasPrefix("Verfasser") }
        let chosen = authors.isEmpty ? entries : authors
        // Namen stehen als „Nachname, Vorname" — Semikolon trennt sie eindeutig.
        return chosen.map(\.name).joined(separator: "; ")
    }

    /// „459 Seiten" → 459.
    static func pages(from formats: [String]) -> Int? {
        for value in formats {
            guard value.localizedCaseInsensitiveContains("seite"),
                  let match = value.range(of: "[0-9]+", options: .regularExpression) else { continue }
            return Int(value[match])
        }
        return nil
    }
}

/// Sammelt die Dublin-Core-Felder einer SRU-Antwort nach lokalem Elementnamen.
enum DublinCoreFields {
    private static let wanted: Set<String> = ["title", "creator", "date", "format"]

    static func parse(_ data: Data) -> [String: [String]] {
        let collector = Collector(wanted: wanted)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = collector
        parser.parse()
        return collector.fields
    }

    private final class Collector: NSObject, XMLParserDelegate {
        private let wanted: Set<String>
        private var current: String?
        private var buffer = ""
        var fields: [String: [String]] = [:]

        init(wanted: Set<String>) {
            self.wanted = wanted
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            current = wanted.contains(name) ? name : nil
            buffer = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard current != nil else { return }
            buffer += string
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                    qualifiedName: String?) {
            guard let key = current, key == name else { return }
            let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { fields[key, default: []].append(value) }
            current = nil
            buffer = ""
        }
    }
}

/// ISBN → Titel, Autor, Cover. Immer sequenziell: Open Library, DNB, dann Google Books.
public actor MetadataLookup {
    private let client: HTTPClient
    private let backoff: @Sendable (Int) async -> Void
    /// Eigener Schlüssel hebt Googles Tagesquote; ohne ihn bleibt es beim anonymen Zugriff.
    private let apiKey: String?

    public init(client: HTTPClient = URLSessionHTTPClient(), apiKey: String? = GoogleBooksKey.current()) {
        self.client = client
        self.apiKey = apiKey
        self.backoff = { attempt in
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 800_000_000))
        }
    }

    init(client: HTTPClient, backoff: @escaping @Sendable (Int) async -> Void, apiKey: String? = nil) {
        self.client = client
        self.backoff = backoff
        self.apiKey = apiKey
    }

    public func metadata(isbn rawISBN: String) async throws -> BookMetadata? {
        let isbn = ISBN.normalized(rawISBN)
        guard !isbn.isEmpty else { return nil }

        var result: BookMetadata?

        if let (data, status) = try? await client.get(OpenLibrary.booksURL(isbn: isbn)), status == 200 {
            result = OpenLibrary.parse(data, isbn: isbn)
        }

        // Deutsche Ausgaben fehlen bei Open Library häufig; die DNB kennt sie und
        // antwortet ohne Schlüssel und ohne Tagesquote — deshalb vor Google.
        if result == nil || result?.title.isEmpty == true {
            if let (data, status) = try? await client.get(DNB.searchURL(isbn: isbn)), status == 200,
               let record = DNB.parse(data) {
                result = merge(result, record)
            }
        }

        var askedGoogle = false
        if result == nil || result?.title.isEmpty == true {
            askedGoogle = true
            if let google = try await googleBooks(isbn: isbn) {
                result = merge(result, google)
            }
        }

        guard var metadata = result else { return nil }

        if metadata.coverURL == nil || !askedGoogle {
            metadata.coverURL = await coverURL(isbn: isbn,
                                               title: metadata.title,
                                               author: metadata.author,
                                               skipGoogleISBN: askedGoogle,
                                               current: metadata.coverURL)
        }
        return metadata
    }

    /// Cover-Kette getrennt vom Metadaten-Lookup: Bestandsbücher haben Titel und Autor
    /// längst, ihnen fehlt nur das Bild — und zu manchen ISBN gibt es Metadaten nirgends,
    /// wohl aber ein Cover.
    public func coverURL(isbn: String, title: String = "", author: String = "") async -> URL? {
        await coverURL(isbn: isbn, title: title, author: author, skipGoogleISBN: false, current: nil)
    }

    private func coverURL(isbn: String,
                          title: String,
                          author: String,
                          skipGoogleISBN: Bool,
                          current: URL?) async -> URL? {
        // Amazon zuerst: nur diese Quelle trifft die Ausgabe, die im Regal steht.
        if let amazon = AmazonCover.url(isbn: isbn), let cover = await usableCover(amazon) {
            return cover
        }
        if let current { return current }

        if !isbn.isEmpty, let cover = await usableOpenLibraryCover(isbn: isbn) { return cover }

        // Die DNB liefert nie ein Bild. Google ist die letzte Quelle, die eines zur
        // ISBN haben kann — auch wenn Titel und Autor längst feststehen.
        if !isbn.isEmpty, !skipGoogleISBN,
           let google = try? await googleBooks(isbn: isbn), let cover = google.coverURL {
            return cover
        }
        // Letzte Stufe: Titelsuche, aber nur mit Autor-Abgleich — reine Titelsuche
        // liefert falsche Bilder.
        return try? await coverByTitle(title: title, author: author)
    }

    /// Google Books sequenziell mit Backoff bei 429.
    private func googleBooks(isbn: String) async throws -> BookMetadata? {
        for attempt in 0..<3 {
            let (data, status) = try await client.get(GoogleBooks.volumesURL(isbn: isbn, key: apiKey))
            if status == 429 {
                await backoff(attempt)
                continue
            }
            guard status == 200 else { return nil }
            return GoogleBooks.parse(data)
        }
        return nil
    }

    /// Open Library antwortet mit 1×1-Pixeln statt 404 — deshalb Größencheck.
    private func usableOpenLibraryCover(isbn: String) async -> URL? {
        await usableCover(OpenLibrary.coverURL(isbn: isbn))
    }

    private func usableCover(_ url: URL) async -> URL? {
        guard let (data, status) = try? await client.get(url), status == 200,
              CoverCache.isUsableImage(data) else { return nil }
        return url
    }

    private func merge(_ base: BookMetadata?, _ other: BookMetadata) -> BookMetadata {
        guard var merged = base else { return other }
        if merged.title.isEmpty { merged.title = other.title }
        if merged.author.isEmpty { merged.author = other.author }
        if merged.year == nil { merged.year = other.year }
        if merged.pages == nil { merged.pages = other.pages }
        if merged.coverURL == nil { merged.coverURL = other.coverURL }
        return merged
    }

    /// Letzte Stufe für Bestandsbücher ohne ISBN-Treffer: Titelsuche, aber nur
    /// mit Autor-Abgleich — reine Titelsuche liefert falsche Cover.
    public func coverByTitle(title: String, author: String) async throws -> URL? {
        let query = SearchTitle.simplify(title)
        guard !query.isEmpty, !author.isEmpty else { return nil }

        if let (data, status) = try? await client.get(OpenLibrary.searchURL(title: query, author: author)),
           status == 200 {
            for candidate in OpenLibrary.searchResults(data) {
                guard AuthorMatch.matches(author, candidate.author) else { continue }
                if let coverID = candidate.coverID,
                   let cover = await usableCover(OpenLibrary.coverURL(coverID: coverID)) {
                    return cover
                }
                if let isbn = candidate.isbn, let cover = await usableOpenLibraryCover(isbn: isbn) {
                    return cover
                }
            }
        }

        // Open Library kennt viele Ausgaben gar nicht; Google führt sie über Titel
        // und Autor, auch wenn es unter der ISBN nichts hat.
        if let (data, status) = try? await client.get(GoogleBooks.searchURL(title: query, author: author, key: apiKey)),
           status == 200 {
            for candidate in GoogleBooks.searchResults(data) {
                guard AuthorMatch.matches(author, candidate.author), let cover = candidate.coverURL else { continue }
                return cover
            }
        }
        return nil
    }
}
