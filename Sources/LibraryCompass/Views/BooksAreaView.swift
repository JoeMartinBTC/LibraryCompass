import SwiftUI
import LibraryCompassCore

/// Scrollbereich: Cover-Grid oder Liste, Leerzustand, Nachladen in Blöcken von 60.
struct BooksAreaView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    let zoom: Double

    var body: some View {
        ScrollView(.vertical) {
            if model.rows.isEmpty {
                EmptyStateView(query: model.search)
            } else if model.viewMode == .grid {
                CoverGrid(model: model, zoom: zoom)
            } else {
                BookList(model: model, zoom: zoom)
            }
        }
        .scrollIndicators(.automatic)
        .accessibilityIdentifier("area.books")
    }
}

private struct CoverGrid: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    let zoom: Double

    var body: some View {
        let coverWidth = (Metrics.coverMinWidth * zoom).rounded()
        LazyVGrid(columns: [GridItem(.adaptive(minimum: coverWidth), spacing: Space.gridGapH, alignment: .top)],
                  alignment: .leading,
                  spacing: Space.gridGapV) {
            ForEach(Array(model.visibleRows.enumerated()), id: \.element.persistentModelID) { index, book in
                GridCard(book: book, width: coverWidth, isSelected: model.selection === book) {
                    model.selection = book
                }
                .onAppear {
                    if index >= model.limit - 12 { model.loadMoreIfNeeded() }
                }
            }
        }
        .padding(.horizontal, Space.s6)
        .padding(.bottom, 104)
    }
}

private struct GridCard: View {
    @Environment(\.lc) private var lc
    let book: Book
    let width: CGFloat
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                CoverView(book: book, width: width)
                    .lcShadow(lc.shadowCover)
                Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                    .lcType(.body)
                    .foregroundStyle(lc.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author.isEmpty ? "–" : book.author)
                    .lcType(.captionS)
                    .foregroundStyle(lc.text3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(LCFormat.stars(book.rating))
                    .font(.system(size: 10.5))
                    .tracking(1)
                    .foregroundStyle(lc.gold)
                    .frame(height: 14, alignment: .leading)
            }
            .frame(width: width, alignment: .leading)
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(isSelected ? lc.glass2 : (hovering ? lc.glass : .clear))
        }
        .selectionRing(lc.brd2, radius: Radius.tile, active: isSelected)
        .padding(-8)
        .onHover { hovering = $0 }
        .accessibilityIdentifier("card.book")
    }
}

private struct BookList: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    let zoom: Double

    var body: some View {
        LazyVStack(spacing: 3) {
            header
            ForEach(Array(model.visibleRows.enumerated()), id: \.element.persistentModelID) { index, book in
                ListRow(book: book, zoom: zoom, isSelected: model.selection === book) {
                    model.selection = book
                }
                .onAppear {
                    if index >= model.limit - 12 { model.loadMoreIfNeeded() }
                }
            }
        }
        .padding(.horizontal, Space.s6)
        .padding(.bottom, 104)
    }

    /// Spalten ohne Genre (BUILD-HANDOVER §1).
    private var header: some View {
        HStack(spacing: Space.s4) {
            Color.clear.frame(width: Metrics.thumbWidth * zoom, height: 1)
            Text("Titel").frame(maxWidth: .infinity, alignment: .leading)
            Text("Jahr").frame(width: 48, alignment: .leading)
            Text("Bewertung").frame(width: 74, alignment: .leading)
            Text("Gelesen").frame(width: 96, alignment: .trailing)
        }
        .lcType(.label)
        .foregroundStyle(lc.text3)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, Space.s4)
        .padding(.bottom, Space.s2)
    }
}

private struct ListRow: View {
    @Environment(\.lc) private var lc
    let book: Book
    let zoom: Double
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s4) {
                // Pflicht laut ISC-12: jede Zeile zeigt eine Cover-Vorschau.
                CoverView(book: book, width: Metrics.thumbWidth * zoom, radius: 4,
                          showsLabels: false, spineWidth: 3)
                    .lcShadow(lc.shadowCover)
                    .accessibilityIdentifier("thumb.cover")

                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                        .lcType(.body)
                        .foregroundStyle(lc.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(book.author.isEmpty ? "–" : book.author)
                        .lcType(.captionS)
                        .foregroundStyle(lc.text3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(book.year.map(String.init) ?? "–")
                    .lcType(.caption)
                    .tabularNums()
                    .foregroundStyle(lc.text2)
                    .frame(width: 48, alignment: .leading)
                Text(LCFormat.stars(book.rating))
                    .font(.system(size: 11))
                    .tracking(1)
                    .foregroundStyle(lc.gold)
                    .frame(width: 74, alignment: .leading)
                Text(LCFormat.date(book.readDate))
                    .lcType(.caption)
                    .tabularNums()
                    .foregroundStyle(lc.text2)
                    .frame(width: 96, alignment: .trailing)
                    .lineLimit(1)
            }
            .padding(.horizontal, Space.s4)
            .frame(height: Metrics.rowHeight * zoom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(isSelected ? lc.glass2 : (hovering ? lc.glass : .clear))
        }
        .selectionRing(lc.brd2, radius: Radius.row, active: isSelected)
        .onHover { hovering = $0 }
        .accessibilityIdentifier("row.book")
    }
}

/// Leerzustand (README §5.7).
struct EmptyStateView: View {
    @Environment(\.lc) private var lc
    let query: String

    var body: some View {
        VStack(spacing: Space.s3) {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(lc.accentGradient)
                .frame(width: 64, height: 64)
                .overlay {
                    LineSymbol(name: "magnifyingglass", size: 28, weight: .light)
                        .foregroundStyle(.white)
                }
                .lcShadow(lc.glow)
            Text("Keine Treffer")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(lc.text)
            Text(query.isEmpty
                 ? "In dieser Auswahl ist kein Buch vorhanden."
                 : "Für „\(query)“ ist in dieser Auswahl kein Buch vorhanden.")
                .lcType(.body)
                .foregroundStyle(lc.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
        .accessibilityIdentifier("state.empty")
    }
}
