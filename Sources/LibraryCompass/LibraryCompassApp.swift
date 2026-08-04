import SwiftUI

@main
struct LibraryCompassApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 920)
    }
}

/// Erscheinungsbild-Umschalter aus README §5.2 — auto → hell → dunkel → auto.
enum Appearance: String, CaseIterable {
    case auto, hell, dunkel

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .hell: .light
        case .dunkel: .dark
        }
    }

    var glyph: String {
        switch self {
        case .auto: "◐"
        case .hell: "○"
        case .dunkel: "●"
        }
    }

    var next: Appearance {
        switch self {
        case .auto: .hell
        case .hell: .dunkel
        case .dunkel: .auto
        }
    }
}

struct RootView: View {
    @AppStorage("appearance") private var appearanceRaw = Appearance.auto.rawValue

    var body: some View {
        ThemedRoot()
            .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
    }
}

/// Löst das Farbschema (System oder manuell) in ein `LCTheme` auf und legt es in die Umgebung.
private struct ThemedRoot: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LibraryView()
            .environment(\.lc, colorScheme == .dark ? .dark : .light)
    }
}
