import SwiftUI

/// How content replaces its skeleton.
///
/// Pick a built-in reveal, or start from one and change what you need:
///
/// ```swift
/// ContentView()
///     .skeletonReveal(.smart)
///
/// var blurIn = SkeletonReveal.sequence
/// blurIn.enter = SkeletonReveal.Enter(blur: 6)
/// ContentView().skeletonReveal(blurIn)
/// ```
///
/// Whatever you choose, a reveal never moves the page: the content was laid out in the
/// skeleton's place all along. Delays and durations stop at one second. Under Reduce Motion
/// every reveal is instant.
public struct SkeletonReveal: Sendable {
    /// When each piece of the content arrives.
    public var order: Order
    /// Where the content starts from as it fades in.
    public var enter: Enter
    /// A mask that uncovers the content across its frame. When set, it replaces ``order``.
    public var wipe: Wipe?
    /// Seconds to wait before the reveal starts.
    public var delay: Double
    /// Seconds each piece takes to fade in, or the whole content for a reveal that comes in
    /// together. `0` is instant.
    public var duration: Double
    /// Seconds a skeleton waits before it shows at all, so data that arrives quickly never
    /// shows one.
    public var hold: Double
    /// Decides the reveal as the content lands. Return `nil` to keep this reveal.
    public var choose: (@Sendable (RevealContext) -> SkeletonReveal?)?

    public init(
        order: Order = .together,
        enter: Enter = .none,
        wipe: Wipe? = nil,
        delay: Double = 0,
        duration: Double = 0.2,
        hold: Double = 0,
        choose: (@Sendable (RevealContext) -> SkeletonReveal?)? = nil
    ) {
        self.order = order
        self.enter = enter
        self.wipe = wipe
        self.delay = delay
        self.duration = duration
        self.hold = hold
        self.choose = choose
    }

    // MARK: Built-in reveals

    /// The default. Decides for each reveal as it lands:
    ///
    /// - at once if the data beat the 150 ms hold (no skeleton ever showed) or someone is
    ///   scrolling,
    /// - a quick crossfade for a refetch,
    /// - whole for something small (under 72 points tall, or three pieces or fewer),
    /// - otherwise row by row, in screen order: rows arrive whole, smaller text a beat behind,
    ///   rows off screen at once. Regions that land together share one cascade down the screen.
    public static let smart = SkeletonReveal(hold: 0.15, choose: { context in
        if context.isInteracting || context.skeletonShownFor == nil { return .instant }
        if context.isRefetch { return SkeletonReveal(duration: 0.12) }
        if context.size.height < 72 || context.pieces <= 3 { return .together }
        return SkeletonReveal(order: .byRow)
    })

    /// Crossfades the whole skeleton into the content.
    public static let together = SkeletonReveal()

    /// Brings each piece in where its skeleton was, top to bottom, then a little left to right.
    public static let sequence = SkeletonReveal(order: .byPosition)

    /// Carries the content in behind one diagonal front, at the shimmer's slant and pace.
    /// Content taller than one and a half screens crossfades instead.
    public static let sweep = SkeletonReveal(wipe: .sweep, duration: 0.6)

    /// Swaps the skeleton for the content at once.
    public static let instant = SkeletonReveal(duration: 0)

    // MARK: Parts

    /// When each piece of the content arrives.
    ///
    /// A piece is one bar of text, one image, one control or one painted shape. Ordered reveals
    /// fade each piece in where its skeleton was, starting at the delay the order gives it.
    public enum Order: Sendable {
        /// Everything at once.
        case together
        /// Your own timing: seconds from the start of the reveal for each piece, or `nil` to show
        /// it at once. Delays stop at one second.
        case custom(@Sendable (RevealPiece) -> Double?)

        /// Top to bottom, then a little left to right, over 320 ms across the region.
        public static let byPosition = Order.custom(RevealPiece.byPosition)
        /// Row by row in screen order, over 320 ms down the screen; smaller text 60 ms behind;
        /// rows off screen at once.
        public static let byRow = Order.custom(RevealPiece.byRow)
    }

    /// Where content starts from as it fades in. Only what paints: blur, offset, scale and
    /// rotation. Nothing here changes layout.
    public struct Enter: Sendable, Equatable {
        public var blur: CGFloat
        public var offset: CGSize
        public var scale: CGFloat
        public var rotation: Angle

        public init(blur: CGFloat = 0, offset: CGSize = .zero, scale: CGFloat = 1, rotation: Angle = .zero) {
            self.blur = blur
            self.offset = offset
            self.scale = scale
            self.rotation = rotation
        }

        public static let none = Enter()
        /// Comes into focus.
        public static let blur = Enter(blur: 6)
        /// Rises a few points into place.
        public static let rise = Enter(offset: CGSize(width: 0, height: 6))
        /// Grows slightly into place.
        public static let zoom = Enter(scale: 0.97)
    }

    /// A mask that uncovers content across its frame as the reveal runs.
    public enum Wipe: Sendable {
        /// Follows the shimmer: the content appears behind its front, at its slant and pace.
        case sweep
        /// Your own mask for each moment of the reveal, from progress 0 to 1. Opaque stops show
        /// the content. The outgoing skeleton gets the inverse, or its own mask if you give one.
        case custom(@Sendable (Double) -> WipeMask, outgoing: (@Sendable (Double) -> WipeMask)? = nil)
    }

    /// One frame of a wipe: a gradient across the content.
    public struct WipeMask: Sendable, Equatable {
        public var stops: [Gradient.Stop]
        public var startPoint: UnitPoint
        public var endPoint: UnitPoint

        public init(stops: [Gradient.Stop], startPoint: UnitPoint = .top, endPoint: UnitPoint = .bottom) {
            self.stops = stops
            self.startPoint = startPoint
            self.endPoint = endPoint
        }
    }

    // MARK: Resolving

    var isOrdered: Bool {
        if wipe != nil { return false }
        if case .custom = order { return true }
        return false
    }

    /// The reveal to run for this context: `choose` applied, times capped at one second, and
    /// Reduce Motion made instant.
    func resolved(for context: RevealContext) -> SkeletonReveal {
        var spec = self
        if let choose, let chosen = choose(context) {
            spec = chosen
            spec.hold = hold
        }
        spec.choose = nil
        spec.delay = min(max(spec.delay, 0), 1)
        spec.duration = min(max(spec.duration, 0), 1)
        if context.reduceMotion { spec = .instant }
        return spec
    }
}

/// One piece of a reveal, for an ``SkeletonReveal/Order/custom(_:)`` order.
///
/// Rects are in screen coordinates.
public struct RevealPiece: Sendable, Equatable {
    /// The piece: one bar of text, one image, control or painted shape.
    public var rect: CGRect
    /// The whole region being revealed.
    public var reveal: CGRect
    /// The piece's row: the pieces around it that sit together vertically. `nil` if alone.
    public var unit: CGRect?
    /// Whether this is smaller text than the largest in its row, such as a caption under a name.
    public var isSecondary: Bool
    /// Seconds since the first of the reveals landing alongside this one began.
    public var late: Double
    /// The screen the reveal is on.
    public var screen: CGRect

    public init(rect: CGRect, reveal: CGRect, unit: CGRect?, isSecondary: Bool, late: Double, screen: CGRect) {
        self.rect = rect
        self.reveal = reveal
        self.unit = unit
        self.isSecondary = isSecondary
        self.late = late
        self.screen = screen
    }

    /// From the first piece of a cascade to the last.
    public static let cascadeSpread = 0.32
    /// How far behind its row smaller text arrives.
    public static let secondaryDelay = 0.06

    /// `sequence`'s order: each piece by its place in the reveal, top to bottom, then a little
    /// left to right.
    @Sendable public static func byPosition(_ piece: RevealPiece) -> Double? {
        let down = (piece.rect.minY - piece.reveal.minY) / max(piece.reveal.height, 1)
        let across = (piece.rect.minX - piece.reveal.minX) / max(piece.reveal.width, 1)
        return min(max(down * 0.8 + across * 0.2, 0), 1) * cascadeSpread
    }

    /// `smart`'s order: rows arrive whole, in screen order, on screen only, main text first.
    ///
    /// Timed against the screen rather than the region, so regions that land together read as
    /// one page cascading down.
    @Sendable public static func byRow(_ piece: RevealPiece) -> Double? {
        let screen = piece.screen
        guard let unit = piece.unit else { return onScreen(piece.rect, screen) ? 0 : nil }
        guard onScreen(unit, screen) else { return nil }
        let at = min(max((unit.minY - screen.minY) / max(screen.height, 1), 0), 1) * cascadeSpread
        return max(at - piece.late, 0) + (piece.isSecondary ? secondaryDelay : 0)
    }

    static func onScreen(_ rect: CGRect, _ screen: CGRect) -> Bool {
        rect.maxY > screen.minY && rect.minY < screen.maxY
    }
}

/// What a reveal knows as content lands, for ``SkeletonReveal/choose``.
public struct RevealContext: Sendable, Equatable {
    /// How long the skeleton was on screen, or `nil` if the data arrived before it showed.
    public var skeletonShownFor: Double?
    /// The size of the content arriving.
    public var size: CGSize
    /// How many pieces the skeleton had: bars, images, controls and shapes.
    public var pieces: Int
    /// Whether this content had loaded before and is loading again.
    public var isRefetch: Bool
    /// Whether someone scrolled in the last 400 ms. See ``SwiftUICore/View/skeletonTracksScrolling()``.
    public var isInteracting: Bool
    /// Whether Reduce Motion is on.
    public var reduceMotion: Bool

    public init(skeletonShownFor: Double?, size: CGSize, pieces: Int = 0, isRefetch: Bool, isInteracting: Bool = false, reduceMotion: Bool) {
        self.skeletonShownFor = skeletonShownFor
        self.size = size
        self.pieces = pieces
        self.isRefetch = isRefetch
        self.isInteracting = isInteracting
        self.reduceMotion = reduceMotion
    }
}

extension EnvironmentValues {
    /// How content below this view replaces its skeleton.
    @Entry public var skeletonReveal: SkeletonReveal = .smart
}

extension View {
    /// Sets how content replaces its skeleton, for every skeleton below this view.
    public func skeletonReveal(_ reveal: SkeletonReveal) -> some View {
        environment(\.skeletonReveal, reveal)
    }
}
