import Foundation

/// Dateistamm eines Covers im Cache — pro Buch eindeutig.
///
/// Bücher mit ISBN werden nach ihrer ISBN abgelegt: der Name ist damit sprechend, und ein
/// zweiter Lauf trifft dieselbe Datei. Für die ~235 Bestandsbücher ohne ISBN gibt es keinen
/// natürlichen Schlüssel; sie bekommen einen **stabilen Hash** aus Titel und Autor.
///
/// Warum Hash und nicht `UUID()`: der Nachlauf läuft wiederholt über denselben Bestand.
/// Eine zufällige Kennung legt bei jedem Lauf eine neue Datei an und lässt die alte als
/// Karteileiche zurück.
public enum CoverKey {

    /// `nil`, wenn ein Buch weder ISBN noch Titel führt — dann gibt es nichts abzulegen.
    public static func stem(isbn: String, title: String, author: String) -> String? {
        let normalizedISBN = ISBN.normalized(isbn)
        if !normalizedISBN.isEmpty { return normalizedISBN }

        let basis = fold(title) + "|" + fold(author)
        guard basis != "|" else { return nil }
        return "t-" + String(fnv1a(basis), radix: 16)
    }

    /// Welches **Buch** ist gemeint — unabhängig davon, wie seine ISBN geschrieben steht.
    ///
    /// Der Dateistamm folgt der Schreibweise des Eintrags, damit bestehende Cover ihren
    /// Namen behalten. Für die Frage „gehört dieses Bild schon jemand anderem?" ist das
    /// aber die falsche Größe: „Cobra" von Forsyth steht zweimal im Bestand, einmal als
    /// `344247776X` und einmal als `9783442477760` — **dieselbe Ausgabe**. Beide dürfen
    /// dasselbe Bild tragen, zwei *verschiedene* Bücher nicht.
    public static func identity(isbn: String, title: String, author: String) -> String? {
        let normalized = ISBN.normalized(isbn)
        if !normalized.isEmpty { return ISBN.canonical(normalized) }
        return stem(isbn: isbn, title: title, author: author)
    }

    /// Kleinschreibung ohne Akzente und Satzzeichen, damit „Die Chefs." und „Die Chefs"
    /// dieselbe Datei treffen.
    private static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "de_DE"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    /// FNV-1a, 64 Bit. Bewusst selbst gerechnet: Swifts `hashValue` ist pro Prozess neu
    /// gesalzen und taugt deshalb nicht als Dateiname.
    private static func fnv1a(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(value.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
