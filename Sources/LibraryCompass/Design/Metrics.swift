import Foundation

/// Radien aus TOKENS.md §4.
enum Radius {
    static let xs: CGFloat = 4
    static let s: CGFloat = 9
    static let m: CGFloat = 11
    static let l: CGFloat = 13
    static let card: CGFloat = 20
    static let sheet: CGFloat = 24
    static let pill: CGFloat = 26
    static let window: CGFloat = 14
    static let row: CGFloat = 13
    static let tile: CGFloat = 18
}

/// Spacing-Raster aus TOKENS.md §6.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 26
    static let s7: CGFloat = 28
    static let gridGapV: CGFloat = 26
    static let gridGapH: CGFloat = 20
}

/// Maße aus TOKENS.md §7.
enum Metrics {
    static let sidebarWidth: CGFloat = 252
    static let sidebarMin: CGFloat = 180
    static let sidebarMax: CGFloat = 400
    static let sidebarHandle: CGFloat = 7
    static let detailWidth: CGFloat = 352
    static let titlebarHeight: CGFloat = 54
    static let toolbarHeight: CGFloat = 54
    static let rowHeight: CGFloat = 58
    static let thumbWidth: CGFloat = 34
    static let thumbHeight: CGFloat = 50
    static let coverMinWidth: CGFloat = 146
    static let zoomMin: Double = 0.70
    static let zoomMax: Double = 1.70
    static let zoomStep: Double = 0.10
    static let ringSize: CGFloat = 84
    static let ringWidth: CGFloat = 7
    static let controlToolbar: CGFloat = 32
    static let controlPanel: CGFloat = 33
    static let controlDialog: CGFloat = 36
    static let controlAction: CGFloat = 52
    static let scrimHeight: CGFloat = 112
    static let actionBottomInset: CGFloat = 26
    static let blurChrome: CGFloat = 24
    static let blurCard: CGFloat = 20
    static let blurSheet: CGFloat = 40
    static let blurOverlay: CGFloat = 8
    /// Nachladeschritt beim Scrollen (README §7).
    static let pageSize = 60
}

/// Bewegung aus TOKENS.md §8 — hart begrenzt, nie auf Layout-Eigenschaften.
enum Motion {
    static let hover: Double = 0.12
    static let progress: Double = 0.14
    static let sheetIn: Double = 0.12
}
