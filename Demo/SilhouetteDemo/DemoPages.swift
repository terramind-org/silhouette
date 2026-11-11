import Silhouette
import SwiftUI

// One page per section of Skullet's docs.

struct FromComponentPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "From your view", note: "Pass the data and a sample of it. Your view is built from the sample, traced unseen, and only ever receives real data.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
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
    @State private var load = DemoLoad { Article.real }

    var body: some View {
        DemoPage(title: "Any view, with a flag", note: "Say when it's loading, and the view is measured as it is, here with placeholder strings while the data is missing.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(load.value?.title ?? "A headline of usual length").font(.system(size: 22, weight: .semibold))
                        Text(load.value?.summary ?? "A standfirst of about the usual length, for the skeleton to trace.")
                            .font(.system(size: 16)).foregroundStyle(Palette.secondary)
                    }
                }
                .skeleton(isLoading: load.value == nil)
            }
            CodeNote("""
            Text(article?.title ?? "A headline of usual length")
            ...
            .skeleton(isLoading: article == nil)
            """)
        }
    }
}

struct OwnSkeletonPage: View {
    @State private var load = DemoLoad { Stats.real }

    var body: some View {
        DemoPage(title: "Your own skeleton", note: "Some things don't trace well, like a chart. Draw your own from shapes or SkeletonBox, and it joins the shared shimmer.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: .sample) { stats in
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Revenue").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                            Text(stats.revenue).font(.system(size: 28, weight: .semibold))
                            WeekBars(values: stats.weeks)
                                .frame(height: 120)
                                .skeletonShape {
                                    HStack(alignment: .bottom, spacing: 6) {
                                        ForEach(0..<12, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .frame(height: 34 + CGFloat(i) * 7)
                                        }
                                    }
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                }
                        }
                    }
                }
            }
            Card {
                HStack(spacing: 12) {
                    SkeletonBox(width: 44, height: 44, radius: .pill)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBox(width: .fraction(0.7))
                        SkeletonBox(width: .fraction(0.4), height: .em(0.8))
                    }
                }
            }
            CodeNote("""
            WeekBars(values: stats.weeks)
                .skeletonShape { RisingBars() }

            SkeletonBox(width: 44, height: 44, radius: .pill)
            """)
        }
    }
}

struct HintsPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "Hints", note: "skeletonBlock() draws a view as one block. skeletonIgnored() leaves it out.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: .sample) { person in
                    Card {
                        HStack(spacing: 12) {
                            Avatar(initials: person.initials, size: 48)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(person.name).font(.system(size: 17, weight: .medium))
                                    Text("New")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.black.opacity(0.8))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Palette.accent, in: Capsule())
                                        .skeletonIgnored()
                                }
                                HStack(spacing: 3) {
                                    ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 12)) }
                                }
                                .foregroundStyle(Palette.accent)
                                .skeletonBlock(cornerRadius: 4)
                            }
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
    @State private var load = DemoLoad { Notice.real }
    @State private var forgot = false

    var body: some View {
        DemoPage(title: "Memory", note: "With an id, a reveal remembers the shape it showed, so the next skeleton is exact. Codable data keeps only its layout across launches.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: Notice.sample, id: "demo.inbox") { NotificationsCard(items: $0) }
            }
            Button(forgot ? "Shapes forgotten" : "Forget shapes, as on sign-out") {
                forgetSkeletonShapes()
                forgot = true
            }
            .buttonStyle(.bordered)
            .tint(Palette.accent)
            CodeNote("""
            Skeleton(inbox, sample: .samples, id: "inbox") { Inbox($0) }

            forgetSkeletonShapes() // on sign-out
            """)
        }
    }
}

struct RevealModesPage: View {
    @State private var chat = DemoLoad(latency: 1) { ChatThread.real }
    @State private var notices = DemoLoad(latency: 1.05) { Notice.real }
    @State private var mode = "smart"

    private var reveal: SkeletonReveal {
        switch mode {
        case "together": .together
        case "sequence": .sequence
        case "sweep": .sweep
        default: .smart
        }
    }

    private func reload() { chat.reload(); notices.reload() }

    var body: some View {
        DemoPage(title: "Reveal modes", note: "How content replaces its skeleton. Under smart, data that lands within 150 ms shows at once: set the response to fast to see it.", reload: reload) {
            Choice(title: "Reveal", selection: $mode, options: ["together", "sequence", "smart", "sweep"].map { ($0, $0) })
            ResponsePicker()
            Reloadable(reload: reload) {
                VStack(spacing: 14) {
                    Skeleton(notices.value, sample: Notice.sample) { NotificationsCard(items: $0) }
                    Skeleton(chat.value, sample: .sample) { ChatCard(thread: $0) }
                }
                .skeletonReveal(reveal)
            }
        }
    }
}

struct ImagesPage: View {
    @State private var load = DemoLoad { Array(0..<9) }
    @State private var seed = 100

    var body: some View {
        DemoPage(title: "Images", note: "Images never hold a reveal back. Each keeps its own skeleton until it has loaded, then fades in.", reload: { seed += 1; load.reload() }) {
            Reloadable(reload: { seed += 1; load.reload() }) {
                Skeleton(load.value, sample: Array(0..<9)) { GalleryCard(items: $0, seed: seed) }
            }
        }
    }
}

struct ChangingSizePage: View {
    @State private var load = DemoLoad { Person.longer }

    var body: some View {
        DemoPage(title: "Changing size", note: "The sample's bio is shorter than the real one. The card eases to its new height rather than snapping.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
            }
            Card { Text("Everything below moves smoothly with it.").font(.system(size: 15)).foregroundStyle(Palette.secondary) }
        }
    }
}

struct OwnRevealPage: View {
    @State private var load = DemoLoad { Notice.real }
    @State private var choice = "blur"

    private var reveal: SkeletonReveal {
        switch choice {
        case "wipe":
            SkeletonReveal(wipe: .custom { p in
                let at = p * 1.2
                return .init(stops: [.init(color: .black, location: max(0, at - 0.2)), .init(color: .clear, location: min(1, max(at, 0.001)))])
            }, duration: 0.5)
        case "zoom":
            SkeletonReveal(order: .byPosition, enter: .zoom, duration: 0.3)
        default:
            SkeletonReveal(order: .byPosition, enter: SkeletonReveal.Enter(blur: 6), duration: 0.3)
        }
    }

    var body: some View {
        DemoPage(title: "Your own reveal", note: "Every built-in is a SkeletonReveal. Start from one and change what you need: a blur-in sequence, a wipe down, a zoom.", reload: load.reload) {
            Choice(title: "Reveal", selection: $choice, options: ["blur", "wipe", "zoom"].map { ($0, $0) })
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: Notice.sample) { NotificationsCard(items: $0) }
                    .skeletonReveal(reveal)
            }
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
        DemoPage(title: "AsyncSkeleton", note: "Give it the async work and the view. It runs the work, shows the skeleton while it waits, and reveals in place.", reload: { trigger += 1 }) {
            Reloadable(reload: { trigger += 1 }) {
                AsyncSkeleton(sample: Quote.sample, trigger: trigger) {
                    try await Task.sleep(for: .seconds(Response.current.seconds))
                    return Quote.real
                } content: { quote in
                    QuoteCard(quote: quote)
                }
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
        DemoPage(title: "ShimmerText", note: "One loading line, such as an AI tool call that's running. It keeps the skeletons' clock.", reload: { running.toggle() }) {
            Reloadable(caption: running ? "Tap to finish" : "Tap to start", reload: { running.toggle() }) {
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        line("moon.zzz.fill", "Looking at your sleep")
                        line("fork.knife", "Searching meals")
                        line("figure.run", "Reading last week's runs")
                    }
                }
            }
        }
    }

    private func line(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(Palette.secondary).frame(width: 22)
            ShimmerText(title, isActive: running).font(.system(size: 16))
        }
    }
}

struct AccessibilityPage: View {
    @State private var load = DemoLoad { Person.real }

    var body: some View {
        DemoPage(title: "Accessibility", note: "While loading, VoiceOver reads one element, “Loading profile”, and never the sample. Under Reduce Motion skeletons hold still and reveals are instant. The skeleton follows Dynamic Type.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: .sample, label: Text("Loading profile")) { ProfileCard(person: $0) }
            }
            Reloadable(caption: "Extra extra large text", reload: load.reload) {
                Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
                    .dynamicTypeSize(.xxxLarge)
            }
        }
    }
}

struct DebugPage: View {
    @State private var load = DemoLoad { Person.longer }
    @State private var xray = false

    var body: some View {
        DemoPage(title: "Debugging", note: "Outlines every loading region: blue while it loads with where its skeleton came from, then green if nothing moved or red with how far it did.", reload: load.reload) {
            Toggle("X-ray", isOn: $xray).tint(Palette.accent)
            Reloadable(reload: load.reload) {
                VStack(spacing: 22) {
                    Skeleton(load.value, sample: .sample) { ProfileCard(person: $0) }
                    Skeleton(load.value, sample: .longer) { ProfileCard(person: $0) }
                }
                .skeletonDebug(xray ? .all : .outlines)
            }
            CodeNote("""
            content.skeletonDebug(.outlines)
            // or launch with -SilhouetteDebug YES
            """)
        }
    }
}
