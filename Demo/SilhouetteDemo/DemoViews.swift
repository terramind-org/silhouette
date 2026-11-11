import Silhouette
import SwiftUI

// The everyday views the demos load. None of them knows about skeletons.

struct ProfileCard: View {
    var person: Person

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Avatar(initials: person.initials, color: Palette.color(for: person.initials), size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(.headline)
                        Text(person.handle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Follow") {}
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                }
                Text(person.bio).font(.body)
            }
        }
    }
}

struct PostRow: View {
    var post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(initials: post.initials, color: Palette.color(for: post.initials), size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(post.author).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(post.time).font(.caption).foregroundStyle(.secondary)
                }
                Text(post.role).font(.caption).foregroundStyle(.secondary)
                Text(post.text).font(.subheadline).padding(.top, 2)
            }
        }
    }
}

struct Feed: View {
    var posts: [Post]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(posts) { PostRow(post: $0) }
            }
        }
    }
}

struct ArticleCard: View {
    var article: Article
    var imageURL: URL?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonAsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(article.title).font(.title2.weight(.bold))
                Text(article.summary).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Avatar(initials: String(article.author.prefix(1)), color: .teal, size: 24)
                    Text(article.author).font(.footnote.weight(.medium))
                    Text("·").foregroundStyle(.tertiary)
                    Text(article.readTime).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatsDashboard: View {
    var stats: Stats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                stat("Revenue", stats.revenue, stats.revenueChange)
                stat("Customers", stats.customers, stats.customersChange)
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Revenue").font(.headline)
                    Text("Last 12 weeks").font(.caption).foregroundStyle(.secondary)
                    WeekBars(values: stats.weeks)
                        .frame(height: 90)
                        // A chart traces as one block rather than twelve bars.
                        .skeletonBlock(cornerRadius: 10)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Activity").font(.headline)
                    ForEach(stats.activity, id: \.self) { line in
                        Label(line, systemImage: "circle.fill")
                            .labelStyle(DotLabel())
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ change: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Text(change).font(.caption.weight(.medium)).foregroundStyle(.green)
            }
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
                        .fill(Color.accentColor.gradient)
                        .frame(height: proxy.size.height * values[i])
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 6)).foregroundStyle(.tint)
            configuration.title
        }
    }
}

struct TrackCard: View {
    var track: Track

    var body: some View {
        Card {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.85)))
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title).font(.headline)
                    Text("\(track.artist) — \(track.album)").font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: track.progress)
                    HStack {
                        Text(track.elapsed)
                        Spacer()
                        Text(track.remaining)
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PortfolioCard: View {
    var holdings: [Holding]

    var body: some View {
        Card {
            VStack(spacing: 14) {
                ForEach(holdings) { h in
                    HStack(spacing: 12) {
                        Circle().fill(Palette.color(for: h.symbol).gradient).frame(width: 34, height: 34)
                            .overlay(Text(String(h.symbol.prefix(1))).font(.caption.bold()).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.name).font(.subheadline.weight(.semibold))
                            Text(h.amount).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(h.value).font(.subheadline.weight(.semibold)).monospacedDigit()
                            Text(h.change).font(.caption).foregroundStyle(h.up ? .green : .red)
                        }
                    }
                }
            }
        }
    }
}

struct SettingsCard: View {
    var rows: [SettingRow]

    var body: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.icon)
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Text(row.title)
                        Spacer()
                        if let isOn = row.isOn {
                            Toggle(row.title, isOn: .constant(isOn)).labelsHidden()
                        } else {
                            Text(row.detail).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 8)
                    if row != rows.last { Divider().padding(.leading, 42) }
                }
            }
        }
    }
}

struct ChatThread: View {
    var posts: [Post]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(posts.enumerated()), id: \.element.id) { i, post in
                let mine = i % 2 == 1
                HStack {
                    if mine { Spacer(minLength: 48) }
                    Text(post.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(mine ? .white : .primary)
                        .background(mine ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if !mine { Spacer(minLength: 48) }
                }
            }
        }
    }
}

struct QuoteCard: View {
    var quote: Quote

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(quote.text)”").font(.title3.weight(.medium))
                Text(quote.by).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

func galleryURL(_ i: Int, seed: Int) -> URL? {
    URL(string: "https://picsum.photos/seed/silhouette-\(seed)-\(i)/400/400")
}
