import Silhouette
import SwiftUI

/// Every theme option, live, over a dashboard, like the theming panel on Skullet's site.
struct ThemingPage: View {
    @State private var load = DemoLoad { Stats.real }
    @State private var preview: ColorScheme = .light
    @State private var base = 8.0
    @State private var highlight = 10.0
    @State private var radius = "auto"
    @State private var top: SkeletonTextMetrics.Top = .capHeight
    @State private var bottom: SkeletonTextMetrics.Bottom = .descender
    @State private var animation: SkeletonAnimation = .shimmer
    @State private var speed = "normal"
    @State private var direction = "angled"
    @State private var reveal = "smart"
    @State private var enter = "none"

    private var theme: SkeletonTheme {
        var theme = SkeletonTheme()
        theme.light = SkeletonColors(base: .black.opacity(base / 100), highlight: .white.opacity(min(1, highlight / 100 * 5.5)))
        theme.dark = SkeletonColors(base: .white.opacity(base / 100 * 1.25), highlight: .white.opacity(highlight / 100))
        theme.radius = switch radius { case "pill": .pill; case "4pt": .points(4); case "0pt": .points(0); default: .auto }
        theme.text = SkeletonTextMetrics(top: top, bottom: bottom)
        theme.animation = animation
        theme.speed = switch speed { case "slow": .slow; case "fast": .fast; default: .normal }
        theme.direction = switch direction { case "top": .topToBottom; case "leading": .leadingToTrailing; default: .angle(.degrees(20)) }
        return theme
    }

    private var revealSpec: SkeletonReveal {
        var spec: SkeletonReveal = switch reveal { case "together": .together; case "sequence": .sequence; case "sweep": .sweep; default: .smart }
        let enterSpec: SkeletonReveal.Enter = switch enter { case "blur": .blur; case "rise": .rise; case "zoom": .zoom; default: .none }
        if enter != "none" {
            // An enter needs a reveal that runs: keep smart's choice, with this entrance.
            if let choose = spec.choose {
                spec.choose = { context in
                    guard var chosen = choose(context), chosen.duration > 0 else { return choose(context) }
                    chosen.enter = enterSpec
                    return chosen
                }
            } else {
                spec.enter = enterSpec
            }
        }
        return spec
    }

    var body: some View {
        DemoPage(title: "Theming", mirrors: "<SkulletProvider theme mode reveal>", note: "Colours per scheme, radius, how much of each line is drawn, animation, speed and direction, and the reveal.", reload: load.reload) {
            Skeleton(load.value, sample: .sample) { StatsDashboard(stats: $0) }
                .skeletonTheme(theme)
                .skeletonReveal(revealSpec)
                .padding(12)
                .background(preview == .dark ? Color.black : Color(white: 0.97), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .environment(\.colorScheme, preview)

            controls
                .onTapGesture {}
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("Preview") { segmented($preview, [(ColorScheme.light, "light"), (.dark, "dark")]) }
            row("Base \(Int(base))%") { Slider(value: $base, in: 2...20, step: 1) }
            row("Highlight \(Int(highlight))%") { Slider(value: $highlight, in: 0...30, step: 1) }
            row("Radius") { segmented($radius, ["auto", "4pt", "0pt", "pill"].map { ($0, $0) }) }
            row("Text top") { segmented($top, [(.ascender, "ascender"), (.capHeight, "cap"), (.xHeight, "x-height")]) }
            row("Text bottom") { segmented($bottom, [(.descender, "descender"), (.baseline, "baseline")]) }
            row("Animation") { segmented($animation, [(.shimmer, "shimmer"), (.groupShimmer, "group"), (.pulse, "pulse"), (.none, "none")]) }
            row("Speed") { segmented($speed, ["slow", "normal", "fast"].map { ($0, $0) }) }
            row("Direction") { segmented($direction, ["leading", "top", "angled"].map { ($0, $0) }) }
            row("Reveal") { segmented($reveal, ["smart", "together", "sequence", "sweep"].map { ($0, $0) }) }
            row("Enter") { segmented($enter, ["none", "blur", "rise", "zoom"].map { ($0, $0) }) }
        }
        .font(.subheadline)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            control()
        }
    }

    private func segmented<T: Hashable>(_ selection: Binding<T>, _ options: [(T, String)]) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
