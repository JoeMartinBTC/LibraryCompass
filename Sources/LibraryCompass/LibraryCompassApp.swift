import AppKit
import SwiftData
import SwiftUI
import LibraryCompassCore

@main
struct LibraryCompassApp: App {
    @State private var model: AppModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        LaunchOptions.resetPreferencesIfTesting()
        let container = LaunchOptions.makeContainer()
        _model = State(initialValue: AppModel(context: ModelContext(container)))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 920)
        .commands {
            // Beides muss in *eine* Gruppe: `replacing:` leert die Gruppe, ein
            // zusätzliches `after:` auf dieselbe Gruppe verschwindet mit ihr —
            // dann gibt es die Menüpunkte nicht und Cmd-K bleibt unbelegt.
            CommandGroup(replacing: .newItem) {
                Button("Buch scannen …") { model.dialog = .scanner }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Buch per ISBN …") { model.dialog = .isbn }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Bibliothek exportieren …") { model.exportLibrary() }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Alle als gelesen markieren") { model.markAllAsRead() }
            }
        }
    }
}

/// Startoptionen: `--uitest` nutzt einen leeren Store mit Demo-Büchern,
/// `--screenshot <pfad>` schreibt einen Fenster-Schnappschuss und beendet die App.
enum LaunchOptions {
    static var isUITest: Bool { CommandLine.arguments.contains("--uitest") }

    /// Vorgabezustand für Schnappschüsse: `--state list|detail|isbn|import|empty`.
    static var state: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--state"),
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `--fetch-covers` holt Cover für den vorhandenen Bestand nach und beendet die App.
    static var fetchesCovers: Bool { CommandLine.arguments.contains("--fetch-covers") }

    /// `--fetch-isbns` schlägt fehlende ISBNs über Titel und Verfasser nach und beendet die App.
    static var fetchesISBNs: Bool { CommandLine.arguments.contains("--fetch-isbns") }

    /// `--fetch-authors` trägt fehlende Verfasser nach und beendet die App.
    static var fetchesAuthors: Bool { CommandLine.arguments.contains("--fetch-authors") }

    /// `--apply-covers <datei>` trägt von Hand geprüfte Cover ein und beendet die App.
    static var applyCoversPath: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--apply-covers"),
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `--apply-authors <datei>` setzt oder leert Verfasser und beendet die App.
    static var applyAuthorsPath: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--apply-authors"),
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `--mark-read` trägt bei allen Büchern ohne Gelesen-Datum das Erfassungsdatum ein.
    static var marksRead: Bool { CommandLine.arguments.contains("--mark-read") }

    /// `--export <pfad>` schreibt die Bibliothek als CSV und beendet die App.
    static var exportPath: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--export"),
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }

    static var screenshotPath: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--screenshot"),
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// Test- und Schnappschuss-Läufe starten immer mit den Standard-Einstellungen.
    static func resetPreferencesIfTesting() {
        guard isUITest || screenshotPath != nil else { return }
        let defaults = UserDefaults.standard
        for key in ["view", "sort", "sidebarOpen", "sidebarWidth", "statsOpen", "zoom"] {
            defaults.removeObject(forKey: key)
        }
        // Zustände für die Design-Abnahme
        switch state {
        case "wide": defaults.set(400.0, forKey: "sidebarWidth")
        case "nostats": defaults.set(false, forKey: "statsOpen")
        default: break
        }
        if let index = CommandLine.arguments.firstIndex(of: "--appearance"),
           CommandLine.arguments.count > index + 1 {
            defaults.set(CommandLine.arguments[index + 1], forKey: "appearance")
        }
    }

    static func makeContainer() -> ModelContainer {
        if isUITest || screenshotPath != nil {
            let container = try! LibraryStore.inMemoryContainer()
            seed(ModelContext(container))
            return container
        }
        if let container = try? LibraryStore.defaultContainer() { return container }
        return try! LibraryStore.inMemoryContainer()
    }

    /// Demo-Bestand für UI-Test und Schnappschuss — die echte Bibliothek bleibt unangetastet.
    private static func seed(_ context: ModelContext) {
        let titles: [(String, String, Int, Int, Int, Bool)] = [
            ("Der Schwarm", "Frank Schätzing", 4, 2004, 995, true),
            ("Die Vermessung der Welt", "Daniel Kehlmann", 5, 2005, 302, true),
            ("Tschick", "Wolfgang Herrndorf", 5, 2010, 254, true),
            ("Der Steppenwolf", "Hermann Hesse", 3, 1927, 288, false),
            ("Unendlicher Spaß", "David Foster Wallace", 4, 1996, 1552, false),
            ("Die Känguru-Chroniken", "Marc-Uwe Kling", 4, 2009, 208, true),
            ("Schuld", "Ferdinand von Schirach", 3, 2010, 208, false),
            ("Kleine Feuer überall", "Celeste Ng", 0, 2017, 384, false)
        ]
        var day = DateComponents(year: 2026, month: 1, day: 3)
        for (index, item) in titles.enumerated() {
            day.day = 3 + index
            let book = Book(isbn: "97831234567\(index)0",
                            title: item.0,
                            author: item.1,
                            rating: item.2,
                            comment: item.5 ? "Kurze Notiz." : "",
                            readDate: item.5 ? Calendar.current.date(from: day) : nil,
                            addedDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400),
                            year: item.3,
                            pages: item.4)
            context.insert(book)
        }
        try? context.save()
    }
}

/// Schreibt im Schnappschuss-Modus ein PNG des Fensters (ohne Bildschirmaufnahme-Rechte).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let path = LaunchOptions.applyAuthorsPath {
            Task { @MainActor in
                exit(Self.applyAuthors(from: path) ? 0 : 1)
            }
            return
        }

        if let path = LaunchOptions.applyCoversPath {
            Task { @MainActor in
                exit(await Self.applyCovers(from: path) ? 0 : 1)
            }
            return
        }

        if LaunchOptions.fetchesCovers || LaunchOptions.fetchesISBNs || LaunchOptions.fetchesAuthors {
            Task { @MainActor in
                let complete: Bool
                if LaunchOptions.fetchesAuthors {
                    complete = await Self.fetchAuthors()
                } else if LaunchOptions.fetchesISBNs {
                    complete = await Self.fetchISBNs()
                } else {
                    complete = await Self.fetchCovers()
                }
                // Unvollständiger Lauf muss sich am Exit-Code zeigen — am 2026-08-08
                // endete er bei 1188 von 1780 und meldete trotzdem Erfolg.
                exit(complete ? 0 : 1)
            }
            return
        }

        if LaunchOptions.marksRead || LaunchOptions.exportPath != nil {
            Task { @MainActor in
                Self.runStoreCommands()
                NSApp.terminate(nil)
            }
            return
        }

        guard let path = LaunchOptions.screenshotPath else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            Self.capture(to: path)
            NSApp.terminate(nil)
        }
    }

    /// Gelesen-Markierung und Export ohne Fenster — für Pflegeläufe auf dem echten Store.
    @MainActor
    static func runStoreCommands() {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return
        }
        let context = ModelContext(container)

        if LaunchOptions.marksRead {
            print("als gelesen markiert: \(ReadDates.markAllAsRead(in: context))")
        }
        if let path = LaunchOptions.exportPath {
            let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
            do {
                try LibraryExport.csv(books).write(toFile: path, atomically: true, encoding: .utf8)
                print("exportiert: \(books.count) Bücher → \(path)")
            } catch {
                FileHandle.standardError.write(Data("Export fehlgeschlagen: \(error)\n".utf8))
            }
        }
        fflush(stdout)
    }

    /// Ein Pflegelauf darf nicht daran sterben, dass jemand das Fenster schließt.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !LaunchOptions.fetchesCovers && !LaunchOptions.fetchesISBNs && !LaunchOptions.fetchesAuthors
            && LaunchOptions.applyCoversPath == nil
    }

    /// Trägt von Hand geprüfte Cover ein. Jede Zeile nennt ein Buch; ein leeres zweites
    /// Feld nimmt ein falsches Cover zurück.
    @MainActor
    static func applyCovers(from path: String) async -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            FileHandle.standardError.write(Data("Zuweisungsdatei nicht lesbar: \(path)\n".utf8))
            return false
        }
        do {
            let report = try await CoverAssignment.apply(CoverAssignment.parse(text),
                                                         context: ModelContext(container)) { done, total, title in
                print("[\(done)/\(total)] \(title)")
                fflush(stdout)
            }
            for problem in report.problems { print("übergangen — \(problem)") }
            print(report.summary)
            fflush(stdout)
            return report.isComplete
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — Zuweisung gescheitert: \(error)\n".utf8))
            return false
        }
    }

    /// Setzt oder leert Verfasser aus einer Datei — der Weg zurück, wenn ein Nachlauf
    /// danebengriff.
    @MainActor
    static func applyAuthors(from path: String) -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            FileHandle.standardError.write(Data("Zuweisungsdatei nicht lesbar: \(path)\n".utf8))
            return false
        }
        do {
            let report = try AuthorAssignment.apply(CoverAssignment.parse(text),
                                                    context: ModelContext(container)) { done, total, title in
                print("[\(done)/\(total)] \(title)")
                fflush(stdout)
            }
            for problem in report.problems { print("übergangen — \(problem)") }
            print(report.summary)
            fflush(stdout)
            return report.isComplete
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — Verfasser-Zuweisung gescheitert: \(error)\n".utf8))
            return false
        }
    }

    /// Trägt fehlende Verfasser nach. Erst danach darf für diese Bücher die Titelsuche
    /// laufen — ohne Verfasser fehlt ihr der Anker.
    @MainActor
    static func fetchAuthors() async -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        do {
            let report = try await AuthorBackfill.run(context: ModelContext(container)) { done, total, title in
                print("[\(done)/\(total)] \(title)")
                fflush(stdout)
            }
            print(report.summary)
            fflush(stdout)
            return report.isComplete
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — Verfasser-Nachlauf gescheitert: \(error)\n".utf8))
            return false
        }
    }

    /// Schlägt fehlende ISBNs nach. Erst danach greift für diese Bücher die
    /// ausgabegenaue Cover-Kette.
    @MainActor
    static func fetchISBNs() async -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        let context = ModelContext(container)
        do {
            let report = try await ISBNBackfill.run(context: context) { done, total, title in
                print("[\(done)/\(total)] \(title)")
                fflush(stdout)
            }
            print(report.summary)
            fflush(stdout)
            return report.isComplete
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — ISBN-Nachlauf gescheitert: \(error)\n".utf8))
            return false
        }
    }

    /// Cover-Nachlauf über den echten Store, sequenziell — Fortschritt auf die Konsole.
    /// Ergebnis sagt, ob jedes vorgesehene Buch tatsächlich gefragt wurde.
    @MainActor
    static func fetchCovers() async -> Bool {
        guard let container = try? LibraryStore.defaultContainer() else {
            FileHandle.standardError.write(Data("Store nicht lesbar\n".utf8))
            return false
        }
        let context = ModelContext(container)
        do {
            let report = try await CoverBackfill.run(context: context) { done, total, title in
                print("[\(done)/\(total)] \(title)")
                fflush(stdout)
            }
            print(report.summary)
            fflush(stdout)
            return report.isComplete
        } catch {
            FileHandle.standardError.write(Data("ABBRUCH — Nachlauf gescheitert: \(error)\n".utf8))
            return false
        }
    }

    @MainActor
    static func capture(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else {
            FileHandle.standardError.write(Data("kein Fenster\n".utf8))
            return
        }
        window.setContentSize(NSSize(width: 1440, height: 920))
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        guard let view = window.contentView else { return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            FileHandle.standardError.write(Data("kein BitmapRep\n".utf8))
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("keine PNG-Daten\n".utf8))
            return
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            FileHandle.standardError.write(Data("Schnappschuss: \(path) (\(data.count) Bytes)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("Schreibfehler: \(error)\n".utf8))
        }
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
    @Bindable var model: AppModel
    @AppStorage("appearance") private var appearance = Appearance.auto.rawValue

    var body: some View {
        ThemedRoot(model: model, appearance: $appearance)
            .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
            .onAppear { applyLaunchState() }
    }

    private func applyLaunchState() {
        switch LaunchOptions.state {
        case "list": model.viewMode = .list
        case "detail", "wide": model.selection = model.rows.first
        case "isbn": model.dialog = .isbn
        case "scan": model.dialog = .scanner
        case "import": model.dialog = .importer
        case "empty": model.search = "zzzz"
        default: break
        }
    }
}

/// Löst das Farbschema (System oder manuell) in ein `LCTheme` auf und legt es in die Umgebung.
private struct ThemedRoot: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: AppModel
    @Binding var appearance: String

    var body: some View {
        LibraryView(model: model, appearance: $appearance)
            .environment(\.lc, colorScheme == .dark ? .dark : .light)
    }
}
