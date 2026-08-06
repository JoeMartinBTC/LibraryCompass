import Foundation

/// Macht aus einem Katalogtitel den Titel, der auf dem Buch steht.
///
/// Katalogdaten schleppen dreierlei mit: die Ausgabevariante in eckigen Klammern
/// (`[Upgrade] ; Upgrade: Roman`), die Verfasserangabe hinter dem Schrägstrich
/// (`Toxin : Thriller / Kathrin Lange`) und Gattungszusätze (`Wer Lügen sät: Thriller`).
/// Echte Untertitel bleiben stehen — sie gehören zum Werk.
public enum TitleCleanup {

    /// Zusätze, die nichts über das Buch sagen. Ein Untertitel fällt nur weg,
    /// wenn er **ganz** aus solchen Wörtern besteht.
    private static let genreWords: Set<String> = [
        "roman", "thriller", "krimi", "kriminalroman", "psychothriller", "justizthriller",
        "novelle", "erzählung", "erzählungen", "geschichten", "kurzgeschichten",
        "sachbuch", "ratgeber", "biographie", "biografie", "autobiographie", "autobiografie",
        "historischer", "historische", "science", "fiction", "fantasy", "sciencefiction",
        "gedichte", "lyrik", "essays", "reportage", "memoir", "novel", "stories",
        "ein", "eine", "der", "die", "das", "und"
    ]

    public static func clean(_ raw: String) -> String {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return "" }

        var value = original

        // 1. Ausgabevariante in eckigen Klammern: der Teil dahinter zählt.
        if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
            let after = value[value.index(after: close)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;·/"))
            if !after.isEmpty { value = after }
            else { value = String(value[value.index(after: value.startIndex)..<close]) }
        }

        // 2. Weitere Fassungen hinter dem Semikolon — die erste genügt.
        if let semicolon = value.range(of: " ; ") {
            value = String(value[..<semicolon.lowerBound])
        }

        // 3. Verfasserangabe hinter dem Schrägstrich.
        if let slash = value.range(of: " / ") {
            value = String(value[..<slash.lowerBound])
        }

        // 4. Gattungszusätze am Ende — aber nur reine Gattungsangaben.
        value = withoutGenreTail(value)

        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? original : cleaned
    }

    /// Schneidet vom letzten Trenner her alles ab, was nur Gattung benennt.
    /// „Wer Lügen sät: Thriller" → „Wer Lügen sät", aber
    /// „Sapiens: Eine kurze Geschichte der Menschheit" bleibt.
    private static func withoutGenreTail(_ value: String) -> String {
        var result = value
        var changed = true
        while changed {
            changed = false
            for separator in [":", " - ", " – "] {
                // Mehrere Gedankenstriche heißen Aufzählung, nicht Gattung:
                // „Wäller Weihnacht. Gedichte - Brauchtum - Geschichten" bleibt ganz.
                if separator != ":", result.components(separatedBy: separator).count > 2 { continue }
                guard let range = result.range(of: separator, options: .backwards) else { continue }
                let tail = result[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                let head = String(result[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !head.isEmpty, !tail.isEmpty, isOnlyGenre(tail) || isCatalogTail(tail) else { continue }
                result = head
                changed = true
                break
            }
        }
        return result
    }

    /// Kataloge kürzen lange Titelfassungen mit Auslassungspunkten ab — was so
    /// endet, ist Klappentext („… sie tötet deinen schlimmsten Feind ..."),
    /// nicht der Titel.
    private static func isCatalogTail(_ text: String) -> Bool {
        text.hasSuffix("...") || text.hasSuffix("…")
    }

    private static func isOnlyGenre(_ text: String) -> Bool {
        let words = text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        guard !words.isEmpty, words.count <= 3 else { return false }

        let folded = genreWords.map { $0.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE")) }
        return words.allSatisfy { folded.contains($0) }
    }
}
