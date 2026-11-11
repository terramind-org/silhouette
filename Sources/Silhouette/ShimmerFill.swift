import SwiftUI

/// The one clock every skeleton keeps time by.
///
/// Phases come from the wall clock rather than from when a view appeared, so a skeleton that
/// mounts late joins the shimmer already in step with the rest.
enum SkeletonClock {
    /// How far along its cycle the animation is at `date`, from 0 to 1.
    static func phase(at date: Date, period: Double) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        return t.truncatingRemainder(dividingBy: period) / period
    }

    /// The pulse's brightness at `date`, from 0 to 1, easing in and out.
    static func pulse(at date: Date, period: Double) -> Double {
        0.5 - 0.5 * cos(2 * .pi * phase(at: date, period: period))
    }
}

/// What a skeleton fill draws.
enum ShimmerPaint: Equatable {
    /// The base, with the highlight moving over it.
    case skeleton
    /// Only the highlight, for shimmering text and views that draw their own base.
    case highlightOnly(Color)
}

/// Fills its frame with the theme's base and the shared moving highlight.
///
/// Every skeleton draws through this view. Highlights travel in one stream across the screen:
/// each band's position comes from the shared clock and the view's place on screen, so
/// neighbouring skeletons read as one band passing over all of them.
struct ShimmerFill: View {
    var paint: ShimmerPaint = .skeleton
    /// The frame the band sweeps across for `.groupShimmer`, in global coordinates.
    var groupFrame: CGRect?

    @Environment(\.skeletonTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A shimmer's loop is measured across a screen this wide; any other width keeps its pace.
    nonisolated static let referenceWidth: CGFloat = 1280
    /// The share of a loop a band takes to cross the reference width; the rest is the gap.
    nonisolated static let sweepShare: CGFloat = 0.7
    /// Bands follow each other this many band-widths apart, start to start.
    nonisolated static let spacing: CGFloat = 2.5

    /// Points per second the band travels at this speed.
    nonisolated static func pace(speed: SkeletonSpeed) -> CGFloat {
        referenceWidth / (sweepShare * speed.shimmerLoop)
    }

    var body: some View {
        let animation = effectiveAnimation
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            TimelineView(.animation(paused: animation == .none)) { timeline in
                Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                    draw(in: &context, size: size, frame: frame, date: timeline.date, animation: animation)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var effectiveAnimation: SkeletonAnimation {
        Self.animation(for: theme, reduceMotion: reduceMotion)
    }

    /// Under Reduce Motion skeletons hold still, unless the theme asks for a quiet pulse.
    nonisolated static func animation(for theme: SkeletonTheme, reduceMotion: Bool) -> SkeletonAnimation {
        guard reduceMotion, theme.animation != .none else { return theme.animation }
        return theme.reducedMotion == .pulse ? .pulse : .none
    }

    private var bandWidth: CGFloat {
        if let width = theme.bandWidth { return max(1, width) }
        return min(max(ScreenWidth.current * 0.4, 80), 320)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, frame: CGRect, date: Date, animation: SkeletonAnimation) {
        let colors = theme.colors(for: colorScheme)
        let rect = CGRect(origin: .zero, size: size)
        let highlight: Color
        switch paint {
        case .skeleton:
            context.fill(Path(rect), with: .color(colors.base))
            highlight = colors.highlight
        case .highlightOnly(let color):
            highlight = color
        }

        switch animation {
        case .none:
            return
        case .pulse:
            // Reduce Motion asks for a quieter, slower breath.
            let period = theme.speed.pulseLoop * (reduceMotion ? 1.5 : 1)
            let amount = SkeletonClock.pulse(at: date, period: period) * (reduceMotion ? 0.7 : 1)
            context.fill(Path(rect), with: .color(highlight.opacity(amount)))
        case .shimmer, .groupShimmer:
            let axis = theme.direction.unitVector(layoutDirection: layoutDirection)
            let band = bandWidth
            let pace = Self.pace(speed: theme.speed)

            // Positions along the band's axis, measured from a fixed origin: the screen for a
            // shared stream, the region for a group shimmer.
            let reference: CGRect
            let period: CGFloat
            if animation == .groupShimmer, let groupFrame {
                reference = groupFrame
                period = Self.extent(of: groupFrame.size, along: axis) + band * 2
            } else {
                reference = .zero
                period = band * Self.spacing
            }
            let loop = Double(period / pace)
            let phase = CGFloat(SkeletonClock.phase(at: date, period: max(loop, 0.05)))
            let origin = CGPoint(x: frame.minX - reference.minX, y: frame.minY - reference.minY)
            let offset = origin.x * axis.dx + origin.y * axis.dy
            let corners = [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            let along = corners.map { offset + $0.x * axis.dx + $0.y * axis.dy }
            let low = along.min() ?? 0, high = along.max() ?? 0
            let start = animation == .groupShimmer ? Self.nearEdge(of: reference.size, along: axis) - band : 0
            let head = start + phase * period

            // A soft ramp either side of the peak, so no stop reads as a line.
            let ramp: [(Double, Double)] = [(0, 0), (0.18, 0.12), (0.34, 0.45), (0.5, 1), (0.66, 0.45), (0.82, 0.12), (1, 0)]
            let gradient = Gradient(stops: ramp.map { Gradient.Stop(color: highlight.opacity($0.1), location: $0.0) })
            var k = ((low - band - head) / period).rounded(.down)
            while head + k * period <= high + band {
                let center = head + k * period
                let from = center - band / 2 - offset
                let to = center + band / 2 - offset
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: from * axis.dx, y: from * axis.dy),
                        endPoint: CGPoint(x: to * axis.dx, y: to * axis.dy)
                    )
                )
                k += 1
            }
        }
    }

    nonisolated static func extent(of size: CGSize, along axis: CGVector) -> CGFloat {
        abs(size.width * axis.dx) + abs(size.height * axis.dy)
    }

    /// The smallest axis coordinate of a rect at the origin with this size.
    nonisolated static func nearEdge(of size: CGSize, along axis: CGVector) -> CGFloat {
        min(0, size.width * axis.dx) + min(0, size.height * axis.dy)
    }
}

/// The width of the screen, for sizing the shimmer's band.
@MainActor
enum ScreenWidth {
    static var current: CGFloat { ScreenBounds.current.width }
}
