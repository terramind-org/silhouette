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
    /// Seconds each piece's wipe takes, or the whole crossfade for a reveal that comes in
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
        duration: Double = 0.3,
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
    /// - otherwise row by row down the screen, one beat apart, each piece wiping in where its
    ///   skeleton was. Reveals that land within 150 ms of each other share one cascade, so
    ///   separate cards come in as one page. Rows off screen appear at once.
    public static let smart = SkeletonReveal(hold: 0.15, choose: { context in
        if context.isInteracting || context.skeletonShownFor == nil { return .instant }
        return SkeletonReveal(order: .byRow)
    })

    /// Crossfades the whole skeleton into the content.
    public static let together = SkeletonReveal()

    /// Brings each piece in where its skeleton was, row by row down the region, each line wiping
    /// in from its leading edge.
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
    /// wipe each piece in where its skeleton was, starting at the delay the order gives it; the
    /// skeleton under it wipes out with the same edge, so the two never show at once in one spot.
    public enum Order: Sendable {
        /// Everything at once.
        case together
        /// Your own timing: seconds from the start of the reveal for each piece, or `nil` to show
        /// it at once. Delays stop at one second.
        case custom(@Sendable (RevealPiece) -> Double?)

        /// Row by row down the region, one beat apart.
        public static let byPosition = Order.custom(RevealPiece.byPosition)
        /// Row by row down the screen, one beat apart, across every reveal landing together;
        /// rows off screen at once.
        public static let byRow = Order.custom(RevealPiece.byRow)
    }

    /// Where content starts from as it fades in. Only what paints: blur, offset, scale,
    /// rotation and a clip. Nothing here changes layout.
    public struct Enter: Sendable, Equatable {
        public var blur: CGFloat
        public var offset: CGSize
        public var scale: CGFloat
        public var rotation: Angle
        /// Starts clipped away entirely and unveils from this edge, like a CSS `clip-path` inset.
        public var clip: Edge?

        public init(blur: CGFloat = 0, offset: CGSize = .zero, scale: CGFloat = 1, rotation: Angle = .zero, clip: Edge? = nil) {
            self.blur = blur
            self.offset = offset
            self.scale = scale
            self.rotation = rotation
            self.clip = clip
        }

        public static let none = Enter()
        /// Comes into focus.
        public static let blur = Enter(blur: 6)
        /// Rises a few points into place.
        public static let rise = Enter(offset: CGSize(width: 0, height: 6))
        /// Grows slightly into place.
        public static let zoom = Enter(scale: 0.97)
        /// Unveils from the top edge down.
        public static let unveil = Enter(clip: .top)
    }

    /// A mask that uncovers content across its frame as the reveal runs.
    public enum Wipe: Sendable {
        /// Follows the shimmer: the content appears behind its front, at its slant and pace.
        case sweep
        /// Your own mask for each moment of the reveal, from progress 0 to 1. Opaque stops show
        /// the content. The outgoing skeleton gets the inverse, or its own mask if you give one.
        /// `effect` paints the incoming content at each moment too, for example a blur that
        /// clears as the wipe passes.
        case custom(@Sendable (Double) -> WipeMask, outgoing: (@Sendable (Double) -> WipeMask)? = nil, effect: (@Sendable (Double) -> Enter)? = nil)
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
        if context.reduceMotion || SkeletonTesting.isInstant { spec = .instant }
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
    /// The piece's row: the pieces beside it, merged where their heights overlap. `nil` if alone.
    public var unit: CGRect?
    /// Whether this is smaller text than the largest in its row, such as a caption under a name.
    public var isSecondary: Bool
    /// The piece's row on screen, counting from the top, among every reveal landing with this one.
    public var row: Int
    /// How many rows are on screen across the reveals landing together.
    public var rows: Int
    /// The piece's row within its own region, counting from the top.
    public var regionRow: Int
    /// How many rows its region has.
    public var regionRows: Int
    /// The screen the reveal is on.
    public var screen: CGRect

    public init(
        rect: CGRect, reveal: CGRect, unit: CGRect?, isSecondary: Bool,
        row: Int, rows: Int, regionRow: Int, regionRows: Int, screen: CGRect
    ) {
        self.rect = rect
        self.reveal = reveal
        self.unit = unit
        self.isSecondary = isSecondary
        self.row = row
        self.rows = rows
        self.regionRow = regionRow
        self.regionRows = regionRows
        self.screen = screen
    }

    /// The beat between one row and the next.
    public static let rowStagger = 0.04
    /// The longest a cascade may take to reach its last row; longer pages tighten the beat.
    public static let longestCascade = 0.45

    /// The beat for a cascade of `rows` rows.
    public static func stagger(rows: Int) -> Double {
        min(rowStagger, longestCascade / Double(max(rows - 1, 1)))
    }

    /// `sequence`'s order: row by row down the region, one beat apart.
    @Sendable public static func byPosition(_ piece: RevealPiece) -> Double? {
        Double(piece.regionRow) * stagger(rows: piece.regionRows)
    }

    /// `smart`'s order: row by row down the screen, one beat apart, across every reveal landing
    /// together, so separate cards cascade as one page. Rows off screen appear at once.
    @Sendable public static func byRow(_ piece: RevealPiece) -> Double? {
        guard onScreen(piece.unit ?? piece.rect, piece.screen) else { return nil }
        return Double(piece.row) * stagger(rows: piece.rows)
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

/// For UI tests and snapshots: launch the app with `-SilhouetteInstant YES` and every reveal is
/// instant and every skeleton holds still, so screenshots and queries never wait on motion.
public enum SkeletonTesting {
    nonisolated public static var isInstant: Bool {
        UserDefaults.standard.bool(forKey: "SilhouetteInstant")
    }
}
