import SwiftUI

extension View {
    /// Draws this view's skeleton as one block filling its frame, rather than tracing what's
    /// inside it.
    ///
    /// Use it on things that trace badly, such as a chart, a map or a group of tiny glyphs.
    ///
    /// ```swift
    /// SparklineChart(points: points)
    ///     .skeletonBlock(cornerRadius: 8)
    /// ```
    public func skeletonBlock(cornerRadius: CGFloat = 0) -> some View {
        skeletonShape { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    }

    /// Leaves this view out of the skeleton. It still takes its space.
    ///
    /// ```swift
    /// Text("New").skeletonIgnored()
    /// ```
    public func skeletonIgnored() -> some View {
        modifier(SkeletonIgnored())
    }

    /// Draws your own skeleton for this view, in its frame, instead of tracing it.
    ///
    /// The shape you give joins the shared shimmer and follows the theme like every other
    /// skeleton. Build it from shapes or ``SkeletonBox``.
    ///
    /// ```swift
    /// Avatar(user: user)
    ///     .skeletonShape { Circle() }
    /// ```
    public func skeletonShape<S: View>(@ViewBuilder _ shape: @escaping () -> S) -> some View {
        modifier(SkeletonReplacement(shape: shape))
    }
}

private struct SkeletonIgnored: ViewModifier {
    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton

    func body(content: Content) -> some View {
        content.opacity(isDrawingSkeleton ? 0 : 1)
    }
}

private struct SkeletonReplacement<S: View>: ViewModifier {
    let shape: () -> S
    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    @Environment(\.skeletonInk) private var ink

    func body(content: Content) -> some View {
        content
            .opacity(isDrawingSkeleton ? 0 : 1)
            .overlay {
                if isDrawingSkeleton { shape().foregroundStyle(ink) }
            }
    }
}

/// A length for a ``SkeletonBox``.
public enum SkeletonLength: Sendable, Equatable, Hashable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    /// A fixed number of points.
    case points(CGFloat)
    /// A fraction of the width or height on offer, from 0 to 1.
    case fraction(CGFloat)
    /// A multiple of the body font's size, so it grows with Dynamic Type.
    case em(CGFloat)

    public init(integerLiteral value: Int) { self = .points(CGFloat(value)) }
    public init(floatLiteral value: Double) { self = .points(CGFloat(value)) }
}

/// One placeholder shape that joins the shared shimmer.
///
/// Use it for your own skeletons: in ``SwiftUICore/View/skeletonShape(_:)``, in a
/// ``Skeleton`` given a custom skeleton, or on its own. Every box shimmers in step with every
/// other skeleton on screen, however late it appears, and follows the theme's colours,
/// animation and Reduce Motion.
///
/// ```swift
/// SkeletonBox(width: 40, height: 40, radius: .pill)
/// SkeletonBox()                         // 60% wide, one line of body text tall
/// SkeletonBox(width: .fraction(1), height: .em(4), radius: .points(12))
/// ```
public struct SkeletonBox: View {
    public var width: SkeletonLength
    public var height: SkeletonLength
    public var radius: SkeletonRadius?

    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    @Environment(\.skeletonInk) private var ink
    @Environment(\.skeletonTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var em: CGFloat = 17

    /// - Parameters:
    ///   - width: 60% of the width on offer by default.
    ///   - height: One line of body text by default.
    ///   - radius: The theme's radius by default.
    public init(width: SkeletonLength = .fraction(0.6), height: SkeletonLength = .em(1), radius: SkeletonRadius? = nil) {
        self.width = width
        self.height = height
        self.radius = radius
    }

    public var body: some View {
        FractionalFrame(width: resolve(width), height: resolve(height)) {
            GeometryReader { proxy in
                let r = (radius ?? theme.radius).value(forHeight: min(proxy.size.height, proxy.size.width))
                let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
                if isDrawingSkeleton {
                    shape.fill(ink)
                } else {
                    ShimmerFill().clipShape(shape)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func resolve(_ length: SkeletonLength) -> FractionalFrame.Length {
        switch length {
        case .points(let p): .points(p)
        case .fraction(let f): .fraction(f)
        case .em(let e): .points(e * em)
        }
    }
}

/// Sizes its content to points or to a fraction of the space on offer.
struct FractionalFrame: Layout {
    enum Length: Equatable { case points(CGFloat), fraction(CGFloat) }

    var width: Length
    var height: Length

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: resolve(width, offered: proposal.width), height: resolve(height, offered: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }

    private func resolve(_ length: Length, offered: CGFloat?) -> CGFloat {
        switch length {
        case .points(let p): max(0, p)
        case .fraction(let f): max(0, (offered ?? 0) * min(max(f, 0), 1))
        }
    }
}

extension View {
    /// Shows this view as it is while its region loads: something bundled or fixed that never
    /// waits for data. It gets no skeleton and isn't part of the reveal.
    ///
    /// ``Skeleton`` finds such parts on its own for `Codable` data. Use this where it can't, for
    /// example with `.skeleton(isLoading:)`.
    public func skeletonKeep() -> some View {
        modifier(SkeletonKept())
    }
}

/// The frames of kept views, in their region's coordinates.
struct SkeletonKeepKey: PreferenceKey {
    static let space = "silhouette.region"
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

private struct SkeletonKept: ViewModifier {
    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton

    func body(content: Content) -> some View {
        // Left out of every traced copy, so it's neither a skeleton nor a piece of the reveal.
        content
            .opacity(isDrawingSkeleton ? 0 : 1)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: SkeletonKeepKey.self, value: isDrawingSkeleton ? [] : [proxy.frame(in: .named(SkeletonKeepKey.space))])
                }
            }
    }
}
