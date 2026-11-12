import Silhouette
import SwiftUI

// The everyday views the demos load. None of them knows about skeletons: each is wrapped once
// where it's used.

// MARK: - Palette

/// The demo's colours: a true-black page in dark mode, the grouped grey page in light.
enum Palette {
    static let page = Color.adaptive(light: Color(red: 0.95, green: 0.95, blue: 0.96), dark: .black)
    static let card = Color.adaptive(light: .white, dark: Color(white: 0.045))
    static let inset = Color.adaptive(light: Color(white: 0.955), dark: Color(white: 0.105))
    static let hairline = Color.adaptive(light: Color.black.opacity(0.07), dark: Color.white.opacity(0.08))
    static let secondary = Color.adaptive(light: Color(white: 0.45), dark: Color(white: 0.58))
    static let accent = Color(red: 0.96, green: 0.65, blue: 0.24)
    static let bubble = Color(red: 0.25, green: 0.45, blue: 0.96)

    static func gradient(for seed: String) -> LinearGradient {
        let pairs: [(Color, Color)] = [
            (Color(red: 0.98, green: 0.62, blue: 0.48), Color(red: 0.93, green: 0.36, blue: 0.55)),
            (Color(red: 0.44, green: 0.80, blue: 0.70), Color(red: 0.20, green: 0.55, blue: 0.80)),
            (Color(red: 0.73, green: 0.58, blue: 0.98), Color(red: 0.45, green: 0.38, blue: 0.92)),
            (Color(red: 0.99, green: 0.80, blue: 0.40), Color(red: 0.96, green: 0.52, blue: 0.27)),
            (Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.31, green: 0.47, blue: 0.95)),
        ]
        let pair = pairs[seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } % pairs.count]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        Color(NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light) })
        #endif
    }
}

// MARK: - Building blocks

/// A soft card on the page, like the ones on Skullet's landing page.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline))
    }
}

/// Initials on a soft gradient.
struct Avatar: View {
    var initials: String
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Palette.gradient(for: initials))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Profile

struct ProfileRow: View {
    var person: Person

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: person.initials, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.system(size: 17, weight: .medium))
                Text(person.handle).font(.system(size: 14)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 8)
            Button("Follow") {}
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)
        }
        .padding(12)
        .background(Palette.inset, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ProfileCard: View {
    var person: Person

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                ProfileRow(person: person)
                Text(person.bio)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Article

struct ArticleCard: View {
    var article: Article
    var imageURL: URL?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonAsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(article.title).font(.system(size: 20, weight: .semibold))
                Text(article.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.secondary)
                HStack(spacing: 8) {
                    Avatar(initials: String(article.author.split(separator: " ").compactMap(\.first)), size: 22)
                    Text(article.author).font(.system(size: 13, weight: .medium))
                    Text(article.readTime).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }
}

// MARK: - Card header

/// A card's title row, as on Skullet's comment list: a title, and a quiet detail or action.
struct CardHeader: View {
    var title: String
    var detail: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
            if let detail { Text(detail).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.secondary) }
            if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.secondary) }
        }
    }
}

// MARK: - Chat

struct ChatCard: View {
    var thread: ChatThread

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Avatar(initials: thread.initials, size: 38)
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(Color(red: 0.3, green: 0.8, blue: 0.5)).frame(width: 11, height: 11)
                                .overlay(Circle().strokeBorder(Palette.card, lineWidth: 2))
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(thread.name).font(.system(size: 16, weight: .semibold))
                        Text("Active now").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    HStack(spacing: 18) {
                        Image(systemName: "phone")
                        Image(systemName: "video")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                }
                VStack(spacing: 6) {
                    ForEach(thread.messages) { message in
                        HStack {
                            if message.mine { Spacer(minLength: 56) }
                            Text(message.text)
                                .font(.system(size: 15))
                                .foregroundStyle(message.mine ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(message.mine ? Palette.bubble : Palette.inset, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            if !message.mine { Spacer(minLength: 56) }
                        }
                    }
                    Text("Read 9:41").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.secondary)
                    Text("Message").font(.system(size: 15)).foregroundStyle(Palette.secondary)
                        .skeletonIgnored()
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(Palette.accent, in: Circle())
                }
                .padding(.leading, 14)
                .padding(.trailing, 5)
                .padding(.vertical, 5)
                .background(Palette.inset, in: Capsule())
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsCard: View {
    var items: [Notice]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: "Notifications", detail: "Mark all read")
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Avatar(initials: item.initials, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.name).font(.system(size: 15, weight: .semibold))
                                Text(item.time).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                                Spacer()
                                if index == 0 {
                                    Circle().fill(Palette.accent).frame(width: 8, height: 8).skeletonIgnored()
                                }
                            }
                            Text(item.text)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Music

struct TrackCard: View {
    var track: Track

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: "Now playing", systemImage: "airplayaudio")
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.48), Color(red: 0.93, green: 0.36, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .overlay(Image(systemName: "waveform").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white.opacity(0.9)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.system(size: 19, weight: .semibold))
                        Text(track.artist).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "heart").font(.system(size: 18)).foregroundStyle(Palette.secondary)
                }
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        Capsule().fill(Palette.inset)
                            .overlay(alignment: .leading) {
                                Capsule().fill(.primary).frame(width: proxy.size.width * track.progress)
                            }
                    }
                    .frame(height: 4)
                    HStack {
                        Text(track.elapsed)
                        Spacer()
                        Text(track.length)
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.secondary)
                }
                HStack {
                    Image(systemName: "shuffle").foregroundStyle(Palette.secondary)
                    Spacer()
                    Image(systemName: "backward.fill")
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 58, height: 58)
                        .background(Palette.accent, in: Circle())
                    Spacer()
                    Image(systemName: "forward.fill")
                    Spacer()
                    Image(systemName: "repeat").foregroundStyle(Palette.secondary)
                }
                .font(.system(size: 19))
                .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Stats

struct StatsCard: View {
    var stats: Stats

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: "Overview", detail: "12 weeks")
                HStack(alignment: .top) {
                    metric("Revenue", stats.revenue, stats.revenueChange)
                    Spacer()
                    metric("Customers", stats.customers, stats.customersChange)
                }
                WeekBars(values: stats.weeks)
                    .frame(height: 96)
                    // A chart traces as one block rather than twelve bars.
                    .skeletonBlock(cornerRadius: 12)
                HStack {
                    Text("Sep")
                    Spacer()
                    Text("Oct")
                    Spacer()
                    Text("Nov")
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ change: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13)).foregroundStyle(Palette.secondary)
            Text(value).font(.system(size: 26, weight: .semibold)).monospacedDigit()
            Text(change).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(red: 0.3, green: 0.8, blue: 0.5))
        }
    }
}

struct WeekBars: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(values.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(i == values.count - 1 ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.inset))
                        .frame(height: proxy.size.height * values[i])
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Portfolio

struct PortfolioCard: View {
    var holdings: [Holding]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: "Portfolio", systemImage: "ellipsis")
                VStack(alignment: .leading, spacing: 4) {
                    Text("$47,306.75").font(.system(size: 32, weight: .semibold)).monospacedDigit()
                    HStack(spacing: 6) {
                        Text("+$1,204.10").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 0.3, green: 0.8, blue: 0.5))
                        Text("today").font(.system(size: 14)).foregroundStyle(Palette.secondary)
                    }
                }
                Divider().overlay(Palette.hairline)
                ForEach(holdings) { h in
                    HStack(spacing: 12) {
                        Circle().fill(Palette.gradient(for: h.symbol)).frame(width: 36, height: 36)
                            .overlay(Text(String(h.symbol.prefix(1))).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.name).font(.system(size: 16, weight: .medium))
                            Text(h.amount).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(h.value).font(.system(size: 16, weight: .medium)).monospacedDigit()
                            Text(h.change).font(.system(size: 13)).foregroundStyle(h.up ? Color(red: 0.3, green: 0.8, blue: 0.5) : Color(red: 0.95, green: 0.4, blue: 0.4))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsCard: View {
    var rows: [SettingRow]

    var body: some View {
        Card(padding: 8) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "Settings")
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Palette.gradient(for: row.icon), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(row.title).font(.system(size: 16))
                        Spacer()
                        if let isOn = row.isOn {
                            Toggle(row.title, isOn: .constant(isOn)).labelsHidden().tint(Palette.accent)
                        } else {
                            Text(row.detail).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    if row != rows.last { Divider().overlay(Palette.hairline).padding(.leading, 52) }
                }
            }
        }
    }
}

// MARK: - Quote

struct QuoteCard: View {
    var quote: Quote

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Text(quote.text).font(.system(size: 22, weight: .medium))
                HStack(spacing: 10) {
                    Avatar(initials: String(quote.by.split(separator: " ").compactMap(\.first).prefix(2)), size: 28)
                    Text(quote.by).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }
}

// MARK: - Gallery

struct GalleryCard: View {
    var items: [Int?]

    var body: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Photos", detail: "See all")
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(items.indices, id: \.self) { i in
                    SkeletonAsyncImage(url: galleryURL(items[i])) { $0.resizable().scaledToFill() }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            }
        }
    }
}

/// A photo for a picture number. The sample has none, so its images wait as skeletons.
func galleryURL(_ picture: Int?) -> URL? {
    picture.flatMap { URL(string: "https://picsum.photos/seed/silhouette-\($0)/600/600") }
}

/// The gallery's pictures: a fresh set each load, so each one loads after its data.
enum Gallery {
    static let sample: [Int?] = Array(repeating: nil, count: 6)
    static func pictures() -> [Int?] { (0..<6).map { _ in Int.random(in: 0..<100_000) } }
}

extension Article {
    /// The real article with a fresh picture, which starts loading once this arrives.
    static func withPicture() -> Article {
        var article = Article.real
        article.picture = Int.random(in: 0..<100_000)
        return article
    }
}
