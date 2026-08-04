import SwiftUI
import LibraryCompassCore

/// Seitenleiste: vier Filterzeilen und der Import-Footer (README §5.1, ohne Genres).
struct SidebarView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Titelleistenbereich — hier sitzen die Fensterknöpfe des Systems.
            Color.clear.frame(height: Metrics.titlebarHeight)

            VStack(spacing: 3) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    FilterRow(filter: filter,
                              count: model.counts[filter],
                              isActive: model.filter == filter) {
                        model.filter = filter
                    }
                }
            }

            Spacer(minLength: 0)

            Divider().overlay(lc.brd)
            ImportRow { model.dialog = .importer }
                .padding(Space.s3)
        }
        .padding(.horizontal, Space.s3)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(lc.sidebar)
            }
        }
    }
}

private struct FilterRow: View {
    @Environment(\.lc) private var lc
    let filter: LibraryFilter
    let count: Int
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    private var symbol: String {
        switch filter {
        case .alle: "books.vertical"
        case .gelesen: "checkmark"
        case .ungelesen: "circle.slash"
        case .bewertet: "star"
        }
    }

    private var tint: (UInt32, UInt32) {
        switch filter {
        case .alle: (0xB45CFF, 0x7B3BE8)
        case .gelesen: (0x56E39F, 0x177A5A)
        case .ungelesen: (0xFFB347, 0xB8531A)
        case .bewertet: (0xFFC24F, 0x8A6516)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                IconTile(symbol: symbol, tint: tint)
                Text(filter.title)
                    .lcType(isActive ? .bodyMActive : .bodyM)
                    .foregroundStyle(isActive ? lc.text : lc.text2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(LCFormat.number(count))
                    .lcType(.captionS)
                    .tabularNums()
                    .foregroundStyle(lc.text3)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive || hovering ? lc.glass2 : .clear)
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(lc.brd2, lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: Motion.hover), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityIdentifier("filter.\(filter.rawValue)")
    }
}

/// 26-px-Kachel mit Verlauf 150° und weißem Strichsymbol.
private struct IconTile: View {
    let symbol: String
    let tint: (UInt32, UInt32)

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
            .fill(LinearGradient(stops: [.init(color: Color(hex: tint.0), location: 0),
                                         .init(color: Color(hex: tint.1), location: 0.55)],
                                 startPoint: UnitPoint(x: 0.10, y: 0),
                                 endPoint: UnitPoint(x: 0.90, y: 1)))
            .frame(width: 26, height: 26)
            .overlay {
                LineSymbol(name: symbol, size: 13, weight: .medium)
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: tint.1).opacity(0.45), radius: 5, y: 3)
    }
}

private struct ImportRow: View {
    @Environment(\.lc) private var lc
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .fill(lc.glass2)
                    .frame(width: 26, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                            .strokeBorder(lc.brd, lineWidth: 1)
                    }
                    .overlay {
                        LineSymbol(name: "arrow.down.to.line", size: 12, weight: .medium)
                            .foregroundStyle(lc.text2)
                    }
                Text("Delicious Library importieren")
                    .lcType(.caption)
                    .foregroundStyle(lc.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(hovering ? lc.glass2 : .clear)
        }
        .animation(.easeOut(duration: Motion.hover), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityIdentifier("btn.import")
    }
}
