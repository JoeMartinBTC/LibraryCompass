import Foundation

/// Die Adresse, unter der ein Mensch das Cover findet, das die App nicht holen darf.
///
/// `amazon.de/robots.txt` schließt automatisierte Zugriffe aus und nennt Claude-Agenten
/// namentlich. Für die ~96 Bücher ohne freie Bildquelle — alte deutsche Ausgaben und
/// Selbstverlagstitel ohne ISBN-10 — bleibt deshalb nur der Weg über den Nutzer: die App
/// baut die Suche zusammen und öffnet sie in seinem Browser. Er sucht, er sieht, er
/// entscheidet. Das ist kein Umweg um die Regel, sondern die Rollenverteilung, die sie
/// vorsieht.
public enum CoverSearch {

    /// Titel und Verfasser als Suchanfrage. `nil`, wenn beides leer ist.
    public static func url(title: String, author: String) -> URL? {
        let terms = [title, author]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !terms.isEmpty else { return nil }

        var components = URLComponents(string: "https://www.amazon.de/s")!
        components.queryItems = [
            URLQueryItem(name: "k", value: terms),
            // Auf Bücher eingrenzen: „Der Rächer" führt sonst zu Hörspielen und Filmen,
            // und der Nutzer sucht das Buch, das bei ihm im Regal steht.
            URLQueryItem(name: "i", value: "stripbooks")
        ]
        return components.url
    }
}
