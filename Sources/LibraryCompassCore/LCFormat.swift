import Foundation

/// Alle sichtbaren Zahlen und Daten in `de-DE` (TOKENS.md §3).
public enum LCFormat {
    private static let german = Locale(identifier: "de_DE")

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = german
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = german
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    private static let dayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = german
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    public static func number(_ value: Int) -> String {
        grouped.string(from: NSNumber(value: value)) ?? String(value)
    }

    public static func average(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// `dd.MM.yyyy`, ohne Datum ein Gedankenstrich (README §5.6).
    public static func date(_ date: Date?) -> String {
        guard let date else { return "–" }
        return dayMonthYear.string(from: date)
    }

    /// Sternzeile: gesetzte Sterne gefüllt, Rest hohl. 0 = leere Zeile.
    public static func stars(_ rating: Int) -> String {
        guard rating > 0 else { return "" }
        let filled = min(5, max(0, rating))
        return String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
    }
}
