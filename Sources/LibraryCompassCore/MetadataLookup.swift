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

    /// Eine Ausgabe, eine Schreibweise: ISBN-10 wird zur ISBN-13 gerechnet.
    /// Dieselbe Ausgabe steht im Bestand mal als `344247776X`, mal als `9783442477760`;
    /// für jeden Vergleich „ist das dasselbe Buch?" zählt die kanonische Form.
    public static func canonical(_ raw: String) -> String {
        let value = normalized(raw)
        guard value.count == 10, AmazonCover.isValidISBN10(value) else { return value }
        let core = "978" + value.dropLast()
        let sum = core.enumerated().reduce(0) { total, pair in
            total + (pair.offset % 2 == 0 ? 1 : 3) * Int(String(pair.element)).orZero
        }
        return core + String((10 - sum % 10) % 10)
    }

    /// Trägt diese Eingabe überhaupt eine ISBN?
    ///
    /// `normalized` wirft alle Buchstaben außer „X" weg. Bei einer Amazon-Kennung wie
    /// `B0BHG35KD6` bleibt davon `0356` übrig — und der Eintrag bekommt eine ISBN, die es
    /// nicht gibt, samt aussichtslosem Nachschlagen. Gemeldet vom Nutzer am 2026-08-09 an
    /// „Die Killerin — Isabella Rose". Eine Eingabe, die keine ISBN ist, muss als solche
    /// erkannt werden, statt still zu Bruchstücken zu zerfallen.
    public static func isPlausible(_ raw: String) -> Bool {
        let value = normalized(raw)
        if value.count == 10 { return AmazonCover.isValidISBN10(value) }
        if value.count == 13 { return AmazonCover.isValidISBN13(value) }
        return false
    }
}

/// Amazons eigene Kennungen — ASIN und die URLs, in denen sie stecken.
///
/// E-Books und Selbstverlagstitel haben oft **gar keine ISBN**, nur eine ASIN. Sie ist
/// keine ISBN und darf auch nicht so behandelt werden: der Bildendpunkt kennt sie nicht
/// (gemessen 2026-08-08 an `B0GNS692YT` → 43 Byte), und kein Katalog schlägt sie nach.
/// Erkannt wird sie trotzdem — damit die App sagen kann, was los ist, statt zu raten.
public enum AmazonReference {

    /// Eine ASIN ist zehnstellig, alphanumerisch und beginnt bei Büchern mit „B".
    /// Zehnstellige reine Ziffernfolgen bleiben ausgenommen — das sind ISBN-10.
    public static func isASIN(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.count == 10, value.hasPrefix("B") else { return false }
        return value.allSatisfy { $0.isNumber || ($0.isLetter && $0.isASCII) }
    }

    /// Zieht die Kennung aus einer eingefügten Amazon-Adresse: `/dp/<kennung>` oder
    /// `/gp/product/<kennung>`. Ergebnis kann eine ASIN **oder** eine ISBN-10 sein —
    /// beim Einfügen einer Produktseite ist beides üblich.
    public static func identifier(inURL raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().contains("amazon.") else { return nil }
        let parts = text.split(whereSeparator: { $0 == "/" || $0 == "?" || $0 == "&" })
        for (index, part) in parts.enumerated() where part == "dp" || part == "product" {
            guard index + 1 < parts.count else { continue }
            let candidate = String(parts[index + 1]).uppercased()
            if candidate.count == 10, candidate.allSatisfy({ $0.isNumber || ($0.isLetter && $0.isASCII) }) {
                return candidate
            }
        }
        return nil
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
        Set(words(value).filter { $0.count > 1 })
    }

    static func words(_ value: String) -> [String] {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "de_DE"))
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
    }

    /// Sind das zwei Schreibweisen desselben Nachnamens?
    ///
    /// Kataloge transliterieren anders als der Bestand: „Chodorkow**ski**" gegen
    /// „Chodorkov**skij**". Die beiden trennen sich am neunten Zeichen, teilen davor aber
    /// acht — der **gemeinsame Anfang** trägt die Entscheidung, nicht ein fester Ausschnitt
    /// des einen Namens.
    ///
    /// Verlangt werden **sechs gemeinsame Zeichen** und dass die Namen sich in der Länge
    /// um **höchstens zwei** unterscheiden. Beides zusammen trennt die Fälle:
    ///
    /// | | gemeinsam | Längendiff | |
    /// |---|---|---|---|
    /// | Chodorkowski / Chodorkovskij | 8 | 1 | derselbe Mensch |
    /// | Dostojewski / Dostojewskij | 11 | 1 | derselbe Mensch |
    /// | Meyer / Meyerhoff | 5 | 4 | zwei Menschen |
    /// | Hillen / Hillenbrand | 6 | 5 | zwei Menschen |
    ///
    /// ⚠️ Die Grenze liegt bei slawischen Endungen: „Chodorkowski" und „Chodorkowskaja"
    /// gelten nach dieser Regel als derselbe Name, sind aber Mann und Frau. Das zu
    /// trennen bräuchte Wissen über Namensformen; solange kein gemessener Fall im Bestand
    /// darauf trifft, wiegt der gewonnene Treffer schwerer — der Titelabgleich steht
    /// ohnehin daneben und ist der stärkere Wächter.
    static func sameSurname(_ lhs: String, _ rhs: String) -> Bool {
        guard let a = words(lhs).first, let b = words(rhs).first else { return false }
        if a == b { return true }
        let shared = zip(a, b).prefix { $0 == $1 }.count
        return shared >= 6 && abs(a.count - b.count) <= 2
    }
}

/// Titel-Abgleich für Katalogtreffer. Der Autor allein belegt eine Ausgabe nicht:
/// „The Fatal Conceit" von Hayek bekam so die ISBN der deutschen Ausgabe
/// „Die verhängnisvolle Anmassung" — gleicher Verfasser, anderes Buch im Regal.
///
/// Der Katalogtitel trägt Originaltitel, Gattung und Verfasserangabe mit sich
/// („[The fix] ; Exekution : Thriller / David Baldacci"), deshalb wird nicht auf
/// Gleichheit geprüft, sondern ob der gesuchte Titel als **zusammenhängende Wortfolge**
/// darin vorkommt.
public enum TitleMatch {
    public static func matches(_ stored: String, _ candidate: String) -> Bool {
        let wanted = words(SearchTitle.simplify(stored))
        guard !wanted.isEmpty else { return false }
        return titles(in: candidate).contains { startsWith(words($0), wanted) }
    }

    /// Die Titel, die einen Datensatz wirklich benennen: der Haupttitel und der
    /// Originaltitel in eckigen Klammern (unter dem umbenannte Neuauflagen laufen).
    ///
    /// ⚠️ Ausdrücklich **nicht** der ganze Katalogtitel. Der schleppt Werbung mit:
    /// „… : Thriller. - Der neue Thriller vom Autor der SPIEGEL-Bestseller THIRTEEN und
    /// FIFTY FIFTY / Steve Cavanagh". Wer darin nach der Wortfolge sucht, hält die
    /// Komplizin für „Fifty-Fifty" — am echten Bestand passiert.
    static func titles(in raw: String) -> [String] {
        var result: [String] = []
        var rest = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
            result.append(String(rest[rest.index(after: rest.startIndex)..<close]))
            rest = String(rest[rest.index(after: close)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;·/"))
        }
        // Untertitel und Verfasserangabe abschneiden — dahinter beginnt der Ballast.
        for separator in [" : ", " / ", ". - "] {
            if let range = rest.range(of: separator) { rest = String(rest[..<range.lowerBound]) }
        }
        result.append(rest.trimmingCharacters(in: .whitespacesAndNewlines))
        return result.filter { !$0.isEmpty }
    }

    /// Bezeichnen die beiden Titel **dasselbe Werk**? Strenger als `matches`.
    ///
    /// `matches` vergleicht gegen den **vereinfachten** Titel, und der ist für die Suche
    /// gedacht, nicht für die Identität: „Steve Jobs. Der Henry Ford der Computerindustrie"
    /// schrumpft zu „Steve Jobs", und damit passt auch „Steve Jobs und die
    /// Erfolgsgeschichte von Apple" — ein anderes Buch derselben Verfasser. Genau so
    /// bekam der Eintrag am 2026-08-09 das Cover der Fischer-Ausgabe.
    ///
    /// Hier zählt deshalb der **ungekürzte** Titel des Eintrags. Der Katalogtitel darf
    /// kürzer sein (der Eintrag führt den Untertitel oft mit, der Katalog nicht) oder
    /// länger (umgekehrt) — aber einer muss den anderen von vorn decken.
    public static func sameWork(_ stored: String, _ candidate: String) -> Bool {
        let mine = words(stored)
        guard !mine.isEmpty else { return false }
        return titles(in: candidate).contains { other in
            let theirs = words(other)
            guard !theirs.isEmpty else { return false }
            return startsWith(mine, theirs) || startsWith(theirs, mine)
        }
    }

    private static func words(_ value: String) -> [String] {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "de_DE"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Der gesuchte Titel muss **vorn** stehen, nicht irgendwo vorkommen.
    private static func startsWith(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        return Array(haystack[0..<needle.count]) == needle
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
        value = withoutSubtitleAfterPeriod(value)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
    }

    /// Deutsche Bestandstitel trennen den Untertitel oft mit **Punkt**:
    /// „Mr. Diamond. Der Insider-Skandal von Wall Street". Mit dem ganzen Wortlaut findet
    /// die DNB nichts, mit dem Haupttitel einen Treffer.
    ///
    /// ⚠️ Abkürzungen dürfen dabei nicht zerschnitten werden — sonst wird aus „Mr. Diamond"
    /// das Wort „Mr". Deshalb wird nur nach einem Wort mit **mehr als zwei Buchstaben**
    /// getrennt; „Mr.", „Dr.", „St." bleiben stehen.
    private static func withoutSubtitleAfterPeriod(_ value: String) -> String {
        var index = value.startIndex
        while let dot = value[index...].range(of: ". ") {
            let word = value[..<dot.lowerBound].split(whereSeparator: { !$0.isLetter && !$0.isNumber }).last ?? ""
            if word.count > 2 { return String(value[..<dot.lowerBound]) }
            index = dot.upperBound
        }
        return value
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

    /// Suche über Titel und Person — für die ~137 Bestandsbücher, die gar keine ISBN
    /// führen. Ohne ISBN bleibt die ausgabegenaue Coverquelle (Amazon über ISBN-10)
    /// unerreichbar.
    public static func searchURL(title: String, author: String, maximumRecords: Int = 10) -> URL {
        var components = URLComponents(string: "https://services.dnb.de/sru/dnb")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.1"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            // Ohne Autor bleibt die Titelsuche allein — die Eindeutigkeitsregel in
            // `isbn(from:title:author:)` fängt ab, was dabei mehrdeutig zurückkommt.
            URLQueryItem(name: "query", value: author.isEmpty
                         ? "TIT=\(SearchTitle.simplify(title))"
                         : "TIT=\(SearchTitle.simplify(title)) and PER=\(surname(of: author))"),
            URLQueryItem(name: "recordSchema", value: "oai_dc"),
            URLQueryItem(name: "maximumRecords", value: String(maximumRecords))
        ]
        return components.url!
    }

    /// Der Katalog führt Personen als „Nachname, Vorname"; die Personensuche trifft mit
    /// dem Nachnamen zuverlässiger als mit der ganzen Zeichenkette.
    static func surname(of author: String) -> String {
        let first = author.split(separator: ";").first.map(String.init) ?? author
        if let comma = first.firstIndex(of: ",") {
            return String(first[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return first.split(separator: " ").last.map(String.init)
            ?? first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ein Datensatz der Trefferliste. Die Antwort mischt Ausgaben, Übersetzungen und
    /// Hörbücher — deshalb wird sie datensatzweise gelesen, nicht als ein Topf.
    public struct Record: Sendable, Equatable {
        public var title: String
        public var creators: [String]
        public var identifiers: [String]
        public var formats: [String] = []

        /// Tonträger tragen eine eigene ISBN und ein eigenes Cover — „Neid" von Arne Dahl
        /// bekam im ersten Lauf `Neid : 8 CDs`. Der Rollenwächter half nicht: Hörbücher
        /// führen den Autor ebenfalls als `[Verfasser]`.
        public var isPrint: Bool {
            let haystack = ([title] + formats).joined(separator: " ").lowercased()
            let audio = ["hörbuch", "hoerbuch", " cd", "cds", "mp3", "lesung", "gelesen von",
                         "tonträger", "dvd", "blu-ray", "audio"]
            return !audio.contains { haystack.contains($0) }
        }

        /// Erste gültige ISBN dieses Datensatzes. `urn:nbn:…` ist keine.
        public var isbn: String? { isbns.first }

        /// **Alle** ISBNs des Datensatzes. Ein Titel erscheint oft mehrfach — kartoniert,
        /// gebunden, als E-Book. Amazon führt sein Bild nur unter manchen davon: „In den
        /// Tod" liegt im Bestand als E-Book-ISBN `9783492990172` (43 Byte = kein Bild),
        /// dieselbe Ausgabe als Druck unter `349206115X` (43.707 Byte).
        public var isbns: [String] {
            identifiers.compactMap { Self.firstISBN(in: $0) }
        }

        /// Nur der **Verfasser** belegt die Ausgabe. Erzähler und Übersetzer nicht:
        /// sonst erbt der Roman die ISBN des Hörbuchs.
        public func hasAuthor(_ author: String) -> Bool {
            guard !author.isEmpty else { return false }
            let writers = creators.filter { $0.contains("[Verfasser") }
            guard !writers.isEmpty else { return false }
            let names = writers.map {
                $0.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
            }
            return names.contains { AuthorMatch.matches(author, $0) }
        }

        /// Wie `hasAuthor`, aber der Namensvergleich läuft über den **Wortstamm** des
        /// Nachnamens statt über ganze Wörter.
        ///
        /// Kataloge transliterieren anders als der Bestand: die App führt
        /// „Chodorkow**ski**, Michail", die DNB die Druckausgabe unter
        /// „Chodorkov**skij**, Michail Borisovič". `AuthorMatch` verlangt gleiche Wörter
        /// und verwirft damit den richtigen Datensatz — am 2026-08-09 blieb „Wie man einen
        /// Drachen tötet" deshalb ohne Cover, obwohl die DNB die Druckausgabe führte.
        ///
        /// Die Verfasserrolle bleibt Pflicht. Erzähler und Übersetzer belegen keine
        /// Ausgabe, sonst erbt der Roman das Cover des Hörbuchs.
        public func hasAuthorStem(_ author: String) -> Bool {
            guard !author.isEmpty else { return false }
            let wanted = DNB.surname(of: author)
            let writers = creators.filter { $0.contains("[Verfasser") }
            guard !writers.isEmpty else { return false }
            return writers.contains { raw in
                let name = raw.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "",
                                                    options: .regularExpression)
                return AuthorMatch.sameSurname(wanted, DNB.surname(of: name))
            }
        }

        /// Aus „978-3-442-49404-0 kart. : EUR 16.00" die Nummer holen — und die
        /// Prüfziffer rechnen, sonst landet irgendeine Artikelnummer bei Amazon.
        static func firstISBN(in raw: String) -> String? {
            let lower = raw.lowercased()
            // ⚠️ Adressen tragen die **Katalognummer** der DNB („http://d-nb.info/1264340478/34").
            // Die ist zehnstellig und mod-11-geprüft, besteht also die ISBN-10-Rechnung
            // zwangsläufig — eine gültige Prüfziffer belegt nicht, dass etwas eine ISBN ist.
            guard !lower.contains("://"), !lower.hasPrefix("urn:"), !lower.contains("d-nb.info"),
                  !lower.contains("nbn-resolving") else { return nil }
            let pattern = "97[89][- ]?(?:[0-9][- ]?){9}[0-9]|[0-9][- ]?(?:[0-9][- ]?){8}[0-9Xx]"
            guard let range = raw.range(of: pattern, options: .regularExpression) else { return nil }
            let value = ISBN.normalized(String(raw[range]))
            if value.count == 13 { return AmazonCover.isValidISBN13(value) ? value : nil }
            if value.count == 10 { return AmazonCover.isValidISBN10(value) ? value : nil }
            return nil
        }
    }

    /// Datensatzweise Sicht auf eine SRU-Antwort.
    public static func records(_ data: Data) -> [Record] {
        DublinCoreFields.records(data).map {
            // Nur, was die DNB selbst als ISBN ausweist. Ungetypte Bezeichner zählen
            // ebenfalls — andere Kataloge kennzeichnen nicht —, alles andere (dnb:IDN,
            // tel:URN …) bleibt draußen.
            Record(title: $0["title"]?.first ?? "",
                   creators: $0["creator"] ?? [],
                   identifiers: $0.filter { key, _ in
                       key == "identifier" || key.uppercased().hasSuffix("ISBN")
                   }.values.flatMap { $0 },
                   formats: $0["format"] ?? [])
        }
    }

    /// ISBN aus einer Trefferliste. Drei Wächter, jeder gegen einen echten Fehlgriff
    /// des ersten Laufs über 174 Bücher: **Verfasser** (sonst erbt der Roman die ISBN
    /// der Hörbuchbox), **Titel** (sonst bekommt „The Fatal Conceit" die ISBN der
    /// deutschen Ausgabe) und **Druckausgabe** (sonst gewinnt der Tonträger, der den
    /// Autor ebenfalls als Verfasser führt).
    public static func isbn(from data: Data, title: String, author: String) -> String? {
        matching(data, title: title, author: author).first?.isbn
    }

    /// Alle ISBNs der belegten Datensätze — Druck vor E-Book, damit die Coverquelle
    /// eine Chance hat.
    public static func isbns(from data: Data, title: String, author: String) -> [String] {
        matching(data, title: title, author: author).flatMap(\.isbns)
    }

    /// ISBNs der **Geschwisterausgaben** desselben Werks — Druck neben Hörbuch, Taschenbuch
    /// neben gebunden. Nur dafür, ein Cover zu finden.
    ///
    /// Eigene Regeln, nicht die von `isbns`, weil hier beide Wächter anders liegen müssen:
    ///
    /// - **Der Titel strenger.** Es geht um dieselbe *Sache*, nicht um einen Suchtreffer.
    ///   `sameWork` vergleicht den ungekürzten Titel; sonst zieht „Steve Jobs. Der Henry
    ///   Ford der Computerindustrie" das Cover von „Steve Jobs und die Erfolgsgeschichte
    ///   von Apple".
    /// - **Der Verfasser lockerer.** Die DNB wurde bereits mit `PER=` gefragt, hat also
    ///   selbst abgeglichen — und schreibt Namen anders als der Bestand. Ein eigener
    ///   Wortvergleich verwirft hier den richtigen Datensatz.
    ///
    /// Ohne Verfasser im Bestand gibt es keine Geschwistersuche: dann fehlt der Anker,
    /// und die Trefferliste zu „Flashback" enthält neun verschiedene Bücher.
    public static func siblingISBNs(from data: Data, title: String, author: String) -> [String] {
        guard !author.isEmpty else { return [] }
        return records(data)
            .filter { TitleMatch.sameWork(title, $0.title) && $0.isPrint && $0.hasAuthorStem(author) }
            .flatMap(\.isbns)
    }

    /// Der Verfasser, **wenn der Titel nur einen kennt**.
    ///
    /// Anders als `author(from:…)` verlangt das keinen einzelnen Datensatz: derselbe Titel
    /// erscheint als Taschenbuch, gebunden und als Lizenzausgabe, das sind drei Datensätze
    /// und trotzdem ein Verfasser. Entscheidend ist, dass alle Treffer **auf denselben
    /// Menschen zeigen** — sonst bleibt das Feld leer.
    ///
    /// Verglichen wird über `sameSurname`, damit die Schreibweisen des Katalogs
    /// („Coben, Harlan" neben „Coben, H.") nicht als zwei Personen zählen.
    /// ⚠️ Verlangt, dass die Antwort **die ganze Trefferliste** enthält. Eindeutigkeit
    /// innerhalb der ersten zehn Datensätze ist keine Eindeutigkeit: „Phantom" wurde am
    /// 2026-08-10 mit „Matsuri" belegt, weil unter den ersten zehn nur ein Manga auf den
    /// Titel passte — die DNB führt zu dem Wort **4921** Datensätze. „Falsche Schuld"
    /// bekam „Minninger" statt Patterson, bei 65 Treffern insgesamt.
    ///
    /// Wer nur einen Ausschnitt sieht, darf über Eindeutigkeit nicht urteilen.
    public static func soleAuthor(from data: Data, title: String) -> String? {
        guard let total = numberOfRecords(in: data) else { return nil }
        let all = records(data)
        guard total <= all.count else { return nil }

        // Je Datensatz zählt der **erste** Verfasser. Co-Autoren desselben Buchs sind
        // kein Widerspruch — „Operation Seewespe" führt Cussler und Morrison, und das
        // ist ein Buch, nicht zwei Meinungen darüber, wer es geschrieben hat.
        let named = all
            .filter { TitleMatch.sameWork(title, $0.title) }
            .compactMap { record -> String? in
                let writers = record.creators.filter { $0.contains("[Verfasser") }
                guard let first = writers.first else { return nil }
                return first.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "",
                                                  options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        guard let candidate = named.first, !candidate.isEmpty else { return nil }
        guard named.allSatisfy({ AuthorMatch.sameSurname(surname(of: candidate), surname(of: $0)) })
        else { return nil }
        return candidate
    }

    /// Wie viele Treffer hat die Suche insgesamt — unabhängig davon, wie viele Datensätze
    /// die Antwort mitschickt.
    public static func numberOfRecords(in data: Data) -> Int? {
        guard let text = String(data: data, encoding: .utf8),
              let range = text.range(of: "numberOfRecords>[0-9]+", options: .regularExpression)
        else { return nil }
        return Int(text[range].split(separator: ">")[1])
    }

    /// Der Verfasser des belegten Datensatzes. Für Bestandsbücher, die selbst keinen führen.
    public static func author(from data: Data, title: String, author: String) -> String? {
        matching(data, title: title, author: author).first
            .map { Self.author(from: $0.creators) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Datensätze, die als Beleg taugen: passender Titel, Druckausgabe, mit ISBN — und
    /// passender Verfasser, **sofern das Buch einen führt**.
    ///
    /// ⚠️ Ohne Autor entfällt der stärkste Wächter. Dann zählt der Beleg nur, wenn die
    /// Trefferliste **eindeutig** ist: ein Titel, ein Datensatz. „Das Poseidon-Komplott"
    /// führt im Bestand keinen Autor und ist über den Titel allein eindeutig belegt —
    /// bei mehreren Treffern bliebe es lieber ohne ISBN als mit der falschen.
    private static func matching(_ data: Data, title: String, author: String) -> [Record] {
        let usable = records(data).filter {
            TitleMatch.matches(title, $0.title) && $0.isPrint && !$0.isbns.isEmpty
        }
        guard !author.isEmpty else { return usable.count == 1 ? usable : [] }
        return usable.filter { $0.hasAuthor(author) }
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
    private static let wanted: Set<String> = ["title", "creator", "date", "format", "identifier"]

    static func parse(_ data: Data) -> [String: [String]] {
        let collector = Collector(wanted: wanted)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = collector
        parser.parse()
        return collector.fields
    }

    /// Dieselbe Antwort, aber je `<record>` getrennt. Nötig, sobald aus einer
    /// Trefferliste **ein** Datensatz ausgewählt werden muss: die flache Sicht
    /// verschmilzt Roman, Übersetzung und Hörbuch zu einem Eintrag.
    static func records(_ data: Data) -> [[String: [String]]] {
        let collector = Collector(wanted: wanted, splitOn: "record")
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = collector
        parser.parse()
        collector.closeRecord()
        return collector.records
    }

    private final class Collector: NSObject, XMLParserDelegate {
        private let wanted: Set<String>
        private let splitOn: String?
        private var current: String?
        private var buffer = ""
        var fields: [String: [String]] = [:]
        var records: [[String: [String]]] = []

        init(wanted: Set<String>, splitOn: String? = nil) {
            self.wanted = wanted
            self.splitOn = splitOn
        }

        /// Letzten Datensatz übernehmen — er wird nicht von einem Folgeelement beendet.
        func closeRecord() {
            guard splitOn != nil, !fields.isEmpty else { return }
            records.append(fields)
            fields = [:]
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            if let splitOn, name == splitOn { closeRecord() }
            current = wanted.contains(name) ? name : nil
            // Die DNB kennzeichnet Bezeichner per Attribut: `tel:ISBN` gegen `dnb:IDN`.
            // Ohne den Typ ist eine nackte Katalognummer von einer nackten ISBN nicht
            // zu unterscheiden — und Katalognummern bestehen die ISBN-10-Prüfziffer.
            if current == "identifier" {
                let type = attributes["xsi:type"] ?? attributes["type"] ?? ""
                current = type.isEmpty ? "identifier" : "identifier:\(type)"
            }
            buffer = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard current != nil else { return }
            buffer += string
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                    qualifiedName: String?) {
            // `current` trägt beim Bezeichner den Typ mit („identifier:tel:ISBN"),
            // deshalb der Vergleich auf den Elementnamen davor.
            guard let key = current, key == name || key.hasPrefix("\(name):") else { return }
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
        // Die gespeicherte ISBN bezeichnet **eine Ausgabe**, das Cover hängt aber am Werk.
        // Ist die gespeicherte das E-Book oder das Hörbuch, führt Amazon unter ihr kein
        // Bild — die Druckausgabe hat eine eigene ISBN, und die trifft. Belegt an
        // „In den Tod" (Grimm): gespeichert `9783492990172` = 43 Byte, Druck `349206115X`
        // = 43.707 Byte. Und an „Wie man einen Drachen tötet": gespeichert war die
        // Hörbuchfassung `9783863526191` = 43 Byte, die Druckausgabe `3958905730` liefert
        // 22.606 Byte. Die beiden DNB-Datensätze sind untereinander **nicht** verknüpft;
        // nur die Suche über Titel und Verfasser findet die Geschwisterausgabe.
        if let siblings = try? await siblingISBNs(title: title, author: author) {
            for candidate in siblings where ISBN.canonical(candidate) != ISBN.canonical(isbn) {
                if let amazon = AmazonCover.url(isbn: candidate), let cover = await usableCover(amazon) {
                    return cover
                }
            }
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
    /// ISBN für ein Buch, das keine führt — über Titel und Verfasser bei der DNB.
    /// Nur die DNB: Google Books liegt regelmäßig an der Tagesquote, und Open Library
    /// kennt die deutschen Ausgaben schlecht.
    /// ⚠️ Der Autor darf fehlen. Bücher ohne Autor sind sonst für immer ausgeschlossen —
    /// „Das Poseidon-Komplott" führt im Bestand keinen und ist über den Titel allein
    /// eindeutig belegt. Die Eindeutigkeitsregel steckt in `DNB.isbn`.
    public func isbn(title: String, author: String) async throws -> String? {
        guard let data = try await searchRecords(title: title, author: author) else { return nil }
        return DNB.isbn(from: data, title: title, author: author)
    }

    /// Der Verfasser, wenn der Titel im Katalog nur einen kennt — sonst `nil`.
    ///
    /// Holt bewusst **100** Datensätze statt der üblichen zehn: die Regel verlangt die
    /// vollständige Trefferliste, und bei zehn wäre fast jeder Titel abgeschnitten.
    public func soleAuthor(title: String) async throws -> String? {
        let query = SearchTitle.simplify(title)
        guard !query.isEmpty else { return nil }
        let (data, status) = try await client.get(DNB.searchURL(title: query, author: "",
                                                                maximumRecords: 100))
        guard status == 200 else { return nil }
        return DNB.soleAuthor(from: data, title: title)
    }

    /// Verfasser aus dem belegten Datensatz — füllt die Lücke bei Büchern ohne Autor.
    public func author(title: String, author: String) async throws -> String? {
        guard let data = try await searchRecords(title: title, author: author) else { return nil }
        return DNB.author(from: data, title: title, author: author)
    }

    /// Weitere ISBNs derselben Ausgabe, etwa die Druckfassung neben dem E-Book.
    public func alternativeISBNs(title: String, author: String) async throws -> [String] {
        guard let data = try await searchRecords(title: title, author: author) else { return [] }
        return DNB.isbns(from: data, title: title, author: author)
    }

    /// ISBNs der Geschwisterausgaben desselben Werks — die Stufe, die den Fall
    /// „gespeichert ist das Hörbuch, das Cover hängt an der Druckausgabe" löst.
    public func siblingISBNs(title: String, author: String) async throws -> [String] {
        guard let data = try await searchRecords(title: title, author: author) else { return [] }
        return DNB.siblingISBNs(from: data, title: title, author: author)
    }

    private func searchRecords(title: String, author: String) async throws -> Data? {
        guard !title.isEmpty else { return nil }
        let (data, status) = try await client.get(DNB.searchURL(title: title, author: author))
        return status == 200 ? data : nil
    }

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
