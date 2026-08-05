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

    public static func searchURL(title: String) -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "limit", value: "5")
        ]
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
    public static func searchResults(_ data: Data) -> [(title: String, author: String, isbn: String?)] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = root["docs"] as? [[String: Any]] else { return [] }
        return docs.map { doc in
            (title: (doc["title"] as? String) ?? "",
             author: ((doc["author_name"] as? [String]) ?? []).joined(separator: ", "),
             isbn: (doc["isbn"] as? [String])?.first)
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
    public static func volumesURL(isbn: String) -> URL {
        URL(string: "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)")!
    }

    public static func parse(_ data: Data) -> BookMetadata? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]],
              let info = items.first?["volumeInfo"] as? [String: Any] else { return nil }

        var metadata = BookMetadata()
        metadata.title = (info["title"] as? String) ?? ""
        metadata.author = ((info["authors"] as? [String]) ?? []).joined(separator: ", ")
        metadata.pages = info["pageCount"] as? Int
        metadata.year = OpenLibrary.yearFromText(info["publishedDate"] as? String)
        if let links = info["imageLinks"] as? [String: Any],
           let raw = (links["thumbnail"] ?? links["smallThumbnail"]) as? String {
            metadata.coverURL = URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
        }
        return metadata.isEmpty ? nil : metadata
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

    /// „Toxin : Thriller / Kathrin Lange" → „Toxin: Thriller".
    /// Hinter dem Schrägstrich steht die Verfasserangabe, die schon im Autorfeld steht.
    static func title(from raw: String) -> String {
        let withoutResponsibility = raw.components(separatedBy: " / ").first ?? raw
        return withoutResponsibility
            .replacingOccurrences(of: " : ", with: ": ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    public init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
        self.backoff = { attempt in
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 800_000_000))
        }
    }

    init(client: HTTPClient, backoff: @escaping @Sendable (Int) async -> Void) {
        self.client = client
        self.backoff = backoff
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

        if result == nil || result?.title.isEmpty == true {
            if let google = try await googleBooks(isbn: isbn) {
                result = merge(result, google)
            }
        }

        guard var metadata = result else { return nil }

        if metadata.coverURL == nil, let cover = await usableOpenLibraryCover(isbn: isbn) {
            metadata.coverURL = cover
        }
        // Letzte Cover-Stufe: Titelsuche, aber nur mit Autor-Abgleich — DNB-Treffer
        // haben nie ein Cover dabei, und reine Titelsuche liefert falsche Bilder.
        if metadata.coverURL == nil,
           let cover = try? await coverByTitle(title: metadata.title, author: metadata.author) {
            metadata.coverURL = cover
        }
        return metadata
    }

    /// Google Books sequenziell mit Backoff bei 429.
    private func googleBooks(isbn: String) async throws -> BookMetadata? {
        for attempt in 0..<3 {
            let (data, status) = try await client.get(GoogleBooks.volumesURL(isbn: isbn))
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
        let url = OpenLibrary.coverURL(isbn: isbn)
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
        guard !title.isEmpty, !author.isEmpty else { return nil }
        let (data, status) = try await client.get(OpenLibrary.searchURL(title: title))
        guard status == 200 else { return nil }

        for candidate in OpenLibrary.searchResults(data) {
            guard AuthorMatch.matches(author, candidate.author), let isbn = candidate.isbn else { continue }
            if let cover = await usableOpenLibraryCover(isbn: isbn) { return cover }
        }
        return nil
    }
}
