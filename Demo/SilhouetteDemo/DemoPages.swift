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

struct RevealModesPage: View {
    @State private var chat = DemoLoad(latency: 1) { ChatThread.real }
    @State private var notices = DemoLoad(latency: 1.05) { Notice.real }
    @State private var comments = DemoLoad(latency: 0.95) { Comment.real }
    /// `-mode sweep` opens on a mode, for recordings.
    @State private var mode = UserDefaults.standard.string(forKey: "mode") ?? "smart"

    private var reveal: SkeletonReveal {
        switch mode {
        case "together": .together
        case "sequence": .sequence
        case "sweep": .sweep
        default: .smart
        }
    }

    private func reload() { comments.reload(); chat.reload(); notices.reload() }

    var body: some View {
        DemoPage(title: "Reveal modes", note: "How content replaces its skeleton. Under smart, data that lands within 150 ms shows at once: set the response to fast to see it.", reload: reload) {
            Choice(title: "Reveal", selection: $mode, options: ["together", "sequence", "smart", "sweep"].map { ($0, $0) })
            ResponsePicker()
            Reloadable(reload: reload) {
                VStack(spacing: 14) {
                    Skeleton(comments.value, sample: Comment.sample) { CommentsCard(comments: $0) }
                    Skeleton(notices.value, sample: Notice.sample) { NotificationsCard(items: $0) }
                    Skeleton(chat.value, sample: .sample) { ChatCard(thread: $0) }
                }
                .skeletonReveal(reveal)
            }
        }
    }
}

struct ImagesPage: View {
    @State private var load = DemoLoad { (0..<9).map { _ in Optional(Int.random(in: 0..<100_000)) } }

    var body: some View {
        DemoPage(title: "Images", note: "Images never hold a reveal back. Each keeps its own skeleton until it has loaded, then fades in.", reload: load.reload) {
            Reloadable(reload: load.reload) {
                Skeleton(load.value, sample: Array(repeating: nil, count: 9)) { GalleryCard(items: $0) }
            }
        }
    }
}

struct OwnRevealPage: View {
    @State private var load = DemoLoad { Notice.real }
    /// `-own unveil` opens on a reveal, for recordings.
    @State private var choice = UserDefaults.standard.string(forKey: "own") ?? "blur"

    private var reveal: SkeletonReveal {
        switch choice {
        case "wipe":
            SkeletonReveal(wipe: .custom { p in
                let at = p * 1.2
                return .init(stops: [.init(color: .black, location: max(0, at - 0.2)), .init(color: .clear, location: min(1, max(at, 0.001)))])
            }, duration: 0.5)
        case "focus":
            // A wipe down with an effect: the content clears from a blur as the front passes.
            SkeletonReveal(wipe: .custom({ p in
                let at = p * 1.2
                return .init(stops: [.init(color: .black, location: max(0, at - 0.2)), .init(color: .clear, location: min(1, max(at, 0.001)))])
            }, effect: { p in SkeletonReveal.Enter(blur: 8 * (1 - p), scale: 0.98 + 0.02 * p) }), duration: 0.6)
        case "unveil":
            SkeletonReveal(order: .byPosition, enter: .unveil, duration: 0.35)
        case "zoom":
            SkeletonReveal(order: .byPosition, enter: .zoom, duration: 0.3)
        default:
            SkeletonReveal(order: .byPosition, enter: SkeletonReveal.Enter(blur: 6), duration: 0.3)
        }
    }

    var body: some View {
        DemoPage(title: "Your own reveal", note: "Every built-in is a SkeletonReveal. Start from one and change what you need: a blur-in sequence, a wipe down, a wipe that clears a blur, an unveil, a zoom.", reload: load.reload) {
            Choice(title: "Reveal", selection: $choice, options: ["blur", "wipe", "focus", "unveil", "zoom"].map { ($0, $0) })
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

