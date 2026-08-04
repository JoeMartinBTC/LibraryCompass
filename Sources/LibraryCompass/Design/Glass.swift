import SwiftUI

/// Glasfläche: Tint-Token über optionalem Blur, dazu die 1-px-Kante (TOKENS §2/§5).
struct GlassSurface: ViewModifier {
    let fill: Color
    let radius: CGFloat
    let border: Color?
    let blurred: Bool

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if blurred {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fill)
                }
            }
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func glass(_ fill: Color, radius: CGFloat, border: Color? = nil, blurred: Bool = false) -> some View {
        modifier(GlassSurface(fill: fill, radius: radius, border: border, blurred: blurred))
    }

    /// Auswahl-Ring einer Karte/Zeile: `0 0 0 1 brd2` plus weicher Schlagschatten.
    func selectionRing(_ color: Color, radius: CGFloat, active: Bool) -> some View {
        overlay {
            if active {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(color, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(active ? 0.22 : 0), radius: active ? 15 : 0, y: active ? 10 : 0)
    }
}

/// Strichsymbol im Stil des Prototyps (Strichstärke 1.5, runde Enden).
struct LineSymbol: View {
    let name: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .imageScale(.medium)
    }
}
