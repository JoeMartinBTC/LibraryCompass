import Foundation

/// Ein **Werk** eines Verfassers, wie es der Katalog kennt — nicht eine Ausgabe.
///
/// Der Katalog führt dasselbe Buch als gebunden, kartoniert, Lizenzausgabe und E-Book.
/// Für die Frage „habe ich das?" ist das ein Eintrag, nicht vier.
public struct BibliographyWork: Sendable, Equatable, Hashable {
    public var title: String
    public var author: String
    public var isbn: String
    public var year: Int?
    /// Alle Titel, unter denen der Katalog dieses Werk führt — Haupttitel und der
    /// Originaltitel in eckigen Klammern. Der Bestand führt oft den anderen.
    public var variants: [String]

    public init(title: String, author: String, isbn: String, year: Int? = nil,
                variants: [String] = []) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.year = year
        self.variants = variants.isEmpty ? [title] : variants
    }
}

/// Ergebnis eines Bibliografie-Laufs — samt der Frage, ob er den Katalog zu Ende gelesen hat.
public struct BibliographyResult: Sendable, Equatable {
    public var works: [BibliographyWork]
    /// Wie viele Datensätze tatsächlich geholt wurden.
    public var seen: Int
    /// Wie viele die DNB insgesamt führt.
    public var total: Int

    public init(works: [BibliographyWork], seen: Int, total: Int) {
        self.works = works
        self.seen = seen
        self.total = total
    }

    /// Eine gekürzte Liste darf sich nicht als ganze ausgeben.
    public var isComplete: Bool { seen >= total }
}

/// Die Werkliste eines Verfassers und ihr Abgleich mit dem Bestand.
///
/// Reine Rechnung ohne Netz und ohne Store — die Datensätze kommen von
/// `MetadataLookup.bibliography(author:)`, die Lücken wandern in `MissingBook`.
public enum AuthorBibliography {

    /// Nur deutschsprachige Ausgaben. Der Lauf vom 2026-08-10 gegen die echte Antwort zu
    /// „Frank Schätzing" zeigte, warum: unter den 21 Werken standen „The swarm : a novel",
    /// „Death and the devil", „L' essaim", „Ölüm ve şeytan" und „Qiao wu sheng xi" — fünf
    /// Übersetzungen von Büchern, die auf Deutsch bereits in der Liste standen. Eine
    /// Lücke im Regal ist die deutsche Ausgabe, nicht ihre türkische Fassung.
    ///
    /// Ein Datensatz **ohne** Sprachangabe fällt mit heraus: genau die fremdsprachigen
    /// Ausgaben führen keine (nachgesehen an denselben fünf), deutsche fast immer.
    static let acceptedLanguages: Set<String> = ["ger", "deu"]

    /// Aus einer Trefferliste die Werke des gesuchten Verfassers.
    ///
    /// Vier Wächter, jeder gegen einen Datensatz, der in der Probe vom 2026-08-10 in der
    /// Antwort zu „Frank Schätzing" stand:
    ///
    /// - **Verfasserrolle.** „Die Juden von Cölln" ist von Wilhelm Jensen; Schätzing hat
    ///   das Vorwort geschrieben und steht als `[Mitwirkender]` darin. Ein Vorwort ist
    ///   nicht sein Werk.
    /// - **Erzähler.** „Tod und Teufel / Frank Schätzing", der Hörverlag 2016 — im Titel
    ///   steht kein Wort davon, dass es eine Lesung ist. Im Datensatz steht
    ///   „Kaminski, Stefan [Erzähler]".
    /// - **Sprache.** „[Breaking News] ; Bleskové správy" ist die slowakische Ausgabe.
    /// - **ISBN.** Ohne sie gibt es weder ein Cover noch etwas zu bestellen; die Antwort
    ///   enthält auch Aufsätze und Teilbände („Part two") ohne jede Nummer.
    public static func works(in records: [DNB.Record], author: String) -> [BibliographyWork] {
        var groups: [BibliographyWork] = []
        /// Schlüssel eines Titels → Gruppe, in der er schon steckt.
        var index: [String: Int] = [:]

        for record in records {
            guard isByAuthor(record, author),
                  !record.hasNarrator,
                  record.isPrint,
                  !record.isOnlineOnly,
                  !record.isbns.isEmpty,
                  speaksOurLanguage(record) else { continue }

            let title = DNB.title(from: record.title)
            let variants = titleVariants(record.title, author: author)
            let keys = variants.compactMap(workKey)
            guard !title.isEmpty, !keys.isEmpty else { continue }

            let candidate = BibliographyWork(title: title,
                                             author: author,
                                             isbn: record.isbns[0],
                                             year: record.year,
                                             variants: variants)

            // Ein Werk wird über **jeden** seiner Titel wiedererkannt. „Mordshunger" und
            // „Mordshunger : [mit einem Lieblingsrezept …]" sind ein Buch, und die
            // Neuauflage unter dem Originaltitel in eckigen Klammern ebenfalls.
            guard let slot = keys.compactMap({ index[$0] }).first else {
                groups.append(candidate)
                for key in keys { index[key] = groups.count - 1 }
                continue
            }
            for key in keys where index[key] == nil { index[key] = slot }
            groups[slot].variants = Array(Set(groups[slot].variants + variants)).sorted()
            // Von zwei Ausgaben desselben Werks gewinnt die **ältere**: sie trägt den
            // Titel, unter dem das Buch erschienen ist, nicht den der Neuvermarktung.
            // Ohne Jahr verliert ein Datensatz gegen jeden, der eines führt.
            if let year = candidate.year, groups[slot].year.map({ year < $0 }) ?? true {
                groups[slot].title = candidate.title
                groups[slot].isbn = candidate.isbn
                groups[slot].year = year
            }
        }

        return groups.sorted { a, b in
            let ya = a.year ?? Int.max, yb = b.year ?? Int.max
            if ya != yb { return ya < yb }
            return BookQuery.compare(a.title, b.title) == .orderedAscending
        }
    }

    /// Die Werke, die im Bestand fehlen.
    ///
    /// Verglichen wird gegen **alle** Bücher desselben Verfassers, nicht gegen den ganzen
    /// Bestand: sonst löscht ein gleichnamiger Titel eines anderen Autors eine echte Lücke.
    ///
    /// Zwei Wege, ein Werk als vorhanden zu erkennen — die ISBN und der Titel. Die ISBN
    /// allein genügt nicht: im Regal steht das Taschenbuch, der Katalog nennt die
    /// gebundene Ausgabe, und beide tragen verschiedene Nummern. Deshalb entscheidet
    /// `TitleMatch.sameWork`, und die ISBN ist nur die Abkürzung für den klaren Fall.
    public static func gaps<B: BookFields>(works: [BibliographyWork],
                                           owned books: [B],
                                           author: String) -> [BibliographyWork] {
        let mine = books.filter { sameAuthor(author, $0.author) }
        let ownedISBNs = Set(mine.map { ISBN.canonical($0.isbn) }.filter { !$0.isEmpty })

        return works.filter { work in
            if ownedISBNs.contains(ISBN.canonical(work.isbn)) { return false }
            // Gegen **jeden** Titel des Werks: der Bestand führt „Der Junge aus dem Wald",
            // der Katalog denselben Band unter „[The boy from the woods]".
            return !mine.contains { book in
                work.variants.contains { TitleMatch.sameWork(book.title, $0) }
            }
        }
    }

    /// Zwei Schreibweisen desselben Menschen? Vergleicht **jedes Wort gegen jedes**.
    ///
    /// Nicht über `DNB.surname(of:)`, und das ist der Punkt: der nimmt ohne Komma das
    /// **letzte** Wort als Nachnamen. Der Bestand führt aber „Coben  Harlan" — umgekehrte
    /// Reihenfolge, Komma fehlt, zwei Leerzeichen. Daraus wurde der Nachname „Harlan", das
    /// Buch zählte nicht als eines von Coben, und „Ich finde dich" stand als Lücke im Korb,
    /// obwohl es gelesen im Regal steht (gemeldet 2026-08-10, am echten Store belegt).
    ///
    /// Katalogfelder sind von Hand gefüllt. Ein Abgleich, der auf eine bestimmte
    /// Schreibweise angewiesen ist, bricht am ersten Tippfehler.
    static func sameAuthor(_ lhs: String, _ rhs: String) -> Bool {
        let a = AuthorMatch.words(lhs).filter { $0.count > 2 }
        let b = AuthorMatch.words(rhs).filter { $0.count > 2 }
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.contains { left in b.contains { AuthorMatch.sameSurname(left, $0) } }
    }

    /// Hat **dieser Mensch** den Datensatz geschrieben? Die Verfasserrolle bleibt Pflicht —
    /// Übersetzer, Erzähler und Vorwortschreiber belegen kein eigenes Werk.
    static func isByAuthor(_ record: DNB.Record, _ author: String) -> Bool {
        let writers = record.creators.filter { $0.contains("[Verfasser") }
        guard !writers.isEmpty else { return false }
        return writers.contains { raw in
            sameAuthor(author, raw.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "",
                                                        options: .regularExpression))
        }
    }

    /// Der Datensatz nennt eine Sprache, die hier gelesen wird.
    private static func speaksOurLanguage(_ record: DNB.Record) -> Bool {
        record.languages.contains { acceptedLanguages.contains($0.lowercased()) }
    }

    /// Die Titel, unter denen ein Datensatz sein Werk führt — Haupttitel und der
    /// Originaltitel in eckigen Klammern.
    ///
    /// ⚠️ In der eckigen Klammer steht nicht immer ein Titel. Die DNB führt neuere
    /// Ausgaben unter dem **Namen des Verfassers** als Reihe: „[Schätzing] ; Helden :
    /// Roman". Wer das als Titel nimmt, hält „Helden", „Die Tyrannei des Schmetterlings"
    /// und „Was, wenn wir einfach die Welt retten?" für ein einziges Werk — am
    /// 2026-08-10 an der echten Antwort gesehen: aus 13 Werken wurden 10.
    static func titleVariants(_ raw: String, author: String) -> [String] {
        let titles = TitleMatch.titles(in: raw).map { DNB.title(from: $0) }.filter { !$0.isEmpty }
        let real = titles.filter { !sameAuthor(author, $0) }
        // Bleibt nichts übrig, war der Haupttitel gemeint — er steht immer an letzter Stelle.
        return Array(Set(real.isEmpty ? Array(titles.suffix(1)) : real)).sorted()
    }

    /// Titel auf seine Wortfolge reduziert — „Mordshunger : [mit einem Lieblingsrezept]"
    /// und „Mordshunger" sind ein Werk und dürfen nicht zweimal in der Liste stehen.
    static func workKey(_ title: String) -> String? {
        let words = SearchTitle.simplify(title)
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "de_DE"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
        return words.isEmpty ? nil : words
    }
}
