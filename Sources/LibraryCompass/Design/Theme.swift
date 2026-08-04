import SwiftUI

extension Color {
    /// `Color(hex: 0xB45CFF)` — Kurzform für die Tokens aus TOKENS.md.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Ein Schatten-Token aus TOKENS.md §5 (mehrlagig).
struct ShadowSpec {
    struct Layer {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    let layers: [Layer]
}

/// Alle Farb-, Verlaufs- und Schatten-Tokens für eine Erscheinung.
/// Namen 1:1 aus `design/handoff/TOKENS.md`.
struct LCTheme {
    let isDark: Bool

    // §2 Farben
    let sidebar: Color
    let glass: Color
    let glass2: Color
    let glass3: Color
    let brd: Color
    let brd2: Color
    let text: Color
    let text2: Color
    let text3: Color
    let accent: Color
    let accent2: Color
    let accentInk: Color
    let cyan: Color
    let mint: Color
    let gold: Color
    let pink: Color
    let scrim: [Gradient.Stop]

    // §1 Hintergrund
    let bgBase: Gradient
    let glowTopLeft: Color
    let glowTopRight: Color
    let glowBottom: Color

    // §5 Schatten
    let shadowCard: ShadowSpec
    let shadowCover: ShadowSpec
    let shadowSheet: ShadowSpec
    let shadowWindow: ShadowSpec
    let ringGlow: ShadowSpec
    let starGlow: ShadowSpec
    let glow: ShadowSpec

    var accentGradient: LinearGradient {
        // Verlauf 150° (CSS) — in SwiftUI-Koordinaten oben-links → unten-rechts, flach geneigt.
        LinearGradient(colors: [accent, accent2],
                       startPoint: UnitPoint(x: 0.10, y: 0.0),
                       endPoint: UnitPoint(x: 0.90, y: 1.0))
    }

    static let dark = LCTheme(
        isDark: true,
        sidebar: Color(hex: 0x0C051C, opacity: 0.34),
        glass: Color(hex: 0xFFFFFF, opacity: 0.055),
        glass2: Color(hex: 0xFFFFFF, opacity: 0.10),
        glass3: Color(hex: 0xFFFFFF, opacity: 0.16),
        brd: Color(hex: 0xFFFFFF, opacity: 0.11),
        brd2: Color(hex: 0xFFFFFF, opacity: 0.20),
        text: Color(hex: 0xFFFFFF),
        text2: Color(hex: 0xFFFFFF, opacity: 0.66),
        text3: Color(hex: 0xFFFFFF, opacity: 0.40),
        accent: Color(hex: 0xB45CFF),
        accent2: Color(hex: 0x7B3BE8),
        accentInk: Color(hex: 0xFFFFFF),
        cyan: Color(hex: 0x4FD8E8),
        mint: Color(hex: 0x56E39F),
        gold: Color(hex: 0xFFC24F),
        pink: Color(hex: 0xFF6BC1),
        scrim: [.init(color: Color(hex: 0x150A2C, opacity: 0), location: 0),
                .init(color: Color(hex: 0x150A2C, opacity: 0.50), location: 0.5),
                .init(color: Color(hex: 0x150A2C, opacity: 0.82), location: 1)],
        bgBase: Gradient(stops: [
            .init(color: Color(hex: 0x28104E), location: 0),
            .init(color: Color(hex: 0x1B0C36), location: 0.55),
            .init(color: Color(hex: 0x150A2C), location: 1)
        ]),
        glowTopLeft: Color(hex: 0x5A2497),
        glowTopRight: Color(hex: 0x2E3FA8),
        glowBottom: Color(hex: 0x7A2A9E),
        shadowCard: ShadowSpec(layers: [
            .init(color: .black.opacity(0.22), radius: 3, x: 0, y: 2),
            .init(color: .black.opacity(0.30), radius: 22, x: 0, y: 18)
        ]),
        shadowCover: ShadowSpec(layers: [
            .init(color: .black.opacity(0.34), radius: 5, x: 0, y: 3),
            .init(color: .black.opacity(0.34), radius: 17, x: 0, y: 14)
        ]),
        shadowSheet: ShadowSpec(layers: [
            .init(color: .black.opacity(0.62), radius: 40, x: 0, y: 30)
        ]),
        shadowWindow: ShadowSpec(layers: [
            .init(color: .black.opacity(0.55), radius: 45, x: 0, y: 40)
        ]),
        ringGlow: ShadowSpec(layers: [
            .init(color: Color(hex: 0xB45CFF, opacity: 0.34), radius: 13, x: 0, y: 0)
        ]),
        starGlow: ShadowSpec(layers: [
            .init(color: Color(hex: 0xFFC24F, opacity: 0.55), radius: 6, x: 0, y: 0)
        ]),
        glow: ShadowSpec(layers: [
            .init(color: Color(hex: 0xB45CFF, opacity: 0.38), radius: 20, x: 0, y: 14)
        ])
    )

    static let light = LCTheme(
        isDark: false,
        sidebar: Color(hex: 0xFFFFFF, opacity: 0.44),
        glass: Color(hex: 0xFFFFFF, opacity: 0.66),
        glass2: Color(hex: 0xFFFFFF, opacity: 0.86),
        glass3: Color(hex: 0x7C46C8, opacity: 0.10),
        brd: Color(hex: 0x4A267C, opacity: 0.12),
        brd2: Color(hex: 0x4A267C, opacity: 0.20),
        text: Color(hex: 0x1E1136),
        text2: Color(hex: 0x1E1136, opacity: 0.62),
        text3: Color(hex: 0x1E1136, opacity: 0.40),
        accent: Color(hex: 0x8B3FE0),
        accent2: Color(hex: 0x6A29C4),
        accentInk: Color(hex: 0xFFFFFF),
        cyan: Color(hex: 0x1F9BB0),
        mint: Color(hex: 0x1E9E6A),
        gold: Color(hex: 0xC8892A),
        pink: Color(hex: 0xD4459B),
        scrim: [.init(color: Color(hex: 0xF8F5FF, opacity: 0), location: 0),
                .init(color: Color(hex: 0xF8F5FF, opacity: 0.62), location: 0.5),
                .init(color: Color(hex: 0xF8F5FF, opacity: 0.92), location: 1)],
        bgBase: Gradient(stops: [
            .init(color: Color(hex: 0xFAF7FF), location: 0),
            .init(color: Color(hex: 0xF3EEFD), location: 1)
        ]),
        glowTopLeft: Color(hex: 0xE5D6FF),
        glowTopRight: Color(hex: 0xD9E3FF),
        glowBottom: Color(hex: 0xF0DAFB),
        shadowCard: ShadowSpec(layers: [
            .init(color: Color(hex: 0x28104E, opacity: 0.06), radius: 3, x: 0, y: 2),
            .init(color: Color(hex: 0x28104E, opacity: 0.10), radius: 22, x: 0, y: 18)
        ]),
        shadowCover: ShadowSpec(layers: [
            .init(color: Color(hex: 0x28104E, opacity: 0.14), radius: 5, x: 0, y: 3),
            .init(color: Color(hex: 0x28104E, opacity: 0.14), radius: 17, x: 0, y: 14)
        ]),
        shadowSheet: ShadowSpec(layers: [
            .init(color: Color(hex: 0x28104E, opacity: 0.28), radius: 40, x: 0, y: 30)
        ]),
        shadowWindow: ShadowSpec(layers: [
            .init(color: Color(hex: 0x28104E, opacity: 0.22), radius: 45, x: 0, y: 40)
        ]),
        ringGlow: ShadowSpec(layers: [
            .init(color: Color(hex: 0x8B3FE0, opacity: 0.22), radius: 13, x: 0, y: 0)
        ]),
        starGlow: ShadowSpec(layers: [
            .init(color: Color(hex: 0xC8892A, opacity: 0.34), radius: 6, x: 0, y: 0)
        ]),
        glow: ShadowSpec(layers: [
            .init(color: Color(hex: 0x8B3FE0, opacity: 0.26), radius: 20, x: 0, y: 14)
        ])
    )
}

private struct LCThemeKey: EnvironmentKey {
    static let defaultValue = LCTheme.dark
}

extension EnvironmentValues {
    var lc: LCTheme {
        get { self[LCThemeKey.self] }
        set { self[LCThemeKey.self] = newValue }
    }
}

extension View {
    /// Mehrlagigen Schatten aus einem Token anwenden.
    func lcShadow(_ spec: ShadowSpec) -> some View {
        spec.layers.reduce(AnyView(self)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }
}
