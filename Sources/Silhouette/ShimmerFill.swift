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

    /// The distance between two shimmer bands on screen, in points. Wide enough that a phone
    /// sees one band at a time; a wide window sees more, all moving at one pace.
    static func span(bandWidth: CGFloat) -> CGFloat { 900 + bandWidth }

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
/// Every skeleton draws through this view. The highlight's position comes from the shared clock
/// and the view's place on screen, so neighbouring skeletons read as one band passing over all
/// of them.
struct ShimmerFill: View {
    var paint: ShimmerPaint = .skeleton
    /// The frame the band sweeps across for `.groupShimmer`, in global coordinates.
    var groupFrame: CGRect?

    @Environment(\.skeletonTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// Reduce Motion turns any travelling band into a gentle pulse.
    private var effectiveAnimation: SkeletonAnimation {
        switch theme.animation {
        case .shimmer, .groupShimmer: reduceMotion ? .pulse : theme.animation
        case .pulse, .none: theme.animation
        }
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
            let period = theme.speed.period * (reduceMotion ? 1.6 : 1.2)
            let amount = SkeletonClock.pulse(at: date, period: period) * (reduceMotion ? 0.7 : 1)
            context.fill(Path(rect), with: .color(highlight.opacity(amount)))
        case .shimmer, .groupShimmer:
            let axis = theme.direction.unitVector(layoutDirection: layoutDirection)
            let band = theme.bandWidth
            let phase = SkeletonClock.phase(at: date, period: theme.speed.period)

            // Positions along the band's axis, measured from a fixed origin: the screen for a
            // shared shimmer, the region for a group shimmer.
            let reference: CGRect
            let span: CGFloat
            if animation == .groupShimmer, let groupFrame {
                reference = groupFrame
                span = Self.extent(of: groupFrame.size, along: axis) + band * 2
            } else {
                reference = .zero
                span = SkeletonClock.span(bandWidth: band)
            }
            let origin = CGPoint(x: frame.minX - reference.minX, y: frame.minY - reference.minY)
            let offset = origin.x * axis.dx + origin.y * axis.dy
            // The extent of this view along the axis, in reference coordinates.
            let corners = [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            let along = corners.map { offset + $0.x * axis.dx + $0.y * axis.dy }
            let low = along.min() ?? 0, high = along.max() ?? 0
            // For a group shimmer the axis starts at the region's near edge.
            let start = animation == .groupShimmer ? Self.nearEdge(of: reference.size, along: axis) - band : 0
            let head = start + CGFloat(phase) * span

            let gradient = Gradient(stops: [
                .init(color: highlight.opacity(0), location: 0),
                .init(color: highlight, location: 0.5),
                .init(color: highlight.opacity(0), location: 1),
            ])
            // Every copy of the band that crosses this view.
            var k = ((low - band - head) / span).rounded(.down)
            while head + k * span <= high + band {
                let center = head + k * span
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

    static func extent(of size: CGSize, along axis: CGVector) -> CGFloat {
        abs(size.width * axis.dx) + abs(size.height * axis.dy)
    }

    /// The smallest axis coordinate of a rect at the origin with this size.
    static func nearEdge(of size: CGSize, along axis: CGVector) -> CGFloat {
        min(0, size.width * axis.dx) + min(0, size.height * axis.dy)
    }
}
