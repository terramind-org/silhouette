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
/// every reveal is a short crossfade, with no movement, blur or wipe.
public struct SkeletonReveal: Sendable {
    /// When each part of the content arrives.
    public var order: Order
    /// Where the content starts from as it fades in.
    public var enter: Enter
    /// A mask that uncovers the content across its frame. When set, it replaces ``order``.
    public var wipe: Wipe?
    /// Seconds to wait before the reveal starts.
    public var delay: Double
    /// Seconds the reveal takes. `0` is instant.
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
        duration: Double = 0.35,
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

    /// The default. Instant when the data lands within 150 ms (the skeleton never shows), a
    /// crossfade for something small or a refetch, and a top-to-bottom sequence for the rest.
    public static let smart = SkeletonReveal(hold: 0.15, choose: { context in
        if context.skeletonShownFor == nil { return .instant }
        if context.isRefetch || context.size.height < 160 { return .together }
        return .sequence
    })

    /// Crossfades the whole skeleton into the content.
    public static let together = SkeletonReveal(duration: 0.3)

    /// Brings the content in where its skeleton was, top to bottom, each part rising slightly.
    public static let sequence = SkeletonReveal(
        order: .sequence(),
        enter: .rise,
        duration: 0.6
    )

    /// Uncovers the content behind the shimmer's front, in the shimmer's direction.
    public static let sweep = SkeletonReveal(wipe: .sweep, duration: 0.55)

    /// Swaps the skeleton for the content at once.
    public static let instant = SkeletonReveal(duration: 0)

    // MARK: Parts

    /// When each part of the content arrives.
    public enum Order: Sendable {
        /// Everything at once.
        case together
        /// Along an axis, each position arriving `spread` of the duration after the first.
        case sequence(axis: Axis = .vertical, spread: Double = 0.55)
        /// Along an axis, with your own delay for each position. The function takes a position
        /// from 0 (top or leading) to 1 and returns its delay as a fraction of `spread`.
        case custom(axis: Axis = .vertical, spread: Double = 0.55, delay: @Sendable (Double) -> Double)
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
        /// Follows the shimmer: the content appears behind its front, in the theme's direction.
        case sweep
        /// Your own mask for each moment of the reveal, from progress 0 to 1. Opaque stops show
        /// the content; the outgoing skeleton gets the inverse.
        case custom(@Sendable (Double) -> WipeMask)
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

    /// The reveal to run for this context: `choose` applied, times capped at one second, and
    /// Reduce Motion turned into a short crossfade.
    func resolved(for context: RevealContext) -> SkeletonReveal {
        var spec = self
        if let choose, let chosen = choose(context) {
            spec = chosen
            spec.hold = hold
        }
        spec.choose = nil
        spec.delay = min(max(spec.delay, 0), 1)
        spec.duration = min(max(spec.duration, 0), 1)
        if context.reduceMotion, spec.duration > 0 {
            spec = SkeletonReveal(duration: 0.2)
        }
        return spec
    }
}

/// What a reveal knows as content lands, for ``SkeletonReveal/choose``.
public struct RevealContext: Sendable, Equatable {
    /// How long the skeleton was on screen, or `nil` if the data arrived before it showed.
    public var skeletonShownFor: Double?
    /// The size of the content arriving.
    public var size: CGSize
    /// Whether this content had loaded before and is loading again.
    public var isRefetch: Bool
    /// Whether Reduce Motion is on.
    public var reduceMotion: Bool

    public init(skeletonShownFor: Double?, size: CGSize, isRefetch: Bool, reduceMotion: Bool) {
        self.skeletonShownFor = skeletonShownFor
        self.size = size
        self.isRefetch = isRefetch
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

// MARK: - Drawing a reveal

/// Which side of a reveal a view is on.
enum RevealRole { case incoming, outgoing }

/// Animates one side of a reveal from `progress` 0 (all skeleton) to 1 (all content).
struct RevealEffect: ViewModifier, Animatable {
    var progress: Double
    var spec: SkeletonReveal
    var role: RevealRole
    var shimmerAxis: CGVector

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = min(max(progress, 0), 1)
        if let mask = Self.mask(spec: spec, progress: p, role: role, shimmerAxis: shimmerAxis) {
            entered(content, p)
                .mask { LinearGradient(stops: mask.stops, startPoint: mask.startPoint, endPoint: mask.endPoint) }
        } else {
            entered(content, p).opacity(role == .incoming ? p : 1 - p)
        }
    }

    @ViewBuilder
    private func entered(_ content: Content, _ p: Double) -> some View {
        if role == .incoming, spec.enter != .none {
            let rest = 1 - p
            content
                .blur(radius: spec.enter.blur * rest)
                .scaleEffect(1 + (spec.enter.scale - 1) * rest)
                .rotationEffect(spec.enter.rotation * rest)
                .offset(x: spec.enter.offset.width * rest, y: spec.enter.offset.height * rest)
        } else {
            content
        }
    }

    /// The gradient mask for this moment, or `nil` for a plain crossfade.
    static func mask(spec: SkeletonReveal, progress p: Double, role: RevealRole, shimmerAxis: CGVector) -> SkeletonReveal.WipeMask? {
        var mask: SkeletonReveal.WipeMask
        switch spec.wipe {
        case .sweep:
            mask = sweep(progress: p, axis: shimmerAxis)
        case .custom(let make):
            mask = make(p)
        case nil:
            switch spec.order {
            case .together:
                return nil
            case .sequence(let axis, let spread):
                mask = ordered(progress: p, axis: axis, spread: spread) { $0 }
            case .custom(let axis, let spread, let delay):
                mask = ordered(progress: p, axis: axis, spread: spread, delay: delay)
            }
        }
        if role == .outgoing {
            mask.stops = mask.stops.map { Gradient.Stop(color: .black.opacity(1 - $0.color.opacityComponent), location: $0.location) }
        }
        return mask
    }

    static let samples = 24

    static func ordered(progress p: Double, axis: Axis, spread: Double, delay: (Double) -> Double) -> SkeletonReveal.WipeMask {
        let spread = min(max(spread, 0), 0.95)
        let stops = (0...samples).map { i -> Gradient.Stop in
            let x = Double(i) / Double(samples)
            let d = min(max(delay(x), 0), 1) * spread
            let local = min(max((p - d) / (1 - spread), 0), 1)
            return Gradient.Stop(color: .black.opacity(local), location: x)
        }
        return axis == .vertical
            ? SkeletonReveal.WipeMask(stops: stops, startPoint: .top, endPoint: .bottom)
            : SkeletonReveal.WipeMask(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    static func sweep(progress p: Double, axis: CGVector) -> SkeletonReveal.WipeMask {
        let feather = 0.3
        let front = p * (1 + feather)
        let stops = (0...samples).map { i -> Gradient.Stop in
            let x = Double(i) / Double(samples)
            return Gradient.Stop(color: .black.opacity(min(max((front - x) / feather, 0), 1)), location: x)
        }
        return SkeletonReveal.WipeMask(
            stops: stops,
            startPoint: UnitPoint(x: 0.5 - axis.dx / 2, y: 0.5 - axis.dy / 2),
            endPoint: UnitPoint(x: 0.5 + axis.dx / 2, y: 0.5 + axis.dy / 2)
        )
    }
}

private extension Color {
    /// The alpha of a colour built by `RevealEffect`, which are always black with an opacity.
    var opacityComponent: Double {
        Double(resolve(in: EnvironmentValues()).opacity)
    }
}
