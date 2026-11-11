import Silhouette
import SwiftUI

// One page per section of Skullet's docs, plus its homepage showcase.

struct ShowcasePage: View {
    @State private var person = DemoLoad { Person.real }
    @State private var article = DemoLoad { Article.real }
    @State private var stats = DemoLoad { Stats.real }
    @State private var track = DemoLoad { Track.real }
    @State private var holdings = DemoLoad { Holding.real }
    @State private var settings = DemoLoad { SettingRow.real }
    @State private var thread = DemoLoad { Post.real }
    @State private var seed = 0

    var body: some View {
        DemoPage(title: "Showcase", mirrors: "the homepage demos", note: "Every card is its everyday view, wrapped once. Tap anywhere to load it all again.", reload: reload) {
            Skeleton(person.value, sample: .sample) { ProfileCard(person: $0) }
            Skeleton(article.value, sample: .sample) { ArticleCard(article: $0, imageURL: galleryURL(0, seed: seed)) }
            Skeleton(thread.value, sample: Post.sample) { ChatThread(posts: $0) }
            Skeleton(settings.value, sample: SettingRow.sample) { SettingsCard(rows: $0) }
            Skeleton(stats.value, sample: .sample) { StatsDashboard(stats: $0) }
            Skeleton(track.value, sample: .sample) { TrackCard(track: $0) }
            Skeleton(holdings.value, sample: Holding.sample) { PortfolioCard(holdings: $0) }
        }
    }

    private func reload() {
        seed += 1
        [person.reload, article.reload, stats.reload, track.reload, holdings.reload, settings.reload, thread.reload].forEach { $0() }
    }
}

struct FromComponentPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "From your component", mirrors: "<Skeleton data sample>", note: "Pass the data and a sample. The sample is laid out unseen and traced, so there's no second skeleton to keep in step.", reload: load.reload) {
            Skeleton(load.value, sample: .sample) { person in
                ProfileCard(person: person)
            }
            CodeNote("""
            Skeleton(user, sample: .sample) { user in
                ProfileCard(person: user)
            }
            """)
        }
    }
}

struct PlainChildrenPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "Plain children", mirrors: "<Skeleton loading>", note: "Toggle loading yourself and the view is measured as it is, here with a placeholder string while the name is missing.", reload: load.reload) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text(load.value?.name ?? "Placeholder name").font(.title2.bold())
                    Text(load.value?.bio ?? "A placeholder bio of about the usual length, for the skeleton to trace.")
                }
            }
            .skeleton(isLoading: load.value == nil)
            CodeNote("""
            Text(user?.name ?? "Placeholder name")
                ...
                .skeleton(isLoading: user == nil)
            """)
        }
    }
}

struct OwnSkeletonPage: View {
    @State private var load = DemoLoad { Stats.real }

    var body: some View {
        DemoPage(title: "Your own skeleton", mirrors: "Component.Skeleton, <SkeletonBox>", note: "Some things don't trace well, such as a chart. Draw your own skeleton from shapes or SkeletonBox; it joins the shared shimmer.", reload: load.reload) {
            Skeleton(load.value, sample: .sample) { stats in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Revenue").font(.headline)
                        WeekBars(values: stats.weeks).frame(height: 120)
                            .skeletonShape {
                                // Twelve bars of rising height, in place of the chart.
                                HStack(alignment: .bottom, spacing: 6) {
                                    ForEach(0..<12, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 4).frame(height: 30 + CGFloat(i) * 7)
                                    }
                                }
                                .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                    }
                }
            }
            HStack(spacing: 12) {
                SkeletonBox(width: 40, height: 40, radius: .pill)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBox(width: .fraction(0.7))
                    SkeletonBox(width: .fraction(0.4), height: .em(0.8))
                }
            }
            CodeNote("""
            WeekBars(values: stats.weeks)
                .skeletonShape { BarsPlaceholder() }

            SkeletonBox(width: 40, height: 40, radius: .pill)
            """)
        }
    }
}

struct HintsPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "Hints", mirrors: "skullet-block, skullet-ignore", note: "skeletonBlock() draws a view as one block; skeletonIgnored() leaves it out of the skeleton.", reload: load.reload) {
            Skeleton(load.value, sample: .sample) { person in
                Card {
                    HStack(spacing: 12) {
                        Avatar(initials: person.initials, color: .pink, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(person.name).font(.headline)
                                Text("New")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.green.opacity(0.2), in: Capsule())
                                    .skeletonIgnored()
                            }
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.caption) }
                            }
                            .foregroundStyle(.yellow)
                            .skeletonBlock(cornerRadius: 4)
                        }
                    }
                }
            }
            CodeNote("""
            Text("New").skeletonIgnored()
            Stars().skeletonBlock(cornerRadius: 4)
            """)
        }
    }
}

struct MemoryPage: View {
    @State private var load = DemoLoad { Post.real }
    @State private var forgot = false

    var body: some View {
        DemoPage(title: "Memory", mirrors: "id, forgetShapes()", note: "With an id, a reveal remembers the shape it showed, so the next skeleton is exact. Codable data keeps only its layout across launches.", reload: load.reload) {
            Skeleton(load.value, sample: Post.sample, id: "demo.feed") { Feed(posts: $0) }
            Button(forgot ? "Shapes forgotten" : "Forget shapes (as on sign-out)") {
                forgetSkeletonShapes()
                forgot = true
            }
            .buttonStyle(.bordered)
            CodeNote("""
            Skeleton(messages, id: "inbox") { Inbox(messages: $0) }

            forgetSkeletonShapes() // on sign-out
            """)
        }
    }
}

struct RevealModesPage: View {
    @State private var load = DemoLoad { Post.real }
    @State private var mode = "smart"

    private var reveal: SkeletonReveal {
        switch mode {
        case "together": .together
        case "sequence": .sequence
        case "sweep": .sweep
        default: .smart
        }
    }

    var body: some View {
        DemoPage(title: "Reveal modes", mirrors: "reveal: smart | together | sequence | sweep", note: "How content replaces its skeleton. Under smart, data that lands within 150 ms shows at once; set the response to fast to see it.", reload: load.reload) {
            Picker("Reveal", selection: $mode) {
                ForEach(["together", "sequence", "smart", "sweep"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            ResponsePicker()
            Skeleton(load.value, sample: Post.sample) { Feed(posts: $0) }
                .skeletonReveal(reveal)
        }
    }
}

struct ImagesPage: View {
    @State private var load = DemoLoad { Array(0..<6) }
    @State private var seed = 0

    var body: some View {
        DemoPage(title: "Images", mirrors: "images never hold a reveal back", note: "Each image keeps its own skeleton until it has loaded, then fades in, while the rest of the page reveals.", reload: { seed += 1; load.reload() }) {
            Skeleton(load.value, sample: Array(0..<6)) { items in
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(items, id: \.self) { i in
                        SkeletonAsyncImage(url: galleryURL(i, seed: seed)) { $0.resizable().scaledToFill() }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

struct ChangingSizePage: View {
    @State private var load = DemoLoad { Person.longer }

    var body: some View {
        DemoPage(title: "Changing size", mirrors: "the reveal eases to the new height", note: "The sample's bio is shorter than the real one. The card eases to its new height rather than snapping.", reload: load.reload) {
            Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
            Text("Content below moves smoothly with it.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct OwnRevealPage: View {
    @State private var load = DemoLoad { Post.real }
    @State private var choice = "blur"

    private var reveal: SkeletonReveal {
        switch choice {
        case "wipe":
            SkeletonReveal(wipe: .custom { p in
                let at = p * 1.2
                return .init(stops: [.init(color: .black, location: max(0, at - 0.2)), .init(color: .clear, location: min(1, max(at, 0.001)))])
            }, duration: 0.5)
        case "zoom":
            SkeletonReveal(order: .sequence(), enter: .zoom, duration: 0.6)
        default:
            SkeletonReveal(order: .sequence(), enter: SkeletonReveal.Enter(blur: 6), duration: 0.7)
        }
    }

    var body: some View {
        DemoPage(title: "Your own reveal", mirrors: "RevealSpec: order, enter, wipe, delay, duration, hold, choose", note: "Start from a built-in reveal and change what you need: a blur-in sequence, a wipe down, a zoom.", reload: load.reload) {
            Picker("Reveal", selection: $choice) {
                ForEach(["blur", "wipe", "zoom"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            Skeleton(load.value, sample: Post.sample) { Feed(posts: $0) }
                .skeletonReveal(reveal)
            CodeNote("""
            var blurIn = SkeletonReveal.sequence
            blurIn.enter = .init(blur: 6)
            content.skeletonReveal(blurIn)
            """)
        }
    }
}

struct AsyncPage: View {
    @State private var trigger = 0

    var body: some View {
        DemoPage(title: "AsyncSkeleton", mirrors: "<SkeletonSuspense>", note: "Give it the async work and the view. It runs the work, shows the skeleton while it waits, and reveals in place.", reload: { trigger += 1 }) {
            AsyncSkeleton(sample: Quote.sample, trigger: trigger) {
                try await Task.sleep(for: .seconds(Response.current.seconds))
                return Quote.real
            } content: { quote in
                QuoteCard(quote: quote)
            }
            CodeNote("""
            AsyncSkeleton(sample: .sample) {
                try await api.quote()
            } content: { QuoteCard(quote: $0) }
            """)
        }
    }
}

struct ShimmerTextPage: View {
    @State private var running = true

    var body: some View {
        DemoPage(title: "ShimmerText", mirrors: "— (native extra)", note: "A single loading line, such as an AI tool call that's running. It shares the skeletons' clock.", reload: { running.toggle() }) {
            VStack(alignment: .leading, spacing: 14) {
                Label { ShimmerText("Looking at your sleep", isActive: running) } icon: { Image(systemName: "moon.zzz") }
                Label { ShimmerText("Searching meals", isActive: running) } icon: { Image(systemName: "fork.knife") }
                Label { ShimmerText("Reading last week's runs", isActive: running) } icon: { Image(systemName: "figure.run") }
                HStack(spacing: 10) {
                    SkeletonBox(width: 28, height: 28, radius: .pill)
                    SkeletonBox(width: .fraction(0.6))
                }
            }
            .font(.callout)
            Text(running ? "Tap to finish" : "Tap to start").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct AccessibilityPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "Accessibility", mirrors: "aria-busy, label, prefers-reduced-motion", note: "While loading, VoiceOver reads one element, “Loading profile”, and never the sample. Reduce Motion turns the shimmer into a gentle pulse and every reveal into a short crossfade. Text follows Dynamic Type, and the skeleton follows the text.", reload: load.reload) {
            Skeleton(load.value, sample: .sample, label: Text("Loading profile")) { ProfileCard(person: $0) }
            Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
                .dynamicTypeSize(.xxLarge)
            Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
                .environment(\.colorScheme, .dark)
                .padding(12)
                .background(.black, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

struct DebugPage: View {
    @State private var load = DemoLoad { Person.longer }
    @State private var xray = false

    var body: some View {
        DemoPage(title: "Debugging", mirrors: "debug, ?skullet-debug, skullet-xray", note: "Outlines every loading region: blue while it loads with where its skeleton came from, then green if nothing moved or red with how far it did. X-ray shows the hidden content through the skeleton.", reload: load.reload) {
            Toggle("X-ray", isOn: $xray)
            Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
                .skeletonDebug(xray ? .all : .outlines)
            Skeleton(load.value, sample: .real) { ProfileCard(person: Person(name: $0.name, handle: $0.handle, role: $0.role, bio: Person.real.bio, initials: $0.initials)) }
                .skeletonDebug(xray ? .all : .outlines)
            CodeNote("""
            content.skeletonDebug(.outlines)
            // or launch with -SilhouetteDebug YES
            """)
        }
    }
}

/// A short code sample under a demo.
struct CodeNote: View {
    var code: String
    init(_ code: String) { self.code = code }

    var body: some View {
        Text(code)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {}
    }
}
