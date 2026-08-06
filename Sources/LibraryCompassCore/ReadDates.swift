import Foundation
import SwiftData

/// Bücher aus dem Import gelten als gelesen — sie stehen im Regal, weil sie
/// gelesen wurden. Delicious Library selbst führte kein Gelesen-Kennzeichen
/// (`hasExperienced` war nie gesetzt), deshalb dient das Erfassungsdatum als
/// Gelesen-Datum. Ein einmaliges Datum genügt (Entscheid 2026-08-03).
@MainActor
public enum ReadDates {

    /// Setzt bei allen Büchern ohne Gelesen-Datum das Erfassungsdatum ein.
    /// Eigene Angaben bleiben unangetastet; ein zweiter Lauf ändert nichts.
    /// - Returns: Anzahl der geänderten Bücher.
    @discardableResult
    public static func markAllAsRead(in context: ModelContext) -> Int {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        var changed = 0
        for book in books where book.readDate == nil {
            book.readDate = book.addedDate
            changed += 1
        }
        if changed > 0 { try? context.save() }
        return changed
    }
}
