import Foundation
import SwiftData
import LibraryCompassCore

/// Der Bestand, den die Schnappschüsse zeigen — echte Bücher, keine Person dahinter.
///
/// Die Produktseite soll eine gewachsene Bibliothek zeigen und nicht acht erfundene
/// Titel; deshalb stehen hier echte Ausgaben mit ihren echten Covern. Was **fehlt**, ist
/// Absicht: keine Bewertung, kein Kommentar, kein Lesedatum. Bis 2026-08-10 zeigten die
/// Bilder auf librarycompass.com den realen Bestand samt Sternen, Lesedaten bis 2005 und
/// einem Kommentar im Klartext — ein Leseprofil, das dort nichts zu suchen hat.
///
/// Die Grenze ist dieselbe wie für Commit-Nachrichten: **welches Buch ja, was jemand
/// darüber denkt nein.**
///
/// Die Titel stehen fest im Code. Der echte SwiftData-Store wird im Schnappschuss-Modus
/// **nie** geöffnet — es gibt bewusst keinen Schalter, der das aufhebt.
enum ShowcaseLibrary {

    /// ISBN, Titel, Verfasser, Cover-Datei, Jahr, Seiten.
    static let books: [(String, String, String, String, Int?, Int?)] = [
        ("3492241468", "Als Hitler die Atombombe baute", "Friedemann Bedürftig", "3492241468.jpg", 2004, 267),
        ("9783499274145", "Berliner Blau", "Kerr, Philip", "9783499274145.jpg", nil, 632),
        ("3492300936", "Biest", "Jenk Saborowski", "3492300936.jpg", 2012, 432),
        ("3442384079", "Blinder Feind", "Jeffery Deaver", "3442384079.jpg", 2015, 384),
        ("3775003568", "Das goldene Buch vom Olivenöl", "Erica Bänziger", "3775003568.jpg", 2005, nil),
        ("9783894251956", "Das Recht des Geldes", "Dahlmann, Olaf R.", "9783894251956.jpg", 2016, nil),
        ("9783644557116", "Das Signal", "Lee, Patrick", "9783644557116.jpg", 2016, nil),
        ("3431039006", "Der Jesus-Deal", "Andreas Eschbach", "3431039006.jpg", 2014, 736),
        ("3924077002", "Der Körper lügt nicht", "John Diamond", "3924077002.jpg", 2001, nil),
        ("9783453433670", "Der Mandant", "Michael Connelly", "9783453433670.jpg", 2009, nil),
        ("3895680214", "Der Photonenring", "Virginia Essene Sheldon Nidle", "3895680214.jpg", 1996, 360),
        ("9798390245026", "Der Sandmann", "Dawson, Mark", "9798390245026.jpg", 2023, 408),
        ("3629016596", "Die Entdeckung des heiligen Grals", "Michael Hesemann", "3629016596.jpg", 2003, nil),
        ("3898430502", "Die Gesetze der Gewinner", "Bodo Schäfer", "3898430502.jpg", 2001, nil),
        ("3453437039", "Die letzte Minute", "Jeff Abbott", "3453437039.jpg", 2013, 576),
        ("3720510271", "Die Macht Ihres Unterbewußtseins", "Joseph Murphy", "3720510271.jpg", 2002, nil),
        ("345343627X", "Die Matlock-Affäre", "Robert Ludlum", "345343627X.jpg", 2012, nil),
        ("3499616270", "Die molekulare Manufaktur", "Damien Broderick", "3499616270.jpg", 2004, 480),
        ("3453439082", "Die Nano-Invasion", "Ludlum, Robert", "3453439082.jpg", nil, nil),
        ("3426636727", "Die Schatten: Die Chroniken der Templer", "Joseph Nassise", "3426636727.jpg", 2008, 304),
        ("3453436849", "Die Scorpio-Illusion", "Robert Ludlum", "3453436849.jpg", 2012, nil),
        ("3426773724", "Diener vieler Herren", "Hans H. von Arnim", "3426773724.jpg", 1998, nil),
        ("3404168429", "Doppelspiel", "David Baldacci", "3404168429.jpg", 2013, 528),
        ("344220433X", "Faceless: Der Tod hat kein Gesicht", "Terry Hayes", "344220433X.jpg", 2014, 800),
        ("9783518474198", "Fünf Winter", "James Kestrel", "9783518474198.jpg", 2024, 498),
        ("3426277778", "Größer als das Amt", "Comey, James B.", "3426277778.jpg", nil, nil),
        ("3453059484", "Handbuch Börse", "Rainer F. Schätzle", "3453059484.jpg", 1992, nil),
        ("3548283888", "Headhunter", "Jo Nesbø", "3548283888.jpg", 2011, 320),
        ("3898972518", "Jagdfieber", "Kay Hooper Marion Balkenhol", "3898972518.jpg", 2005, 367),
        ("3492060676", "Karges Land", "Erik Storey", "3492060676.jpg", 2017, nil),
        ("343016172X", "Lebe deine Stärken!", "Jörg Löhr Ulrich Pramann", "343016172X.jpg", 2004, 220),
        ("3423301317", "Lebendiges Mittelalter", "Brigitte Hellmann", "3423301317.jpg", 1995, 314),
        ("3897490595", "Luckfactor", "Brian Tracy", "3897490595.jpg", 2000, nil),
        ("3873873788", "Metaphern, Die Zauberkraft des NLP", "Franz-Josef Hücker", "3873873788.jpg", 1998, nil),
        ("340431980X", "Mir gehört New York", "Jerry Cotton", "340431980X.jpg", 2009, 464),
        ("3548286895", "Operation Elite", "Reilly, Matthew", "3548286895.jpg", nil, nil),
        ("3404243439", "Perfect Copy - Die zweite Schöpfung", "Andreas Eschbach", "3404243439.jpg", 2005, 220),
        ("3103974825", "Permanent Record: Meine Geschichte", "Edward Snowden", "3103974825.jpg", 2019, nil),
        ("3866473621", "Philosophie des Geldes", "Georg Simmel", "3866473621.jpg", 2009, nil),
        ("1572483296", "Protect Your Patent (Protect Your Patent)", "James L. Rogers", "1572483296.jpg", 2003, 240),
        ("362900637X", "Scientology: Ich klage an", "Renate Hartwig", "362900637X.jpg", 1994, 288),
        ("0764551949", "Spanish for Dummies", "Jean Antonin Billard", "0764551949.jpg", 1999, 432),
        ("3404175557", "Spectrum", "Ethan Cross", "3404175557.jpg", 2017, nil),
        ("1455550620", "The Black Ice", "Michael Connelly", "1455550620.jpg", 2013, 464),
        ("0062320238", "The Black Widow", "Daniel Silva", "0062320238.jpg", 2017, 592),
        ("0099553279", "The Fear Index", "Robert Harris", "0099553279.jpg", 2012, 400),
        ("1582701709", "The Secret", "Rhonda Byrne", "1582701709.jpg", 2006, 198),
        ("3733802144", "Verschlußsache BND", "Udo Ulfkotte", "3733802144.jpg", 2002, 367),
        ("3426770970", "Verschlußsache Jesus", "Michael Baigent Richard Leigh", "3426770970.jpg", 1993, nil),
        ("3873870940", "Virginia Satir, Muster ihres Zaubers", "Steve Andreas", "3873870940.jpg", 1994, nil),
        ("3784429238", "Wege zum Heiligen Gral", "Monika Hauf", "3784429238.jpg", 2003, 256),
        ("0061709719", "What Would Google Do?", "Jeff Jarvis", "0061709719.jpg", 2009, 272),
        ("3442357152", "Zeit der Rache. Ein Jack- Reacher- Roman.", "Lee Child", "3442357152.jpg", 2002, 512),
        ("9783596701391", "Zorn - Blut und Strafe", "Ludwig, Stephan", "9783596701391.jpg", nil, 433),
    ]

    /// Legt den Bestand in einen leeren Store.
    ///
    /// **Kommentare bleiben leer.** Ein erfundener Kommentar auf einer Produktseite sähe
    /// aus wie ein echter, und das Feld zeigt seinen Zweck auch mit dem Platzhaltertext.
    ///
    /// Bewertung und Lesedatum sind dagegen gesetzt — **berechnet, nicht übernommen**.
    /// Ohne sie zeigt die Seite eine ungenutzte App: 0 % gelesen, keine Sterne, leere
    /// Spalten, und damit nicht das, wofür es das Programm gibt. Die Werte stammen aus
    /// dem Index, hängen an keinem Menschen und lassen sich aus den Bildern auf niemanden
    /// zurückrechnen.
    static func fill(_ context: ModelContext) {
        let start = Date(timeIntervalSince1970: 1_735_000_000)
        for (index, entry) in books.enumerated() {
            let (isbn, title, author, cover, year, pages) = entry
            // Neun von zehn gelesen — eine gewachsene Bibliothek sieht so aus.
            let read = index % 10 != 7
            let book = Book(isbn: isbn, title: title, author: author, coverPath: cover,
                            rating: read ? 3 + (index * 7) % 3 : 0,
                            readDate: read ? start.addingTimeInterval(-Double(index) * 611_000) : nil,
                            addedDate: start.addingTimeInterval(-Double(index) * 43_200),
                            year: year, pages: pages)
            context.insert(book)
        }
        try? context.save()
    }
}
