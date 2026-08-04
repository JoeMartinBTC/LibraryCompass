import SwiftUI

/// `bgLayers` aus TOKENS.md §1 — Basisverlauf 163° plus drei weiche Glows.
/// Liegt auf dem Fenster, nicht auf den Spalten.
struct BackgroundLayers: View {
    @Environment(\.lc) private var lc

    var body: some View {
        GeometryReader { geo in
            let h = max(geo.size.height, 1)
            ZStack {
                LinearGradient(gradient: lc.bgBase,
                               startPoint: UnitPoint(x: 0.12, y: 0),
                               endPoint: UnitPoint(x: 0.88, y: 1))
                glow(lc.glowTopLeft, x: 0.10, y: -0.12, radius: 0.95 * h)
                glow(lc.glowTopRight, x: 0.97, y: 0.06, radius: 0.80 * h)
                glow(lc.glowBottom, x: 0.60, y: 1.08, radius: 0.60 * h)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(_ color: Color, x: CGFloat, y: CGFloat, radius: CGFloat) -> some View {
        RadialGradient(gradient: Gradient(colors: [color, color.opacity(0)]),
                       center: UnitPoint(x: x, y: y),
                       startRadius: 0,
                       endRadius: max(radius, 1))
    }
}
