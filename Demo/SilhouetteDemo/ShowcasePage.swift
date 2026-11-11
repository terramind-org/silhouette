import Silhouette
import SwiftUI

/// The demo's home, after Skullet's landing page: the hero and a column of everyday cards, each
/// loading on its own and cascading in as one page.
struct ShowcasePage: View {
    @State private var hero = DemoLoad(latency: 0.95) { true }
    @State private var person = DemoLoad(latency: 0.9) { Person.real }
    @State private var article = DemoLoad(latency: 1.0) { Article.real }
    @State private var chat = DemoLoad(latency: 1.05) { ChatThread.real }
    @State private var notices = DemoLoad(latency: 0.95) { Notice.real }
    @State private var track = DemoLoad(latency: 1.1) { Track.real }
    @State private var stats = DemoLoad(latency: 1.15) { Stats.real }
    @State private var holdings = DemoLoad(latency: 1.2) { Holding.real }
    @State private var settings = DemoLoad(latency: 1.25) { SettingRow.real }
    @State private var gallery = DemoLoad(latency: 1.2) { Array(0..<6) }
    @State private var seed = 0
    @Binding var path: [DemoRoute]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Hero(path: $path)
                    .skeleton(isLoading: hero.value == nil, label: Text("Loading Silhouette"))
                    .padding(.top, 28)
                    .padding(.bottom, 18)

                card(person.reload) { Skeleton(person.value, sample: .sample) { ProfileRowCard(person: $0) } }
                card(article.reload) { Skeleton(article.value, sample: .sample) { ArticleCard(article: $0, imageURL: galleryURL(9, seed: seed)) } }
                card(chat.reload) { Skeleton(chat.value, sample: .sample) { ChatCard(thread: $0) } }
                card(notices.reload) { Skeleton(notices.value, sample: Notice.sample) { NotificationsCard(items: $0) } }
                card(track.reload) { Skeleton(track.value, sample: .sample) { TrackCard(track: $0) } }
                card(stats.reload) { Skeleton(stats.value, sample: .sample) { StatsCard(stats: $0) } }
                card(gallery.reload) { Skeleton(gallery.value, sample: Array(0..<6)) { GalleryCard(items: $0, seed: seed) } }
                card(holdings.reload) { Skeleton(holdings.value, sample: Holding.sample) { PortfolioCard(holdings: $0) } }
                card(settings.reload) { Skeleton(settings.value, sample: SettingRow.sample) { SettingsCard(rows: $0) } }

                Text("Tap a card to load it again")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary.opacity(0.8))
                    .padding(.vertical, 20)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .skeletonTracksScrolling()
        .background(Palette.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let every = UserDefaults.standard.double(forKey: "autoreload")
            guard every > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if !Task.isCancelled { reloadAll() }
            }
        }
    }

    private func card<C: View>(_ reload: @escaping () -> Void, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .contentShape(.rect)
            .onTapGesture(perform: reload)
            .accessibilityAction(named: "Reload", reload)
    }

    private func reloadAll() {
        seed += 1
        [hero.reload, person.reload, article.reload, chat.reload, notices.reload, track.reload, stats.reload, gallery.reload, holdings.reload, settings.reload].forEach { $0() }
    }
}

/// The profile row on its own card, as on Skullet's landing page.
struct ProfileRowCard: View {
    var person: Person

    var body: some View {
        Card { ProfileRow(person: person) }
    }
}

/// The name, the line under it, the links and the install line.
private struct Hero: View {
    @Binding var path: [DemoRoute]
    @State private var copied = false

    var body: some View {
        VStack(spacing: 14) {
            Logo().frame(width: 64, height: 64)
            VStack(spacing: 6) {
                Text("Silhouette").font(.system(size: 34, weight: .bold))
                Text("Skeletons traced from your layout")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 22) {
                Button("Features") { path.append(.index) }
                Button("Theming") { path.append(.theming) }
                Link("GitHub", destination: URL(string: "https://github.com/terramind-org/silhouette")!)
            }
            .font(.system(size: 16))
            .foregroundStyle(Palette.secondary)
            .buttonStyle(.plain)
            HStack(spacing: 18) {
                Text(".package(url: \"…/silhouette\")")
                    .font(.system(size: 14, design: .monospaced))
                    .lineLimit(1)
                Button(copied ? "Copied" : "Copy") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = ".package(url: \"https://github.com/terramind-org/silhouette.git\", from: \"0.1.0\")"
                    #endif
                    copied = true
                }
                .font(.system(size: 14))
                .foregroundStyle(Palette.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(Palette.inset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

/// A silhouette's head and shoulders over two lines of skeleton.
struct Logo: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            var head = Path()
            head.addEllipse(in: CGRect(x: s * 0.33, y: s * 0.08, width: s * 0.34, height: s * 0.34))
            var shoulders = Path()
            shoulders.addRoundedRect(in: CGRect(x: s * 0.16, y: s * 0.46, width: s * 0.68, height: s * 0.26), cornerSize: CGSize(width: s * 0.13, height: s * 0.13), style: .continuous)
            var line = Path()
            line.addRoundedRect(in: CGRect(x: s * 0.2, y: s * 0.8, width: s * 0.6, height: s * 0.09), cornerSize: CGSize(width: s * 0.045, height: s * 0.045))
            context.fill(head, with: .foreground)
            context.fill(shoulders, with: .foreground)
            context.fill(line, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
