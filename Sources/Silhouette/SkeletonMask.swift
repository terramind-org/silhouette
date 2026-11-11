import CoreText
import SwiftUI

extension EnvironmentValues {
    /// Whether this view is being drawn as a skeleton's shape.
    ///
    /// Silhouette lays out a copy of your content to trace its skeleton. In that copy this is
    /// `true`. Check it to skip work a tracing copy shouldn't do, such as starting a download
    /// in `.task`:
    ///
    /// ```swift
    /// @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    /// ...
    /// .task { if !isDrawingSkeleton { await model.load() } }
    /// ```
    @Entry public var isDrawingSkeleton: Bool = false

    /// The colour a traced copy draws covered areas in: the opposite of the page.
    @Entry var skeletonInk: Color = .black
}

/// Draws its content as the shape of a skeleton: each line of text a bar, each image, control and
/// painted shape a block, everything else left out. The result is an opaque mask.
struct SkeletonShape<Content: View>: View {
    var content: Content

    @Environment(\.skeletonTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // The content is laid out by SwiftUI itself, in exactly the space the real content has,
        // then drawn into a canvas that turns anything painted at all into full coverage.
        GeometryReader { proxy in
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                guard let shape = context.resolveSymbol(id: SymbolID.content) else { return }
                let rect = CGRect(origin: .zero, size: size)
                // Over the page's colour, then measured by how far each pixel is from it.
                context.addFilter(.colorMatrix(Self.coverage(for: colorScheme)))
                context.drawLayer { layer in
                    layer.fill(Path(rect), with: .color(colorScheme == .dark ? .black : .white))
                    layer.draw(shape, in: rect)
                }
            } symbols: {
                content
                    .modifier(TextAsBars(metrics: theme.text, radius: theme.radius, ink: colorScheme == .dark ? .white : .black))
                    .environment(\.isDrawingSkeleton, true)
                    .environment(\.skeletonInk, colorScheme == .dark ? .white : .black)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .tag(SymbolID.content)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private enum SymbolID: Hashable { case content }

    /// Turns the traced copy into coverage: black, with alpha raised so faint text, tints and
    /// redacted lines count as solid while soft edges stay smooth.
    ///
    /// Surfaces close to the page's own colour (white cards in light mode, black ones in dark)
    /// are left out: they are containers, not content, so a card traces as its lines and
    /// pictures rather than one block. Mark any other container background with
    /// `skeletonIgnored()`.
    static func coverage(for scheme: ColorScheme) -> ColorMatrix {
        var m = ColorMatrix()
        m.r1 = 0; m.r2 = 0; m.r3 = 0; m.r4 = 0; m.r5 = 0
        m.g1 = 0; m.g2 = 0; m.g3 = 0; m.g4 = 0; m.g5 = 0
        m.b1 = 0; m.b2 = 0; m.b3 = 0; m.b4 = 0; m.b5 = 0
        // Everything is opaque over the page, so luminance alone says how far a pixel is from it.
        let k: Float = 16
        let (lr, lg, lb): (Float, Float, Float) = (0.2126, 0.7152, 0.0722)
        m.a4 = 0
        if scheme == .dark {
            // Covered where brighter than black.
            m.a1 = k * lr; m.a2 = k * lg; m.a3 = k * lb; m.a5 = -1.2
        } else {
            // Covered where darker than white.
            m.a1 = -k * lr; m.a2 = -k * lg; m.a3 = -k * lb; m.a5 = k - 1.2
        }
        return m
    }
}

/// Draws each line of text as one bar, trimmed to the theme's text metrics.
struct TextAsBars: ViewModifier {
    var metrics: SkeletonTextMetrics
    var radius: SkeletonRadius
    /// The colour bars are drawn in: the opposite of the page.
    var ink: Color

    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
            content.textRenderer(LineBarRenderer(metrics: metrics, radius: radius, ink: ink))
        } else {
            content.redacted(reason: .placeholder)
        }
    }
}

@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct LineBarRenderer: TextRenderer {
    var metrics: SkeletonTextMetrics
    var radius: SkeletonRadius
    var ink: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            guard let bar = Self.bar(for: line, metrics: metrics) else { continue }
            let r = radius.value(forHeight: bar.height)
            context.fill(Path(roundedRect: bar, cornerRadius: r, style: .continuous), with: .color(ink))
        }
    }

    /// The bar for one line: from its first glyph to its last, between the chosen metrics.
    static func bar(for line: Text.Layout.Line, metrics: SkeletonTextMetrics) -> CGRect? {
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let baseline = line.typographicBounds.origin.y
        for run in line {
            let b = run.typographicBounds
            guard b.width > 0 else { continue }
            minX = min(minX, b.rect.minX)
            maxX = max(maxX, b.rect.maxX)
            ascent = max(ascent, b.ascent)
            descent = max(descent, b.descent)
        }
        guard maxX > minX, ascent > 0 else { return nil }
        let rect = FontRatios.bar(baseline: baseline, ascent: ascent, descent: descent, metrics: metrics)
        return CGRect(x: minX, y: rect.minY, width: maxX - minX, height: rect.height)
    }
}

/// Where the cap height and x-height fall, as fractions of the ascent, read once from the
/// system font.
enum FontRatios {
    static let capHeight: CGFloat = ratios.cap
    static let xHeight: CGFloat = ratios.x

    private static let ratios: (cap: CGFloat, x: CGFloat) = {
        let font = CTFontCreateUIFontForLanguage(.system, 100, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 100, nil)
        let ascent = CTFontGetAscent(font)
        guard ascent > 0 else { return (0.74, 0.55) }
        return (CTFontGetCapHeight(font) / ascent, CTFontGetXHeight(font) / ascent)
    }()

    /// The vertical extent of a bar, given a line's baseline (y grows downwards) and metrics.
    static func bar(baseline: CGFloat, ascent: CGFloat, descent: CGFloat, metrics: SkeletonTextMetrics) -> CGRect {
        let topOffset: CGFloat = switch metrics.top {
        case .ascender: ascent
        case .capHeight: ascent * capHeight
        case .xHeight: ascent * xHeight
        }
        let bottomOffset: CGFloat = switch metrics.bottom {
        case .descender: descent
        case .baseline: 0
        }
        return CGRect(x: 0, y: baseline - topOffset, width: 0, height: topOffset + bottomOffset)
    }
}
