import Foundation

/// Prüft, ob ein gescannter Strichcode ein Buch bezeichnet.
///
/// Bücher tragen EAN-13 mit dem Bookland-Präfix 978 oder 979 — die ISBN-13 selbst.
/// Jede andere Ware trägt ebenfalls EAN-13, deshalb reicht „13 Ziffern" nicht:
/// ohne Präfix- und Prüfziffernkontrolle landet die Müslipackung als Buch im Regal.
public enum ScannedCode {

    /// - Returns: die ISBN, oder `nil`, wenn der Code kein Buch bezeichnet.
    public static func isbn(from raw: String) -> String? {
        let direct = ISBN.normalized(raw)
        if let isbn = validated(direct) { return isbn }

        // QR-Codes tragen oft eine Adresse oder „ISBN 978-…" — die Ziffernfolge
        // daraus lesen, aber nur, wenn sie für sich genommen gültig ist.
        for candidate in digitRuns(in: raw) {
            if let isbn = validated(candidate) { return isbn }
        }
        return nil
    }

    private static func validated(_ value: String) -> String? {
        if value.count == 13 {
            guard value.hasPrefix("978") || value.hasPrefix("979") else { return nil }
            return AmazonCover.isValidISBN13(value) ? value : nil
        }
        if value.count == 10 {
            return AmazonCover.isValidISBN10(value) ? value : nil
        }
        return nil
    }

    /// Ziffernfolgen aus einem Text — Trennzeichen innerhalb einer ISBN bleiben erhalten.
    private static func digitRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in text {
            if character.isNumber || character == "X" || character == "-" {
                current.append(character)
            } else {
                runs.append(current)
                current = ""
            }
        }
        runs.append(current)
        return runs.map(ISBN.normalized).filter { !$0.isEmpty }
    }
}
