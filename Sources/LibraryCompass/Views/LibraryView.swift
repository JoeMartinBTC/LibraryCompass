import SwiftUI
import LibraryCompassCore

/// Fenster: Seitenleiste · Mittelspalte · Detail-Panel über dem Verlaufsgrund (README §4).
struct LibraryView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    @Binding var appearance: String

    @AppStorage("sidebarOpen") private var sidebarOpen = true
    @AppStorage("sidebarWidth") private var sidebarWidth = Double(Metrics.sidebarWidth)
    @AppStorage("statsOpen") private var statsOpen = true
    @AppStorage("zoom") private var zoom = 1.0

    var body: some View {
        ZStack {
            BackgroundLayers()

            HStack(spacing: 0) {
                if sidebarOpen {
                    SidebarView(model: model)
                        .frame(width: sidebarWidth)
                        .fixedSize(horizontal: true, vertical: false)
                        .overlay(alignment: .trailing) { resizeHandle }
                }

                mainColumn

                if let book = model.selection {
                    DetailPanelView(model: model, book: book)
                }
            }

            if model.dialog == .isbn {
                ISBNSheet(model: model)
            } else if model.dialog == .importer {
                ImportSheet(model: model)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .animation(nil, value: sidebarWidth)
        .animation(nil, value: statsOpen)
        .animation(nil, value: model.viewMode)
    }

    private var mainColumn: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ToolbarView(model: model, sidebarOpen: $sidebarOpen, zoom: $zoom, appearance: $appearance)
                TitleRow(model: model, statsOpen: $statsOpen)
                if statsOpen {
                    StatsCardsView(model: model)
                } else {
                    Color.clear.frame(height: 14)
                }
                BooksAreaView(model: model, zoom: zoom)
            }

            LinearGradient(stops: lc.scrim, startPoint: .top, endPoint: .bottom)
                .frame(height: Metrics.scrimHeight)
                .allowsHitTesting(false)

            FloatingAction { model.dialog = .isbn }
                .padding(.bottom, Metrics.actionBottomInset)
        }
        // Mittelspalte gibt nach, damit Seitenleiste (bis 400) und Detail-Panel
        // nebeneinander passen — Inhalte kürzen statt überlaufen (README §11.5).
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipped()
    }

    /// Ziehfläche an der rechten Kante — folgt dem Cursor 1:1, ohne Animation.
    private var resizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(width: Metrics.sidebarHandle)
            .offset(x: 3)
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        sidebarWidth = min(Double(Metrics.sidebarMax),
                                           max(Double(Metrics.sidebarMin), value.location.x))
                    }
            )
            .accessibilityIdentifier("handle.sidebar")
    }
}

/// Titelzeile mit Anzahl und Statistik-Umschalter (README §5.3).
private struct TitleRow: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    @Binding var statsOpen: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.s3) {
            Text(model.screenTitle)
                .lcType(.screenTitle)
                .foregroundStyle(lc.text)
                .accessibilityIdentifier("lbl.screenTitle")
            Spacer(minLength: Space.s3)
            Text(model.countLine)
                .lcType(.caption)
                .tabularNums()
                .foregroundStyle(lc.text3)
                .lineLimit(1)
                .accessibilityIdentifier("lbl.count")
            Button {
                statsOpen.toggle()
            } label: {
                HStack(spacing: 5) {
                    Text("Statistik")
                        .lcType(.captionS)
                        .foregroundStyle(hovering ? lc.text : lc.text2)
                    LineSymbol(name: "chevron.down", size: 8)
                        .foregroundStyle(lc.text3)
                        .rotationEffect(.degrees(statsOpen ? 180 : 0))
                }
                .padding(.horizontal, 11)
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .fill(statsOpen ? lc.glass : (hovering ? lc.glass2 : .clear)))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(lc.brd, lineWidth: 1)
            }
            .onHover { hovering = $0 }
            .accessibilityIdentifier("btn.stats")
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, 4)
    }
}

/// Einzige Hauptaktion des Screens (README §5.8).
private struct FloatingAction: View {
    @Environment(\.lc) private var lc
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LineSymbol(name: "plus", size: 15, weight: .medium)
                Text("Buch hinzufügen").lcType(.action)
            }
            .foregroundStyle(lc.accentInk)
            .padding(.horizontal, 34)
            .frame(height: Metrics.controlAction)
            .background(Capsule().fill(lc.accentGradient))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .lcShadow(lc.glow)
            .brightness(hovering ? 0.06 : 0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityIdentifier("btn.addBook")
    }
}
