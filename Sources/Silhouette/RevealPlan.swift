import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if os(watchOS)
import WatchKit
#endif

// MARK: - Pieces

/// Finds the pieces of a traced skeleton: each bar, image, control and painted shape.
enum PieceTracer {
    /// Draws `view` as its skeleton shape, offscreen, and returns each piece's rect in the view's
    /// own coordinates.
    @MainActor
    static func pieces<V: View>(of view: V, size: CGSize, environment: EnvironmentValues) -> [CGRect] {
        guard let image = shape(of: view, size: size, environment: environment, scale: 1) else { return [] }
        return pieces(in: image, pointSize: size)
    }

    /// Where the view puts ink: its letters themselves, its images, controls and painted shapes,
    /// and none of the surfaces behind them. A reveal hides only this, so a card's surface is
    /// never cut away while its lines wait for their turn.
    @MainActor
    static func ink<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> CGImage? {
        shape(of: view, size: size, environment: environment, scale: scale, textAsBars: false)
    }

    @MainActor
    private static func shape<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat, textAsBars: Bool = true) -> CGImage? {
        guard size.width >= 1, size.height >= 1, size.width * size.height < 6_000_000 else { return nil }
        var env = environment
        env.isDrawingSkeleton = false
        let renderer = ImageRenderer(content: SkeletonShape(content: view, textAsBars: textAsBars)
            .environment(\.self, env)
            .frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.cgImage
    }

    /// Connected areas of coverage in an image, as rects in points.
    static func pieces(in image: CGImage, pointSize: CGSize) -> [CGRect] {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return [] }
        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &alpha, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let sx = pointSize.width / CGFloat(width), sy = pointSize.height / CGFloat(height)

        var label = [Int32](repeating: 0, count: width * height)
        var rects: [CGRect] = []
        var stack: [Int] = []
        var next: Int32 = 0
        for start in 0..<(width * height) where alpha[start] > 127 && label[start] == 0 {
            next += 1
            label[start] = next
            stack.append(start)
            var minX = width, minY = height, maxX = 0, maxY = 0, count = 0
            while let i = stack.popLast() {
                let x = i % width, y = i / width
                count += 1
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                        let j = ny * width + nx
                        if alpha[j] > 127, label[j] == 0 { label[j] = next; stack.append(j) }
                    }
                }
            }
            let boxW = maxX - minX + 1, boxH = maxY - minY + 1
            // Specks, and outlines that only frame other pieces (a card's border), aren't pieces.
            guard count >= 4 else { continue }
            if Double(count) / Double(boxW * boxH) < 0.25, boxW * boxH > 2000 { continue }
            rects.append(CGRect(x: CGFloat(minX) * sx, y: CGFloat(minY) * sy, width: CGFloat(boxW) * sx, height: CGFloat(boxH) * sy))
        }
        return merged(rects)
    }

    /// Merges rects that overlap, such as the parts of one symbol.
    static func merged(_ rects: [CGRect]) -> [CGRect] {
        var result = rects
        var changed = true
        while changed {
            changed = false
            outer: for i in result.indices {
                for j in result.indices where j > i {
                    if result[i].insetBy(dx: -0.5, dy: -0.5).intersects(result[j]) {
                        result[i] = result[i].union(result[j])
                        result.remove(at: j)
                        changed = true
                        break outer
                    }
                }
            }
        }
        return result.sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
    }

    /// Whether a piece looks like a line of text: short and wide.
    static func isTextBar(_ rect: CGRect) -> Bool {
        rect.height <= 40 && rect.width >= rect.height * 2.5
    }
}

// MARK: - Plans

/// Rows of a page: pieces that sit side by side, merged where their heights overlap. Each line
/// of a paragraph is its own row; an avatar beside a name and a handle makes one row with them.
enum Rows {
    static func of(_ rects: [CGRect]) -> [CGRect] {
        var rows: [CGRect] = []
        for rect in rects.sorted(by: { $0.minY < $1.minY }) {
            if let last = rows.last, rect.minY < last.maxY - 0.5 {
                rows[rows.count - 1] = last.union(rect)
            } else {
                rows.append(rect)
            }
        }
        return rows
    }

    /// How many rows lie wholly above `rect`: its place in the cascade.
    static func index(of rect: CGRect, in rows: [CGRect]) -> Int {
        rows.filter { $0.maxY <= rect.minY + 0.5 }.count
    }
}

/// The timing of one ordered reveal: when each piece of the content wipes in, and when each
/// piece of its skeleton wipes out with it.
struct RevealPlan {
    struct Timed: Equatable {
        /// In the region's own coordinates.
        var rect: CGRect
        /// Seconds from the start, or `nil` for at once.
        var delay: Double?
    }

    var incoming: [Timed]
    var outgoing: [Timed]
    /// Seconds each piece's wipe takes.
    var fade: Double
    var start: Date
    /// Wipes run right to left in a right-to-left layout.
    var rightToLeft = false
    /// The content's ink (see `PieceTracer.ink`), in the region's coordinates. While a piece
    /// waits, only its ink is hidden; without it, the piece's whole area is.
    var ink: Image?
    var inkSize: CGSize = .zero

    /// When the last piece has finished, in seconds from the start.
    var end: Double {
        let latest = (incoming + outgoing).compactMap(\.delay).max() ?? 0
        return latest + fade
    }

    /// How far a piece's wipe has gone, eased, at `t` seconds from the start.
    func amount(_ piece: Timed, at t: Double) -> Double {
        guard let delay = piece.delay, fade > 0 else { return 1 }
        return Self.ease(min(max((t - delay) / fade, 0), 1))
    }

    /// CSS's `ease`: cubic-bezier(0.25, 0.1, 0.25, 1).
    static func ease(_ x: Double) -> Double {
        UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.25, y: 0.1), endControlPoint: UnitPoint(x: 0.25, y: 1)).value(at: x)
    }

    /// Times every piece of the content and of its skeleton by `order`.
    ///
    /// - Parameter pageRows: every row of every reveal landing in this batch, in screen
    ///   coordinates, so one cascade runs down the whole page.
    static func make(
        order: @Sendable (RevealPiece) -> Double?,
        content: [CGRect],
        skeleton: [CGRect],
        region: CGRect,
        screen: CGRect,
        pageRows: [CGRect],
        delay: Double,
        fade: Double,
        rightToLeft: Bool = false,
        ink: CGImage? = nil,
        inkScale: CGFloat = 1
    ) -> RevealPlan {
        let regionRows = Rows.of(content + skeleton)
        let onScreenRows = pageRows.filter { RevealPiece.onScreen($0, screen) }
        func timed(_ rects: [CGRect]) -> [Timed] {
            let units = Rows.of(rects)
            return rects.map { rect in
                let unit = units.first { $0.insetBy(dx: -0.5, dy: -0.5).contains(rect) }
                let lines = rects.filter { PieceTracer.isTextBar($0) && (unit?.contains($0) ?? false) }
                let largest = lines.map(\.height).max() ?? 0
                let global = rect.offsetBy(dx: region.minX, dy: region.minY)
                let piece = RevealPiece(
                    rect: global,
                    reveal: region,
                    unit: unit.map { $0.offsetBy(dx: region.minX, dy: region.minY) },
                    isSecondary: PieceTracer.isTextBar(rect) && rect.height < largest * 0.8,
                    row: Rows.index(of: global, in: onScreenRows),
                    rows: onScreenRows.count,
                    regionRow: Rows.index(of: rect, in: regionRows),
                    regionRows: regionRows.count,
                    screen: screen
                )
                return Timed(rect: rect, delay: order(piece).map { min(max($0, 0), 1) + delay })
            }
        }
        return RevealPlan(
            incoming: timed(content), outgoing: timed(skeleton), fade: fade, start: Date(), rightToLeft: rightToLeft,
            ink: ink.map { Image(decorative: $0, scale: inkScale) },
            inkSize: ink.map { CGSize(width: CGFloat($0.width) / inkScale, height: CGFloat($0.height) / inkScale) } ?? .zero
        )
    }
}

/// Reveals landing within 150 ms of each other share one cascade: each waits for the window to
/// close, then all of them rank every row they hold together, top to bottom.
@MainActor
final class RevealBatch {
    static let window = 0.15
    private static var current: RevealBatch?

    private let opened = Date()
    private var closed = false
    private var rects: [CGRect] = []

    /// Adds a reveal's pieces, in screen coordinates, and returns every row of the batch once
    /// the window has closed.
    static func join(_ pieces: [CGRect], now: Date = Date()) async -> [CGRect] {
        let batch: RevealBatch
        if let current, !current.closed, now.timeIntervalSince(current.opened) < window {
            batch = current
        } else {
            batch = RevealBatch()
            current = batch
        }
        batch.rects += pieces
        let wait = window - Date().timeIntervalSince(batch.opened)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        batch.closed = true
        return Rows.of(batch.rects)
    }
}

/// The screen a view is on, in global coordinates.
@MainActor
enum ScreenBounds {
    static var current: CGRect {
        #if os(watchOS)
        return WKInterfaceDevice.current().screenBounds
        #elseif os(visionOS)
        return CGRect(x: 0, y: 0, width: 1280, height: 720)
        #elseif canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow?.bounds ?? scene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 400, height: 860)
        #elseif canImport(AppKit)
        return NSApplication.shared.keyWindow?.contentView?.bounds ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        #else
        return CGRect(x: 0, y: 0, width: 400, height: 860)
        #endif
    }
}

// MARK: - Input

/// When someone last scrolled, for `smart`'s "mid-gesture" check.
@MainActor
enum SkeletonInput {
    static var lastScroll = Date.distantPast
    static let window = 0.4

    static var isInteracting: Bool {
        Date().timeIntervalSince(lastScroll) < window
    }
}

extension View {
    /// Lets `smart` reveals see scrolling in this scroll view, so content that lands while
    /// someone scrolls appears at once instead of animating under their thumb.
    ///
    /// ```swift
    /// ScrollView { Feed() }
    ///     .skeletonTracksScrolling()
    /// ```
    ///
    /// Needs iOS 18, macOS 15, tvOS 18, watchOS 11 or visionOS 2; it does nothing earlier.
    public func skeletonTracksScrolling() -> some View {
        modifier(ScrollTracking())
    }
}

private struct ScrollTracking: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
            content.onScrollPhaseChange { _, phase in
                if phase != .idle { SkeletonInput.lastScroll = Date() }
            }
        } else {
            content
        }
    }
}

// MARK: - Drawing a reveal

/// Which side of a reveal a view is on.
enum RevealRole { case incoming, outgoing }

/// The mask for one side of a reveal. Always present, so the content beneath it keeps its
/// identity whatever the reveal does.
struct RevealMask: View {
    var role: RevealRole
    var progress: Double
    var spec: SkeletonReveal
    var plan: RevealPlan?
    var shimmerAxis: CGVector

    var body: some View {
        if let plan {
            TimelineView(.animation) { timeline in
                Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                    draw(plan, at: timeline.date.timeIntervalSince(plan.start), in: &context, size: size)
                }
            }
        } else if let mask = WipeEffect.mask(spec: spec, progress: progress, role: role, shimmerAxis: shimmerAxis) {
            LinearGradient(stops: mask.stops, startPoint: mask.startPoint, endPoint: mask.endPoint)
        } else {
            Rectangle().opacity(role == .incoming ? progress : 1 - progress)
        }
    }

    private func draw(_ plan: RevealPlan, at t: Double, in context: inout GraphicsContext, size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        let incoming = role == .incoming
        let pieces = incoming ? plan.incoming : plan.outgoing
        if incoming {
            // Everything shows except the ink of what hasn't wiped in yet: a waiting line hides
            // its letters, never the card behind them.
            context.fill(Path(full), with: .color(.black))
            context.blendMode = .destinationOut
            for piece in pieces {
                let area = Self.area(of: piece.rect)
                let waiting = Self.wipe(area: area, shown: plan.amount(piece, at: t), rightToLeft: plan.rightToLeft, showing: false)
                context.drawLayer { layer in
                    if let ink = plan.ink {
                        layer.clip(to: Path(area))
                        layer.draw(ink, in: CGRect(origin: .zero, size: plan.inkSize))
                    } else {
                        layer.fill(Path(area), with: .color(.black))
                    }
                    layer.blendMode = .destinationIn
                    layer.fill(Path(area), with: waiting)
                }
            }
        } else {
            // The skeleton's faint traces outside its pieces go with the last piece; each bar
            // wipes out behind the same edge its line wipes in on.
            let overall = plan.end > 0 ? RevealPlan.ease(min(max(t / plan.end, 0), 1)) : 1
            context.fill(Path(full), with: .color(.black.opacity(1 - overall)))
            let areas = pieces.map { Self.area(of: $0.rect) }
            context.blendMode = .clear
            for area in areas { context.fill(Path(area), with: .color(.black)) }
            context.blendMode = .normal
            for (piece, area) in zip(pieces, areas) {
                let left = Self.wipe(area: area, shown: plan.amount(piece, at: t), rightToLeft: plan.rightToLeft, showing: false)
                context.fill(Path(area), with: left)
            }
        }
    }

    /// One edge passing along a piece: opaque on the side already revealed when `showing`, or on
    /// the side still waiting when not, with a soft edge between.
    static func wipe(area: CGRect, shown: Double, rightToLeft: Bool, showing: Bool) -> GraphicsContext.Shading {
        let feather = min(0.3, 18 / max(area.width, 1))
        let edge = shown * (1 + feather)
        let solid = Color.black, none = Color.black.opacity(0)
        let (before, after) = showing ? (solid, none) : (none, solid)
        let stops = [
            Gradient.Stop(color: before, location: 0),
            Gradient.Stop(color: before, location: min(max(edge - feather, 0), 1)),
            Gradient.Stop(color: after, location: min(max(edge, 0.0001), 1)),
            Gradient.Stop(color: after, location: 1),
        ]
        let from = rightToLeft ? CGPoint(x: area.maxX, y: area.midY) : CGPoint(x: area.minX, y: area.midY)
        let to = rightToLeft ? CGPoint(x: area.minX, y: area.midY) : CGPoint(x: area.maxX, y: area.midY)
        return .linearGradient(Gradient(stops: stops), startPoint: from, endPoint: to)
    }

    /// A piece's area on screen: its bar, grown to take in the ascenders and descenders that
    /// stand outside a bar drawn from cap height.
    static func area(of rect: CGRect) -> CGRect {
        rect.insetBy(dx: -2, dy: -max(2, rect.height * 0.35))
    }
}

/// The incoming content's entrance: blur, offset, scale and rotation easing away.
struct EnterEffect: ViewModifier, Animatable {
    var enter: SkeletonReveal.Enter
    /// 1 at the start of the entrance, 0 once arrived.
    var rest: Double

    nonisolated var animatableData: Double {
        get { rest }
        set { rest = newValue }
    }

    func body(content: Content) -> some View {
        content
            .blur(radius: enter.blur * rest)
            .scaleEffect(1 + (enter.scale - 1) * rest)
            .rotationEffect(enter.rotation * rest)
            .offset(x: enter.offset.width * rest, y: enter.offset.height * rest)
    }
}

/// Carries the animated progress of a crossfade or a wipe into the mask.
struct RevealLayer: ViewModifier, Animatable {
    var progress: Double
    var role: RevealRole
    var spec: SkeletonReveal
    var plan: RevealPlan?
    var shimmerAxis: CGVector

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask {
            RevealMask(role: role, progress: min(max(progress, 0), 1), spec: spec, plan: plan, shimmerAxis: shimmerAxis)
        }
    }
}

/// Gradient masks for wipes.
enum WipeEffect {
    static let samples = 24

    static func mask(spec: SkeletonReveal, progress p: Double, role: RevealRole, shimmerAxis: CGVector) -> SkeletonReveal.WipeMask? {
        var mask: SkeletonReveal.WipeMask
        switch spec.wipe {
        case .sweep: mask = sweep(progress: p, axis: shimmerAxis)
        case .custom(let make, let outgoing):
            if role == .outgoing, let outgoing { return outgoing(p) }
            mask = make(p)
        case nil: return nil
        }
        if role == .outgoing {
            mask.stops = mask.stops.map {
                Gradient.Stop(color: .black.opacity(1 - Double($0.color.resolve(in: EnvironmentValues()).opacity)), location: $0.location)
            }
        }
        return mask
    }

    static func sweep(progress p: Double, axis: CGVector) -> SkeletonReveal.WipeMask {
        let feather = 0.15
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
