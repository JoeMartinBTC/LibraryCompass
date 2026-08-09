import SwiftUI
import LibraryCompassCore

/// Detail-Panel rechts, 352 breit (README §5.9). Chips ohne Genre.
struct DetailPanelView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    let book: Book

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Space.s3) {
                    CoverView(book: book, width: 158, radius: Radius.window)
                        .lcShadow(lc.shadowSheet)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                            .lcType(.detailTitle)
                            .foregroundStyle(lc.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(book.author.isEmpty ? "–" : book.author)
                            .lcType(.body)
                            .foregroundStyle(lc.text2)
                    }

                    HStack(spacing: 6) {
                        Chip(text: book.year.map(String.init) ?? "–")
                        Chip(text: book.pages.map { "\(LCFormat.number($0)) Seiten" } ?? "– Seiten")
                    }

                    EditCard(model: model, book: book)

                    Text("ISBN \(book.isbn.isEmpty ? "–" : book.isbn)")
                        .lcType(.captionS)
                        .tabularNums()
                        .foregroundStyle(lc.text3)
                        .padding(.top, 2)

                    deleteButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 2)
                .padding(.bottom, 28)
            }
        }
        .frame(width: Metrics.detailWidth)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(lc.sidebar)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(lc.brd).frame(width: 1)
        }
    }

    /// Löschen ist der einzige Schritt in dieser App, den kein zweiter Klick rückgängig
    /// macht — deshalb als einziger mit Rückfrage, und die Rückfrage nennt den Titel.
    private var deleteButton: some View {
        Button {
            model.pendingDeletion = book
        } label: {
            HStack(spacing: 6) {
                LineSymbol(name: "trash", size: 12, weight: .medium)
                Text("Buch löschen")
            }
            .lcType(.caption)
            .foregroundStyle(lc.pink)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.controlPanel)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(lc.pink.opacity(0.45), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, Space.s3)
        .accessibilityIdentifier("btn.deleteBook")
        .confirmationDialog("„\(book.title.isEmpty ? "Ohne Titel" : book.title)“ löschen?",
                            isPresented: Binding(
                                get: { model.pendingDeletion?.persistentModelID == book.persistentModelID },
                                set: { if !$0 { model.pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { model.delete(book) }
                .accessibilityIdentifier("btn.confirmDelete")
            Button("Abbrechen", role: .cancel) { model.pendingDeletion = nil }
        } message: {
            Text("Bewertung und Kommentar gehen mit verloren. Das lässt sich nicht rückgängig machen.")
        }
    }

    private var header: some View {
        HStack {
            Text("Details")
                .lcType(.label)
                .foregroundStyle(lc.text3)
            Spacer()
            Button {
                model.selection = nil
            } label: {
                LineSymbol(name: "xmark", size: 11)
                    .foregroundStyle(lc.text2)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn.closeDetail")
        }
        .padding(.horizontal, 24)
        .frame(height: Metrics.titlebarHeight)
    }
}

private struct Chip: View {
    @Environment(\.lc) private var lc
    let text: String

    var body: some View {
        Text(text)
            .lcType(.captionS)
            .foregroundStyle(lc.text2)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .glass(lc.glass, radius: Radius.s, border: lc.brd)
    }
}

/// Bearbeitungskarte: Bewertung, Gelesen-Datum, Kommentar — alles schreibt sofort.
private struct EditCard: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel
    let book: Book

    @State private var comment: String = ""
    @State private var readDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Meine Bewertung")
                        .lcType(.label)
                        .foregroundStyle(lc.text3)
                    Spacer()
                    Button("zurücksetzen") { model.setRating(0, for: book) }
                        .buttonStyle(.plain)
                        .lcType(.captionS)
                        .foregroundStyle(lc.text3)
                        .accessibilityIdentifier("btn.resetRating")
                }
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            model.setRating(value, for: book)
                        } label: {
                            Text(book.rating >= value ? "★" : "☆")
                                .font(.system(size: 25))
                                .foregroundStyle(book.rating >= value ? lc.gold : lc.glass3)
                                .lcShadow(book.rating >= value ? lc.starGlow : ShadowSpec(layers: []))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("btn.star\(value)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gelesen am")
                    .lcType(.label)
                    .foregroundStyle(lc.text3)
                HStack(spacing: 8) {
                    DatePicker("", selection: Binding(
                        get: { book.readDate ?? readDate },
                        set: { model.setReadDate($0, for: book) }
                    ), displayedComponents: .date)
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .lcType(.caption)
                        .frame(height: Metrics.controlPanel)
                        .padding(.horizontal, 8)
                        .glass(lc.glass2, radius: Radius.m, border: lc.brd)
                        .accessibilityIdentifier("field.readDate")

                    Button("Heute") { model.setReadDate(Date(), for: book) }
                        .buttonStyle(.plain)
                        .lcType(.caption)
                        .foregroundStyle(lc.text2)
                        .padding(.horizontal, 13)
                        .frame(height: Metrics.controlPanel)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .strokeBorder(lc.brd, lineWidth: 1)
                        }
                        .accessibilityIdentifier("btn.today")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Kommentar")
                    .lcType(.label)
                    .foregroundStyle(lc.text3)
                TextEditor(text: $comment)
                    .scrollContentBackground(.hidden)
                    .lcType(.caption)
                    .foregroundStyle(lc.text)
                    .frame(height: 100)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .glass(lc.glass2, radius: Radius.l, border: lc.brd)
                    .overlay(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("Notiz zu diesem Buch …")
                                .lcType(.caption)
                                .foregroundStyle(lc.text3)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: comment) { _, newValue in
                        model.setComment(newValue, for: book)
                    }
                    .accessibilityIdentifier("field.comment")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Space.s4)
        .glass(lc.glass, radius: Radius.tile, border: lc.brd, blurred: true)
        .lcShadow(lc.shadowCard)
        .onAppear { comment = book.comment }
        .onChange(of: book.persistentModelID) { _, _ in comment = book.comment }
    }
}
