import SwiftUI

/// Platzhalter für das Bibliotheks-Fenster (Meilenstein 1: nur der Verlaufsgrund).
struct LibraryView: View {
    @Environment(\.lc) private var lc

    var body: some View {
        ZStack {
            BackgroundLayers()
            Text("LibraryCompass")
                .lcType(.screenTitle)
                .foregroundStyle(lc.text)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
