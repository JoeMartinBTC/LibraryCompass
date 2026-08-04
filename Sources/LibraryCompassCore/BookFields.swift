import Foundation

/// Die zehn Felder eines Buchs (BUILD-HANDOVER §2) als Lesezugriff.
/// Filter, Sortierung und Statistik arbeiten gegen dieses Protokoll, damit sie
/// ohne Store getestet werden können.
public protocol BookFields {
    var isbn: String { get }
    var title: String { get }
    var author: String { get }
    var coverPath: String? { get }
    var rating: Int { get }
    var comment: String { get }
    var readDate: Date? { get }
    var addedDate: Date { get }
    var year: Int? { get }
    var pages: Int? { get }
}
