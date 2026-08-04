import SwiftUI

/// Typo-Skala aus TOKENS.md §3. SF Pro (System), große Zahlen bewusst leicht (300/400).
enum LCType {
    case screenTitle    // 36 / 300 / −0.03em
    case heroNumber     // 32 / 300 / −0.03em
    case statNumber     // 28 / 300 / −0.03em
    case ringValue      // 20 / 400 / −0.02em
    case detailTitle    // 21 / 400 / −0.02em
    case sheetTitle     // 17.5 / 500 / −0.01em
    case action         // 14.5 / 500
    case bodyM          // 13.5 / 450
    case bodyMActive    // 13.5 / 560
    case body           // 13 / 450
    case caption        // 12.5 / 450
    case captionS       // 11.5 / 450
    case label          // 10.5 / 700 / +0.09em / UPPERCASE
    case coverTitle     // 13 / 600
    case coverAuthor    // 8.5 / 600 / +0.11em / UPPERCASE

    var size: CGFloat {
        switch self {
        case .screenTitle: 36
        case .heroNumber: 32
        case .statNumber: 28
        case .detailTitle: 21
        case .ringValue: 20
        case .sheetTitle: 17.5
        case .action: 14.5
        case .bodyM, .bodyMActive: 13.5
        case .body, .coverTitle: 13
        case .caption: 12.5
        case .captionS: 11.5
        case .label: 10.5
        case .coverAuthor: 8.5
        }
    }

    var weight: Font.Weight {
        switch self {
        case .screenTitle, .heroNumber, .statNumber: .light        // 300
        case .ringValue, .detailTitle: .regular                    // 400
        case .sheetTitle, .action: .medium                         // 500
        case .bodyM, .body, .caption, .captionS: .regular          // 450
        case .bodyMActive: .medium                                 // 560
        case .label: .bold                                         // 700
        case .coverTitle, .coverAuthor: .semibold                  // 600
        }
    }

    /// Tracking in Punkten (em × Größe).
    var tracking: CGFloat {
        switch self {
        case .screenTitle, .heroNumber, .statNumber: -0.03 * size
        case .ringValue, .detailTitle: -0.02 * size
        case .sheetTitle: -0.01 * size
        case .label: 0.09 * size
        case .coverAuthor: 0.11 * size
        default: 0
        }
    }

    var isUppercase: Bool { self == .label || self == .coverAuthor }
}

private struct LCTypeModifier: ViewModifier {
    let type: LCType
    func body(content: Content) -> some View {
        content
            .font(.system(size: type.size, weight: type.weight))
            .tracking(type.tracking)
            .textCase(type.isUppercase ? .uppercase : nil)
    }
}

extension View {
    func lcType(_ type: LCType) -> some View { modifier(LCTypeModifier(type: type)) }
    /// Zahlen laufen immer mit fester Ziffernbreite (TOKENS §3).
    func tabularNums() -> some View { monospacedDigit() }
}
