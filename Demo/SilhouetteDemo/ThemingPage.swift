import Silhouette
import SwiftUI

/// Every theme option, live, over a dashboard, like the theming panel on Skullet's docs.
struct ThemingPage: View {
    @State private var stats = DemoLoad(latency: 1) { Stats.real }
    @State private var notices = DemoLoad(latency: 1.05) { Notice.real }
    @State private var preview: ColorScheme = .dark
    @State private var base = 8.0
    @State private var highlight = 10.0
    @State private var radius = "auto"
    @State private var top: SkeletonTextMetrics.Top = .capHeight
    @State private var bottom: SkeletonTextMetrics.Bottom = .descender
    @State private var animation: SkeletonAnimation = .shimmer
    @State private var speed = "slow"
    @State private var reveal = "smart"
    @State private var enter = "none"

    private var theme: SkeletonTheme {
        var theme = SkeletonTheme()
        theme.light = SkeletonColors(base: .black.opacity(base / 100), highlight: .white.opacity(min(1, highlight / 100 * 6)))
        theme.dark = SkeletonColors(base: .white.opacity(base / 100), highlight: .white.opacity(highlight / 100))
        theme.radius = switch radius { case "pill": .pill; case "4pt": .points(4); case "0pt": .points(0); default: .auto }
        theme.text = SkeletonTextMetrics(top: top, bottom: bottom)
        theme.animation = animation
        theme.speed = speed == "fast" ? .fast : .slow
        return theme
    }

    private var revealSpec: SkeletonReveal {
        var spec: SkeletonReveal = switch reveal { case "together": .together; case "sequence": .sequence; case "sweep": .sweep; default: .smart }
        let entrance: SkeletonReveal.Enter = switch enter { case "blur": .blur; case "rise": .rise; case "zoom": .zoom; default: .none }
        if let choose = spec.choose {
            spec.choose = { context in
                guard var chosen = choose(context) else { return nil }
                chosen.enter = entrance
                return chosen
            }
        } else {
            spec.enter = entrance
        }
        return spec
    }

    private func reload() { stats.reload(); notices.reload() }

    var body: some View {
        DemoPage(title: "Theming", note: "Colours for light and dark, radius, how much of each line is drawn, the animation and its speed, and the reveal.", reload: reload) {
            Reloadable(reload: reload) {
                VStack(spacing: 14) {
                    Skeleton(stats.value, sample: .sample) { StatsCard(stats: $0) }
                    Skeleton(notices.value, sample: Notice.sample) { NotificationsCard(items: $0) }
                }
                .skeletonTheme(theme)
                .skeletonReveal(revealSpec)
                .padding(12)
                .background(preview == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .environment(\.colorScheme, preview)
            }
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Choice(title: "Preview", selection: $preview, options: [(.light, "light"), (.dark, "dark")])
                    slider("Base", $base, 2...20)
                    slider("Highlight", $highlight, 0...30)
                    Choice(title: "Radius", selection: $radius, options: ["auto", "4pt", "0pt", "pill"].map { ($0, $0) })
                    Choice(title: "Text top", selection: $top, options: [(.ascender, "ascender"), (.capHeight, "cap height"), (.xHeight, "x-height")])
                    Choice(title: "Text bottom", selection: $bottom, options: [(.descender, "descender"), (.baseline, "baseline")])
                    Choice(title: "Animation", selection: $animation, options: [(.shimmer, "shimmer"), (.groupShimmer, "group"), (.pulse, "pulse"), (.none, "none")])
                    Choice(title: "Speed", selection: $speed, options: ["slow", "fast"].map { ($0, $0) })
                    Choice(title: "Reveal", selection: $reveal, options: ["smart", "together", "sequence", "sweep"].map { ($0, $0) })
                    Choice(title: "Enter", selection: $enter, options: ["none", "blur", "rise", "zoom"].map { ($0, $0) })
                }
            }
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) \(Int(value.wrappedValue))%").font(.system(size: 13)).foregroundStyle(Palette.secondary)
            Slider(value: value, in: range, step: 1).tint(Palette.accent)
        }
    }
}
