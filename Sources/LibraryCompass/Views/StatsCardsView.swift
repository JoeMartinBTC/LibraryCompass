import SwiftUI
import LibraryCompassCore

/// Die drei Statistik-Karten (README §5.4). Inhalte kürzen, statt zu überlaufen.
struct StatsCardsView: View {
    @Environment(\.lc) private var lc
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let gap = 14.0
            let unit = max(0, (geo.size.width - 2 * gap)) / 3.32
            HStack(alignment: .top, spacing: gap) {
                LibraryCard(stats: model.stats)
                    .frame(width: unit * 1.32, height: geo.size.height)
                RatingsCard(stats: model.stats)
                    .frame(width: unit, height: geo.size.height)
                RecentCard(books: model.recentlyRead) { model.selection = $0 }
                    .frame(width: unit, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(height: 196)
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s4)
    }
}

private struct CardSurface: ViewModifier {
    @Environment(\.lc) private var lc
    let deco: AnyView?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Space.s5)
            .padding(.vertical, Space.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { deco }
            .glass(lc.glass, radius: Radius.card, border: lc.brd, blurred: true)
            .lcShadow(lc.shadowCard)
    }
}

private extension View {
    func statCard(deco: AnyView? = nil) -> some View { modifier(CardSurface(deco: deco)) }
}

private struct LibraryCard: View {
    @Environment(\.lc) private var lc
    let stats: LibraryStats

    var body: some View {
        HStack(spacing: Space.s5) {
            ProgressRing(percent: stats.readPercent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Meine Bibliothek")
                    .lcType(.caption)
                    .foregroundStyle(lc.text2)
                    .lineLimit(1)
                Text(LCFormat.number(stats.total))
                    .lcType(.heroNumber)
                    .tabularNums()
                    .foregroundStyle(lc.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("▲").font(.system(size: 9))
                    Text("\(LCFormat.number(stats.readCount)) gelesen")
                        .lcType(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(lc.mint)
                ReadBar(read: stats.readCount, total: stats.total)
                    .frame(maxWidth: 230)
                    .padding(.top, 6)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .statCard(deco: AnyView(
            Circle()
                .fill(RadialGradient(colors: [lc.cyan.opacity(0.30), .clear],
                                     center: .center, startRadius: 0, endRadius: 115))
                .frame(width: 230, height: 230)
                .offset(x: 70, y: -80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        ))
    }
}

private struct ProgressRing: View {
    @Environment(\.lc) private var lc
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(lc.glass3, lineWidth: Metrics.ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(AngularGradient(colors: [lc.cyan, lc.accent],
                                        center: .center,
                                        startAngle: .degrees(0),
                                        endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: Metrics.ringWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .lcShadow(lc.ringGlow)
            VStack(spacing: 0) {
                Text("\(percent) %")
                    .lcType(.ringValue)
                    .tabularNums()
                    .foregroundStyle(lc.text)
                Text("Gelesen")
                    .lcType(.label)
                    .foregroundStyle(lc.text3)
            }
        }
        .frame(width: Metrics.ringSize, height: Metrics.ringSize)
    }
}

private struct ReadBar: View {
    @Environment(\.lc) private var lc
    let read: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let fraction = total == 0 ? 0 : CGFloat(read) / CGFloat(total)
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [lc.mint, lc.cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * fraction - 1))
                RoundedRectangle(cornerRadius: 4).fill(lc.glass3)
            }
        }
        .frame(height: 7)
    }
}

private struct RatingsCard: View {
    @Environment(\.lc) private var lc
    let stats: LibraryStats

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Eigene Bewertungen")
                .lcType(.caption)
                .foregroundStyle(lc.text2)
                .lineLimit(1)
            Text(LCFormat.number(stats.ratedCount))
                .lcType(.statNumber)
                .tabularNums()
                .foregroundStyle(lc.text)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(LCFormat.stars(Int(stats.averageRating.rounded())))
                    .font(.system(size: 11))
                    .tracking(1)
                    .foregroundStyle(lc.gold)
                Text("Ø \(LCFormat.average(stats.averageRating))")
                    .lcType(.captionS)
                    .tabularNums()
                    .foregroundStyle(lc.text3)
                    .lineLimit(1)
            }
            VStack(spacing: 4) {
                ForEach(stats.distribution, id: \.stars) { bar in
                    DistributionRow(bar: bar, maximum: stats.distribution.map(\.count).max() ?? 1)
                }
            }
            .padding(.top, 6)
        }
        .statCard()
    }
}

private struct DistributionRow: View {
    @Environment(\.lc) private var lc
    let bar: RatingBar
    let maximum: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(String(repeating: "★", count: bar.stars))
                .font(.system(size: 10.5))
                .foregroundStyle(lc.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(lc.glass3)
                    Capsule()
                        .fill(LinearGradient(colors: [lc.gold, lc.pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(bar.count) / CGFloat(max(1, maximum)))
                }
            }
            .frame(height: 5)
            Text(LCFormat.number(bar.count))
                .font(.system(size: 10.5))
                .tabularNums()
                .foregroundStyle(lc.text3)
                .frame(width: 30, alignment: .trailing)
                .lineLimit(1)
        }
    }
}

private struct RecentCard: View {
    @Environment(\.lc) private var lc
    let books: [Book]
    let select: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Zuletzt gelesen")
                .lcType(.caption)
                .foregroundStyle(lc.text2)
                .lineLimit(1)
            VStack(spacing: 7) {
                ForEach(books) { book in
                    RecentRow(book: book) { select(book) }
                }
            }
            .padding(.top, 10)
        }
        .statCard(deco: AnyView(
            Circle()
                .fill(RadialGradient(colors: [lc.pink.opacity(0.26), .clear],
                                     center: .center, startRadius: 0, endRadius: 95))
                .frame(width: 190, height: 190)
                .offset(x: 60, y: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        ))
    }
}

private struct RecentRow: View {
    @Environment(\.lc) private var lc
    let book: Book
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CoverView(book: book, width: 20, radius: 3, showsLabels: false, spineWidth: 2)
                    .lcShadow(lc.shadowCover)
                Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                    .font(.system(size: 12))
                    .foregroundStyle(lc.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                Text(LCFormat.date(book.readDate))
                    .font(.system(size: 11))
                    .tabularNums()
                    .foregroundStyle(lc.text3)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? lc.glass2 : .clear))
        .onHover { hovering = $0 }
    }
}
