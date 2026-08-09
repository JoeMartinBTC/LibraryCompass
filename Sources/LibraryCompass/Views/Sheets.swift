import SwiftUI
import UniformTypeIdentifiers
import LibraryCompassCore

/// Gemeinsamer Rahmen der beiden Dialoge (README §5.10/§5.11).
struct SheetContainer<Content: View>: View {
    @Environment(\.lc) private var lc
    let width: CGFloat
    let topInset: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            // Abdunkeln statt Material: ein Material über dem Inhalt legt in SwiftUI
            // nur den Fensterhintergrund frei und verdeckt die Bibliothek komplett.
            Color(hex: 0x0C051C, opacity: 0.52)
                .ignoresSafeArea()
            content
                .padding(Space.s7)
                .frame(width: width, alignment: .leading)
                .glass(lc.glass2, radius: Radius.sheet, border: lc.brd2, blurred: true)
                .lcShadow(lc.shadowSheet)
                .padding(.top, topInset)
        }
        .transition(.opacity.combined(with: .offset(y: -10)))
    }
}

/// Buch per ISBN hinzufügen (README §5.10).
struct ISBNSheet: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel

    var body: some View {
        SheetContainer(width: 466, topInset: 130) {
            VStack(alignment: .leading, spacing: Space.s4) {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                        .fill(lc.accentGradient)
                        .frame(width: 38, height: 38)
                        .overlay { LineSymbol(name: "plus", size: 16, weight: .medium).foregroundStyle(.white) }
                        .shadow(color: lc.accent.opacity(0.4), radius: 9, y: 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buch per ISBN hinzufügen")
                            .lcType(.sheetTitle)
                            .foregroundStyle(lc.text)
                        Text("Titel, Autor und Cover werden übernommen.")
                            .lcType(.caption)
                            .foregroundStyle(lc.text2)
                    }
                }

                TextField("978-3-…", text: $model.isbnInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .tabularNums()
                    .foregroundStyle(lc.text)
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .glass(lc.glass, radius: Radius.l, border: lc.brd2)
                    .onSubmit(add)
                    .accessibilityIdentifier("field.isbn")

                if let message = model.lookupMessage {
                    Text(message)
                        .lcType(.captionS)
                        .foregroundStyle(lc.pink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lbl.isbnHint")
                }

                // Erscheint erst, wenn die Eingabe keine ISBN war — E-Books und
                // Selbstverlagstitel haben oft nur eine Amazon-Kennung.
                if model.needsManualEntry {
                    VStack(alignment: .leading, spacing: 8) {
                        plainField("Titel", text: $model.manualTitle, id: "field.manualTitle")
                        plainField("Verfasser", text: $model.manualAuthor, id: "field.manualAuthor")
                    }
                }

                HStack(spacing: 9) {
                    // Zweiter Weg zum selben Ziel: Strichcode statt Tippen.
                    Button {
                        model.isbnInput = ""
                        model.dialog = .scanner
                    } label: {
                        HStack(spacing: 6) {
                            LineSymbol(name: "barcode.viewfinder", size: 14, weight: .medium)
                            Text("Scannen")
                        }
                        .lcType(.caption)
                        .foregroundStyle(lc.text)
                        .padding(.horizontal, 14)
                        .frame(height: Metrics.controlDialog)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(lc.brd, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn.openScanner")

                    Spacer()
                    Button("Abbrechen") { close() }
                        .buttonStyle(.plain)
                        .lcType(.caption)
                        .foregroundStyle(lc.text2)
                        .padding(.horizontal, 14)
                        .frame(height: Metrics.controlDialog)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(lc.brd, lineWidth: 1)
                        }
                    Button(action: add) {
                        Text("Hinzufügen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(lc.accentInk)
                            .padding(.horizontal, 16)
                            .frame(height: Metrics.controlDialog)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(lc.accentGradient))
                            .shadow(color: lc.accent.opacity(0.34), radius: 11, y: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn.addISBN")
                }
            }
        }
    }

    private func plainField(_ label: String, text: Binding<String>, id: String) -> some View {
        TextField(label, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(lc.text)
            .padding(.horizontal, 13)
            .frame(height: 40)
            .glass(lc.glass, radius: Radius.l, border: lc.brd2)
            .onSubmit(add)
            .accessibilityIdentifier(id)
    }

    private func add() {
        if model.needsManualEntry {
            guard model.addBookManually(title: model.manualTitle, author: model.manualAuthor) != nil else { return }
            close()
            return
        }
        guard !model.isbnInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Bleibt der Dialog offen, war die Eingabe keine ISBN — dann steht jetzt die
        // Rückfrage nach Titel und Verfasser darin, und Schließen wäre Datenverlust.
        guard model.addBook(isbn: model.isbnInput) != nil else { return }
        close()
    }

    private func close() {
        model.isbnInput = ""
        model.manualTitle = ""
        model.manualAuthor = ""
        model.needsManualEntry = false
        model.lookupMessage = nil
        model.dialog = nil
    }
}

/// Import-Dialog (README §5.11).
struct ImportSheet: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel

    private var finished: Bool { model.importFinished != nil }

    var body: some View {
        SheetContainer(width: 506, topInset: 120) {
            VStack(alignment: .leading, spacing: Space.s4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aus Delicious Library importieren")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(lc.text)
                    Text(finished
                         ? "Import abgeschlossen. Bewertungen und Notizen wurden übernommen."
                         : "Bibliotheksdatei wählen. Bestehende Bücher werden anhand der ISBN abgeglichen.")
                        .lcType(.caption)
                        .foregroundStyle(lc.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                fileRow

                VStack(alignment: .leading, spacing: 7) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(lc.glass3)
                            Capsule()
                                .fill(LinearGradient(colors: [lc.cyan, lc.accent],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * model.importProgress)
                                .shadow(color: lc.accent.opacity(0.5), radius: 7)
                        }
                    }
                    .frame(height: 7)
                    .animation(.linear(duration: Motion.progress), value: model.importProgress)

                    Text(model.importError ?? model.importStatusLine)
                        .lcType(.captionS)
                        .tabularNums()
                        .foregroundStyle(model.importError == nil ? lc.text3 : lc.pink)
                        .accessibilityIdentifier("lbl.importStatus")
                }

                HStack(spacing: 9) {
                    Button(finished ? "Schließen" : "Abbrechen") { model.dialog = nil }
                        .buttonStyle(.plain)
                        .lcType(.caption)
                        .foregroundStyle(lc.text2)
                        .padding(.horizontal, 14)
                        .frame(height: Metrics.controlDialog)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(lc.brd, lineWidth: 1)
                        }
                    Spacer()
                    Button {
                        if finished { model.dialog = nil } else { Task { await model.runImport() } }
                    } label: {
                        Text(finished ? "Fertig" : (model.importRunning ? "Importiert …" : "Import starten"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(lc.accentInk)
                            .padding(.horizontal, 16)
                            .frame(height: Metrics.controlDialog)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(lc.accentGradient))
                            .opacity(model.importRunning ? 0.55 : 1)
                            .shadow(color: lc.accent.opacity(0.34), radius: 11, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.importRunning || model.importFile == nil)
                    .accessibilityIdentifier("btn.startImport")
                }
            }
        }
    }

    private var fileRow: some View {
        HStack(spacing: Space.s3) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x4FD8E8), Color(hex: 0x2E3FA8)],
                                     startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.9, y: 1)))
                .frame(width: 32, height: 42)
                .lcShadow(lc.shadowCover)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.importFile?.lastPathComponent ?? "Keine Datei gewählt")
                    .lcType(.caption)
                    .foregroundStyle(lc.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .lcType(.captionS)
                    .foregroundStyle(lc.text3)
            }
            Spacer(minLength: Space.s2)
            Button(model.importFile == nil ? "Datei wählen …" : "Andere Datei …") { chooseFile() }
                .buttonStyle(.plain)
                .lcType(.captionS)
                .foregroundStyle(lc.text2)
                .padding(.horizontal, 11)
                .frame(height: 29)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(lc.brd2, lineWidth: 1)
                }
                .accessibilityIdentifier("btn.chooseFile")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .glass(lc.glass, radius: Radius.s + 7, border: lc.brd)
    }

    private var subtitle: String {
        guard model.importFile != nil else { return "Delicious-Library-Export (XML)" }
        let entries = model.importEntryCount.map { "\(LCFormat.number($0)) Einträge" } ?? "Einträge unbekannt"
        let size = model.importFileSize.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        } ?? "–"
        return "\(entries) · \(size)"
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.xml, UTType(filenameExtension: "xml")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Importieren"
        if panel.runModal() == .OK, let url = panel.url {
            model.prepareImport(file: url)
        }
    }
}
