import SwiftUI

/// How every skeleton below a view looks and moves.
///
/// Set one with ``SwiftUICore/View/skeletonTheme(_:)`` near the root of your app, or change a
/// single option for one part of the screen with ``SwiftUICore/View/skeletonTheme(_:)-(_)``:
///
/// ```swift
/// ContentView()
///     .skeletonTheme(SkeletonTheme(animation: .shimmer, speed: .slow, radius: .pill))
///
/// Sidebar()
///     .skeletonTheme { $0.speed = .fast }
/// ```
public struct SkeletonTheme: Sendable, Equatable {
    /// The fill and highlight in light mode.
    public var light: SkeletonColors
    /// The fill and highlight in dark mode.
    public var dark: SkeletonColors
    /// How skeletons move while they wait.
    public var animation: SkeletonAnimation
    /// How long one pass of the shimmer, or one breath of the pulse, takes.
    public var speed: SkeletonSpeed
    /// Which way the shimmer travels.
    public var direction: ShimmerDirection
    /// The width of the shimmer's highlight, in points. `nil` takes 40% of the screen's width,
    /// between 80 and 320 points, so it doesn't grow heavier on a wide screen.
    public var bandWidth: CGFloat?
    /// How round each line of text is drawn.
    public var radius: SkeletonRadius
    /// How much of each line of text is drawn.
    public var text: SkeletonTextMetrics
    /// Forces light or dark colours for skeletons. `nil` follows the system.
    public var colorScheme: ColorScheme?
    /// What skeletons do when Reduce Motion is on. They hold still by default.
    public var reducedMotion: SkeletonReducedMotion

    public init(
        light: SkeletonColors = .defaultLight,
        dark: SkeletonColors = .defaultDark,
        animation: SkeletonAnimation = .shimmer,
        speed: SkeletonSpeed = .slow,
        direction: ShimmerDirection = .angle(.degrees(20)),
        bandWidth: CGFloat? = nil,
        radius: SkeletonRadius = .auto,
        text: SkeletonTextMetrics = SkeletonTextMetrics(),
        colorScheme: ColorScheme? = nil,
        reducedMotion: SkeletonReducedMotion = .holdStill
    ) {
        self.light = light
        self.dark = dark
        self.animation = animation
        self.speed = speed
        self.direction = direction
        self.bandWidth = bandWidth
        self.radius = radius
        self.text = text
        self.colorScheme = colorScheme
        self.reducedMotion = reducedMotion
    }

    /// The theme skeletons use when you set none.
    public static let `default` = SkeletonTheme()

    /// The colours for a colour scheme.
    public func colors(for scheme: ColorScheme) -> SkeletonColors {
        (colorScheme ?? scheme) == .dark ? dark : light
    }
}

/// A skeleton's fill, and the highlight that passes over it.
public struct SkeletonColors: Sendable, Equatable {
    /// The skeleton's resting fill.
    public var base: Color
    /// The colour of the shimmer's band, or of the pulse at its peak, drawn over the base.
    public var highlight: Color

    public init(base: Color, highlight: Color) {
        self.base = base
        self.highlight = highlight
    }

    /// Ink at 7% with a paler sheen, for light backgrounds.
    public static let defaultLight = SkeletonColors(base: .black.opacity(0.07), highlight: .white.opacity(0.6))
    /// White at 8% with a brighter sheen, for dark and true-black backgrounds.
    public static let defaultDark = SkeletonColors(base: .white.opacity(0.08), highlight: .white.opacity(0.10))

    /// Builds colours from one tint: the base at `base` opacity and the highlight `highlight` brighter.
    public static func tinted(_ color: Color, base: Double = 0.08, highlight: Double = 0.10) -> SkeletonColors {
        SkeletonColors(base: color.opacity(base), highlight: color.opacity(highlight))
    }
}

/// How skeletons move while they wait.
public enum SkeletonAnimation: Sendable, Equatable, CaseIterable {
    /// A band of highlight sweeps across the screen. Every skeleton shares one band, so they
    /// shimmer in step however late each one appeared.
    case shimmer
    /// Like ``shimmer``, but the band sweeps across each loading region on its own, from edge
    /// to edge, still in step with every other region.
    case groupShimmer
    /// Every skeleton breathes together, brightening and fading.
    case pulse
    /// Skeletons hold still.
    case none
}

/// What skeletons do when Reduce Motion is on.
public enum SkeletonReducedMotion: Sendable, Equatable, Hashable, CaseIterable {
    /// Skeletons hold still: the base colour, with no highlight moving over it.
    case holdStill
    /// A slow, quiet pulse in place of any travelling band. Nothing moves across the screen.
    case pulse
}

/// How fast skeletons move.
///
/// A shimmer keeps the pace it has across a 1280-point screen on any width, so a wide window
/// doesn't make it race: one loop takes 4 s when slow and 2 s when fast. A pulse breathes in
/// 2.4 s or 1.2 s.
public enum SkeletonSpeed: Sendable, Equatable, Hashable {
    case slow
    case normal
    case fast
    /// One shimmer loop across a 1280-point screen, or one pulse, in this many seconds.
    case seconds(Double)

    /// One shimmer loop across a 1280-point screen, in seconds.
    public var shimmerLoop: Double {
        switch self {
        case .slow: 4
        case .normal: 3
        case .fast: 2
        case .seconds(let s): max(0.2, s)
        }
    }

    /// One pulse, in seconds.
    public var pulseLoop: Double {
        switch self {
        case .slow: 2.4
        case .normal: 1.8
        case .fast: 1.2
        case .seconds(let s): max(0.2, s)
        }
    }
}

/// Which way the shimmer's band travels.
public enum ShimmerDirection: Sendable, Equatable, Hashable {
    /// Leading to trailing: left to right, or right to left in a right-to-left language.
    case leadingToTrailing
    case trailingToLeading
    case topToBottom
    case bottomToTop
    /// Travels along this angle, measured clockwise from left-to-right.
    case angle(Angle)

    func unitVector(layoutDirection: LayoutDirection) -> CGVector {
        let radians: Double
        switch self {
        case .leadingToTrailing: radians = layoutDirection == .rightToLeft ? .pi : 0
        case .trailingToLeading: radians = layoutDirection == .rightToLeft ? 0 : .pi
        case .topToBottom: radians = .pi / 2
        case .bottomToTop: radians = -.pi / 2
        case .angle(let a): radians = layoutDirection == .rightToLeft ? .pi - a.radians : a.radians
        }
        return CGVector(dx: cos(radians), dy: sin(radians))
    }
}

/// How round each line of text is drawn.
public enum SkeletonRadius: Sendable, Equatable, Hashable {
    /// A gentle rounding in proportion to the line's height.
    case auto
    /// A fixed corner radius, in points.
    case points(CGFloat)
    /// Fully round ends.
    case pill
    /// A share of the shape's height, like a percentage radius: `0.5` is a pill.
    case fraction(CGFloat)

    func value(forHeight height: CGFloat) -> CGFloat {
        switch self {
        case .auto: min(height / 2, max(2, height * 0.28))
        case .points(let r): min(height / 2, max(0, r))
        case .pill: height / 2
        case .fraction(let f): min(height / 2, max(0, height * f))
        }
    }
}

/// How much of each line of text is drawn, from a top edge down to a bottom edge.
///
/// Drawn from the real glyph metrics on iOS 18, macOS 15, watchOS 11, tvOS 18 and visionOS 2
/// and later. Earlier systems draw the line the way SwiftUI redacts text.
public struct SkeletonTextMetrics: Sendable, Equatable, Hashable {
    public enum Top: Sendable, Equatable, Hashable, CaseIterable {
        /// The top of tall letters such as "h" and "l".
        case ascender
        /// The top of capitals.
        case capHeight
        /// The top of lowercase letters such as "x".
        case xHeight
    }

    public enum Bottom: Sendable, Equatable, Hashable, CaseIterable {
        /// The bottom of letters such as "g" and "p".
        case descender
        /// The line the letters sit on.
        case baseline
    }

    public var top: Top
    public var bottom: Bottom

    /// Cap height to descender by default. SwiftUI sets lines with no extra leading, so a bar
    /// from ascender to descender would touch the next line's and the lines would merge.
    public init(top: Top = .capHeight, bottom: Bottom = .descender) {
        self.top = top
        self.bottom = bottom
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The theme skeletons below this view use.
    @Entry public var skeletonTheme: SkeletonTheme = .default
}

extension View {
    /// Sets the theme for every skeleton below this view.
    public func skeletonTheme(_ theme: SkeletonTheme) -> some View {
        environment(\.skeletonTheme, theme)
    }

    /// Changes some of the theme for every skeleton below this view, keeping the rest.
    ///
    /// ```swift
    /// Sidebar().skeletonTheme { $0.speed = .fast }
    /// ```
    public func skeletonTheme(_ transform: @escaping (inout SkeletonTheme) -> Void) -> some View {
        transformEnvironment(\.skeletonTheme, transform: transform)
    }

    /// Sets how much of each line of text is drawn, for every skeleton below this view,
    /// whatever the theme says.
    ///
    /// ```swift
    /// CompactList().skeletonText(SkeletonTextMetrics(top: .xHeight, bottom: .baseline))
    /// ```
    public func skeletonText(_ text: SkeletonTextMetrics) -> some View {
        transformEnvironment(\.skeletonTheme) { $0.text = text }
    }
}
