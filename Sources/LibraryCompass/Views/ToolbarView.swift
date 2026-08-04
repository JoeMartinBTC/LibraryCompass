import SwiftUI
import LibraryCompassCore

/// Toolbar, 54 hoch (README §5.2).
struct ToolbarView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    @Binding var sidebarOpen: Bool
    @Binding var zoom: Double
    @Binding var appearance: String

    var body: some View {
        HStack(spacing: 10) {
            // Bei zugeklappter Seitenleiste sitzen die Fensterknöpfe hier.
            if !sidebarOpen {
                Color.clear.frame(width: 68, height: 1)
            }

            ToolbarButton(symbol: "sidebar.left",
                          fill: sidebarOpen ? lc.glass : lc.glass3,
                          identifier: "btn.sidebar") {
                sidebarOpen.toggle()
            }

            SearchField(text: $model.search)

            Spacer(minLength: Space.s2)

            ZoomControl(zoom: $zoom)

            SortPicker(sort: $model.sort)

            ViewSwitcher(mode: $model.viewMode)

            ToolbarButton(glyph: Appearance(rawValue: appearance)?.glyph ?? "◐",
                          fill: lc.glass,
                          identifier: "btn.appearance") {
                appearance = (Appearance(rawValue: appearance) ?? .auto).next.rawValue
            }
        }
        .padding(.horizontal, Space.s6)
        .frame(height: Metrics.toolbarHeight)
    }
}

private struct ToolbarButton: View {
    @Environment(\.lc) private var lc
    var symbol: String?
    var glyph: String?
    let fill: Color
    let identifier: String
    let action: () -> Void

    init(symbol: String? = nil, glyph: String? = nil, fill: Color, identifier: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.glyph = glyph
        self.fill = fill
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol {
                    LineSymbol(name: symbol, size: 14)
                } else if let glyph {
                    Text(glyph).font(.system(size: 13))
                }
            }
            .foregroundStyle(lc.text2)
            .frame(width: Metrics.controlToolbar, height: Metrics.controlToolbar)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glass(fill, radius: Radius.m, border: lc.brd)
        .accessibilityIdentifier(identifier)
    }
}

private struct SearchField: View {
    @Environment(\.lc) private var lc
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            LineSymbol(name: "magnifyingglass", size: 12)
                .foregroundStyle(lc.text3)
            TextField("Titel oder Autor suchen", text: $text)
                .textFieldStyle(.plain)
                .lcType(.caption)
                .foregroundStyle(lc.text)
                .focused($focused)
                .accessibilityIdentifier("field.search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Text("✕")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(lc.text2)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(lc.glass3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn.clearSearch")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 288, height: Metrics.controlToolbar)
        .glass(lc.glass, radius: Radius.m, border: focused ? lc.accent : lc.brd, blurred: true)
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(lc.accent, lineWidth: 1.5)
            }
        }
    }
}

/// Zoom-Regler: −, Spur mit Verlauf, +, Prozentanzeige (README §5.2).
private struct ZoomControl: View {
    @Environment(\.lc) private var lc
    @Binding var zoom: Double

    private let trackWidth: CGFloat = 86

    var body: some View {
        HStack(spacing: 9) {
            StepButton(symbol: "minus", identifier: "btn.zoomOut") {
                zoom = clamp(zoom - Metrics.zoomStep)
            }

            ZStack(alignment: .leading) {
                Capsule().fill(lc.glass3).frame(width: trackWidth, height: 4)
                Capsule()
                    .fill(LinearGradient(colors: [lc.cyan, lc.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, trackWidth * fraction), height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: trackWidth * fraction - 6)
            }
            .frame(width: trackWidth, height: 14)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let f = min(1, max(0, value.location.x / trackWidth))
                zoom = clamp(Metrics.zoomMin + f * (Metrics.zoomMax - Metrics.zoomMin))
            })

            StepButton(symbol: "plus", identifier: "btn.zoomIn") {
                zoom = clamp(zoom + Metrics.zoomStep)
            }

            Text("\(Int((zoom * 100).rounded()))\u{00A0}%")
                .lcType(.captionS)
                .tabularNums()
                .foregroundStyle(lc.text3)
                .frame(width: 40, alignment: .trailing)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, Space.s3)
        .frame(height: Metrics.controlToolbar)
        .glass(lc.glass, radius: Radius.m, border: lc.brd)
    }

    private var fraction: CGFloat {
        CGFloat((zoom - Metrics.zoomMin) / (Metrics.zoomMax - Metrics.zoomMin))
    }

    private func clamp(_ value: Double) -> Double {
        (min(Metrics.zoomMax, max(Metrics.zoomMin, value)) * 100).rounded() / 100
    }

    private struct StepButton: View {
        @Environment(\.lc) private var lc
        let symbol: String
        let identifier: String
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                LineSymbol(name: symbol, size: 9, weight: .semibold)
                    .foregroundStyle(lc.text2)
                    .frame(width: 16, height: 16)
                    .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? lc.glass3 : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .accessibilityIdentifier(identifier)
        }
    }
}

private struct SortPicker: View {
    @Environment(\.lc) private var lc
    @Binding var sort: LibrarySort

    var body: some View {
        Picker("", selection: $sort) {
            ForEach(LibrarySort.allCases, id: \.self) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .buttonStyle(.borderless)
        .lcType(.caption)
        .tint(lc.text2)
        .padding(.horizontal, 6)
        .frame(height: Metrics.controlToolbar)
        .fixedSize()
        .glass(lc.glass, radius: Radius.m, border: lc.brd, blurred: true)
        .accessibilityIdentifier("menu.sort")
    }
}

private struct ViewSwitcher: View {
    @Environment(\.lc) private var lc
    @Binding var mode: ViewMode

    var body: some View {
        HStack(spacing: 3) {
            segment(.grid, symbol: "square.grid.2x2", identifier: "btn.grid")
            segment(.list, symbol: "list.bullet", identifier: "btn.list")
        }
        .padding(3)
        .glass(lc.glass, radius: 12, border: lc.brd)
    }

    private func segment(_ value: ViewMode, symbol: String, identifier: String) -> some View {
        Button {
            mode = value
        } label: {
            LineSymbol(name: symbol, size: 12)
                .foregroundStyle(mode == value ? lc.text : lc.text3)
                .frame(width: 36, height: 26)
                .background(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .fill(mode == value ? lc.glass3 : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
