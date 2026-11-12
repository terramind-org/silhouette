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

    /// Where the content puts ink, as an alpha mask in the region's coordinates: its letters,
    /// images and shapes, and none of the surfaces behind them, grown a couple of pixels so soft
    /// edges count too. A reveal hides only this while a piece waits.
    ///
    /// The content is drawn plainly over the page's colour, then each pixel is measured by how far
    /// it is from that colour. Drawn plainly, it shares nothing with the live skeleton.
    @MainActor
    static func ink<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> Image? {
        inkMask(of: view, size: size, environment: environment, scale: scale).map { Image(decorative: $0, scale: scale) }
    }

    /// The view as it draws, in its own colours, on nothing.
    @MainActor
    static func picture<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> Image? {
        guard size.width >= 1, size.height >= 1, size.width * size.height * scale * scale < 24_000_000 else { return nil }
        let renderer = ImageRenderer(content: view
            .id(UUID())
            .environment(\.self, environment)
            .frame(width: size.width, height: size.height, alignment: .topLeading))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        let dark = environment.colorScheme == .dark
        return inAppearance(dark: dark) { renderer.cgImage }.map { Image(decorative: $0, scale: scale) }
    }

    /// The size the view takes at this width, left free to be as tall as it likes. A region is
    /// held at its skeleton's height while it loads, so the content that arrives can run past it.
    @MainActor
    static func fittingSize<V: View>(of view: V, width: CGFloat, environment: EnvironmentValues) -> CGSize? {
        guard width >= 1 else { return nil }
        var env = environment
        env.isDrawingSkeleton = true
        let renderer = ImageRenderer(content: view.environment(\.self, env).frame(width: width, alignment: .topLeading))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        var size: CGSize?
        renderer.render { measured, _ in size = measured }
        return size
    }

    /// The content drawn in the opposite of the page, over the page, for ``coverage(of:page:)``.
    @MainActor
    static func inkRender<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> CGImage? {
        guard size.width >= 1, size.height >= 1, size.width * size.height < 6_000_000 else { return nil }
        var env = environment
        env.isDrawingSkeleton = true
        let dark = env.colorScheme == .dark
        let renderer = ImageRenderer(content: view
            .id(UUID())
            .environment(\.self, env)
            .environment(\.colorScheme, env.colorScheme)
            .foregroundStyle(dark ? Color.white : Color.black)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(dark ? Color.black : Color.white))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        // Offscreen, colours that follow light and dark mode resolve against the current
        // appearance, not the environment's, so render under the page's own.
        return inAppearance(dark: dark) { renderer.cgImage }
    }

    /// The same, with the content's text drawn invisibly.
    @MainActor
    static func bareRender<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> CGImage? {
        guard #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) else { return nil }
        return inkRender(of: view.textRenderer(InvisibleText()), size: size, environment: environment, scale: scale)
    }

    @MainActor
    static func inkMask<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> CGImage? {
        inkRender(of: view, size: size, environment: environment, scale: scale)
            .flatMap { coverage(of: $0, page: environment.colorScheme == .dark ? 0 : 1) }
    }

    @MainActor
    static func inAppearance<T>(dark: Bool, _ body: () -> T) -> T {
        #if canImport(UIKit) && !os(watchOS)
        var result: T?
        UITraitCollection(userInterfaceStyle: dark ? .dark : .light).performAsCurrent { result = body() }
        return result!
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        var result: T?
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance { result = body() }
        return result ?? body()
        #else
        return body()
        #endif
    }

    /// Alpha for every pixel by how far its luminance is from the page's, grown by two pixels.
    nonisolated static func coverage(of image: CGImage, page: Double, grow: Int = 2) -> CGImage? {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var alpha = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Double(rgba[i * 4]), g = Double(rgba[i * 4 + 1]), b = Double(rgba[i * 4 + 2])
            let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
            // A faint surface (a card a shade off the page) stays out; anything clearly drawn is in.
            alpha[i] = UInt8(min(max((abs(lum - page) - surfaceTolerance) * coverageGain * 255, 0), 255))
        }
        // Grow by two pixels, so the letters' soft edges are covered.
        for _ in 0..<grow {
            var grown = alpha
            for y in 0..<height {
                for x in 0..<width {
                    var m = alpha[y * width + x]
                    if x > 0 { m = max(m, alpha[y * width + x - 1]) }
                    if x < width - 1 { m = max(m, alpha[y * width + x + 1]) }
                    if y > 0 { m = max(m, alpha[(y - 1) * width + x]) }
                    if y < height - 1 { m = max(m, alpha[(y + 1) * width + x]) }
                    grown[y * width + x] = m
                }
            }
            alpha = grown
        }
        var black = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) { black[i * 4 + 3] = alpha[i] }
        return black.withUnsafeMutableBytes { bytes -> CGImage? in
            CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
    }

    @MainActor
    static func shape<V: View>(of view: V, size: CGSize, environment: EnvironmentValues, scale: CGFloat, textAsBars: Bool = true) -> CGImage? {
        guard size.width >= 1, size.height >= 1, size.width * size.height < 6_000_000 else { return nil }
        var env = environment
        env.isDrawingSkeleton = false
        // A fresh identity each time: offscreen renders otherwise reuse how an earlier render of
        // the same content drew its text.
        let renderer = ImageRenderer(content: SkeletonShape(content: view.id(UUID()), textAsBars: textAsBars)
            .environment(\.self, env)
            .frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.cgImage
    }

    /// Whether an image has any coverage at all: an offscreen render of a view that only
    /// exists in the live hierarchy comes back empty.
    nonisolated static func hasCoverage(_ image: CGImage) -> Bool {
        let w = 64, h = max(1, Int(Double(image.height) / Double(max(image.width, 1)) * 64))
        var alpha = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(
            data: &alpha, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return true }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return alpha.contains { $0 > 32 }
    }

    /// The areas that look the same in two renders of one size, at one pixel a point.
    nonisolated static func unchanged(_ areas: [CGRect], a: CGImage, b: CGImage) -> [CGRect] {
        // A region that hugs its content may come out a little narrower or shorter with real
        // data; both are drawn from the top leading corner, so compare where they overlap.
        let w = min(a.width, b.width), h = min(a.height, b.height)
        guard w > 0, h > 0 else { return [] }
        func pixels(_ image: CGImage) -> [UInt8]? {
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            guard let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            // Top-left anchored: the context's origin is bottom-left.
            context.draw(image, in: CGRect(x: 0, y: h - image.height, width: image.width, height: image.height))
            return bytes
        }
        guard let pa = pixels(a), let pb = pixels(b) else { return [] }
        return areas.filter { area in
            let x0 = max(Int(area.minX), 0), x1 = min(Int(area.maxX), w)
            let y0 = max(Int(area.minY), 0), y1 = min(Int(area.maxY), h)
            guard x1 > x0, y1 > y0 else { return false }
            // Two renders of the same view match pixel for pixel, so any pixel that clearly
            // differs means the area depends on the data, however thin the stroke.
            var changed = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let i = (y * w + x) * 4
                    let d = max(abs(Int(pa[i]) - Int(pb[i])), abs(Int(pa[i + 1]) - Int(pb[i + 1])), abs(Int(pa[i + 2]) - Int(pb[i + 2])))
                    if d > 24 { changed += 1 }
                }
            }
            return changed <= 1
        }
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
            if Double(count) / Double(boxW * boxH) < 0.25, boxW * boxH > 2000 {
                // A border runs along its box's edges; a ring or an arc only touches them.
                let band = max(3, min(boxW, boxH) / 20)
                var alongEdges = 0
                for y in minY...maxY {
                    for x in minX...maxX where label[y * width + x] == next {
                        if x - minX < band || maxX - x < band || y - minY < band || maxY - y < band { alongEdges += 1 }
                    }
                }
                if Double(alongEdges) / Double(count) > 0.8 { continue }
            }
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
    /// The cascade's time as drawn, shared by every layer of the reveal.
    var clock = RevealClock()
    /// Wipes run right to left in a right-to-left layout.
    var rightToLeft = false
    /// The content as drawn, over the page's colour, in the region's coordinates: where its ink
    /// is, for a waiting piece to hide just that. Without it, a waiting piece's whole area is.
    var ink: Image?
    var inkSize: CGSize = .zero
    /// The ink of the content with its text drawn invisibly, exact rather than grown: where
    /// ``SurfaceLayer`` leaves the page showing, under each picture and control's skeleton.
    var bareInk: Image?

    /// Seconds into the cascade at a frame drawn at `date`.
    func time(at date: Date) -> Double {
        clock.time(at: date, start: start)
    }

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
        rightToLeft: Bool = false
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
        return RevealPlan(incoming: timed(content), outgoing: timed(skeleton), fade: fade, start: Date(), rightToLeft: rightToLeft)
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
    /// Regions that have said they're coming, and how many have arrived or left.
    private var expected = 0
    private var settled = 0
    /// When the last cascade under way ends.
    private(set) static var busyUntil = Date.distantPast
    /// When each row of earlier batches starts its wipe: its top in screen coordinates.
    private static var scheduled: [(batch: ObjectIdentifier, top: CGFloat, at: Date)] = []

    /// Adds a reveal's pieces, in screen coordinates, and returns every row of the batch once
    /// the window has closed.
    static func join(_ pieces: [CGRect], now: Date = Date()) async -> [CGRect] {
        await joinBatch(pieces, now: now).rows
    }

    static func joinBatch(_ pieces: [CGRect], now: Date = Date()) async -> (rows: [CGRect], batch: ObjectIdentifier) {
        let batch = reserve(now: now)
        return (await batch.join(pieces), ObjectIdentifier(batch))
    }

    /// Takes a place in the batch the moment a region's data arrives, before it does any
    /// tracing. Regions that arrive in the same update share one batch however long each takes
    /// to trace, because the batch waits for every place taken. Within the window, later
    /// arrivals join too.
    static func reserve(now: Date = Date()) -> RevealBatch {
        let batch: RevealBatch
        if let current, !current.closed, current.settled < current.expected || now.timeIntervalSince(current.opened) < window {
            batch = current
        } else {
            batch = RevealBatch()
            current = batch
        }
        batch.expected += 1
        return batch
    }

    /// Adds a region's pieces, in screen coordinates, and returns every row of the batch once
    /// everyone who took a place has arrived or left, and the window has passed.
    func join(_ pieces: [CGRect]) async -> [CGRect] {
        rects += pieces
        settled += 1
        // Never longer than a second, should a region stop on its way.
        let latest = opened.addingTimeInterval(1)
        while (settled < expected || Date().timeIntervalSince(opened) < Self.window), Date() < latest {
            try? await Task.sleep(for: .seconds(0.01))
        }
        closed = true
        return Rows.of(rects)
    }

    /// Gives up a place: the region revealed some other way.
    func leave() {
        settled += 1
    }

    /// Keeps the page's cascade strictly top to bottom across batches: a line never starts
    /// before a line above it from an earlier batch, which a reveal landing a moment later
    /// would otherwise do. Then records when this plan's lines start.
    static func queue(_ plan: inout RevealPlan, region: CGRect, batch: ObjectIdentifier) {
        let now = plan.start
        scheduled.removeAll { $0.at < now }
        func held(_ timed: inout [RevealPlan.Timed]) {
            for i in timed.indices {
                guard let delay = timed[i].delay else { continue }
                let top = timed[i].rect.minY + region.minY
                let after = scheduled
                    .filter { $0.batch != batch && $0.top < top - 1 }
                    .map { $0.at.timeIntervalSince(now) + RevealPiece.rowStagger }
                    .max() ?? 0
                timed[i].delay = max(delay, after)
            }
        }
        held(&plan.incoming)
        held(&plan.outgoing)
        busyUntil = max(busyUntil, now.addingTimeInterval(plan.end))
        for piece in plan.incoming {
            guard let delay = piece.delay else { continue }
            scheduled.append((batch, piece.rect.minY + region.minY, now.addingTimeInterval(delay)))
        }
    }
}

/// Work that can wait for a quiet moment: run one piece at a time, never while a cascade is
/// under way, so it can't hold up a frame anyone is watching.
@MainActor
enum IdleWork {
    private static var queue: [() -> Bool] = []
    private static var running = false

    /// `work` returns whether it did anything; work that had nothing to do takes no turn.
    static func enqueue(_ work: @escaping () -> Bool) {
        queue.append(work)
        guard !running else { return }
        running = true
        Task { @MainActor in
            while !queue.isEmpty {
                let busy = RevealBatch.busyUntil.timeIntervalSinceNow
                if busy > 0 {
                    try? await Task.sleep(for: .seconds(busy + 0.05))
                    continue
                }
                if queue.removeFirst()() {
                    // One piece a frame or two, so scrolling never feels it.
                    try? await Task.sleep(for: .seconds(0.03))
                }
            }
            running = false
        }
    }
}

/// A cascade's time, as its frames are drawn rather than as the wall clock runs.
///
/// Between two drawn frames it moves on by at most a twentieth of a second, so when the app
/// stalls (other content arriving and being traced, say) the cascade waits rather than jumping
/// ahead and showing every line at once.
final class RevealClock: @unchecked Sendable {
    static let longestStep = 1.0 / 20
    private var last: Date?
    private(set) var elapsed: Double = 0
    private let fixed: Double?

    /// - Parameter fixed: Always this time, for tests.
    init(fixed: Double? = nil) {
        self.fixed = fixed
        elapsed = fixed ?? 0
    }

    func time(at date: Date, start: Date) -> Double {
        if let fixed { return fixed }
        guard let last else {
            last = date
            elapsed = min(max(date.timeIntervalSince(start), 0), Self.longestStep)
            return elapsed
        }
        if date > last {
            elapsed += min(date.timeIntervalSince(last), Self.longestStep)
            self.last = date
        }
        return elapsed
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let plan, role == .incoming, plan.ink != nil {
            // Everything shows except the letters, images and shapes of what hasn't wiped in yet:
            // a waiting line hides its own ink, never the card behind it.
            TimelineView(.animation) { timeline in
                Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                    drawWaitingInk(plan, at: plan.time(at: timeline.date), in: &context, size: size)
                }
            }
        } else if let plan {
            TimelineView(.animation) { timeline in
                Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                    draw(plan, at: plan.time(at: timeline.date), in: &context, size: size)
                }
            }
        } else if let mask = WipeEffect.mask(spec: spec, progress: progress, role: role, shimmerAxis: shimmerAxis) {
            LinearGradient(stops: mask.stops, startPoint: mask.startPoint, endPoint: mask.endPoint)
        } else {
            // Past the frame too: a stroke's outer half, a shadow or a glow drawn beyond the
            // content's bounds must never be cut off.
            Rectangle().fill(.black).padding(-RevealMask.overflow).opacity(role == .incoming ? progress : 1 - progress)
        }
    }

    /// How far beyond its frame content may draw and still be shown.
    static let overflow: CGFloat = 80

    private func drawWaitingInk(_ plan: RevealPlan, at t: Double, in context: inout GraphicsContext, size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        let areas = plan.incoming.map { Self.area(of: $0.rect) }
        context.fill(Path(full), with: .color(.black))
        guard let ink = plan.ink else { return }
        context.blendMode = .destinationOut
        context.drawLayer { hide in
            // The ink: the content over the page's colour, measured by how far each pixel is from
            // it, grown a point or so so soft edges count too.
            hide.draw(ink, in: CGRect(origin: .zero, size: plan.inkSize))
            // Less everything outside a piece, and each piece's revealed side.
            hide.blendMode = .destinationOut
            hide.drawLayer { revealed in
                revealed.fill(Path(full), with: .color(.black))
                revealed.blendMode = .clear
                for area in areas { revealed.fill(Path(area), with: .color(.black)) }
                revealed.blendMode = .normal
                for (piece, area) in zip(plan.incoming, areas) {
                    revealed.fill(Path(area), with: Self.wipe(area: area, shown: plan.amount(piece, at: t), rightToLeft: plan.rightToLeft, showing: true))
                }
            }
        }
    }

    private func draw(_ plan: RevealPlan, at t: Double, in context: inout GraphicsContext, size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        let incoming = role == .incoming
        let pieces = incoming ? plan.incoming : plan.outgoing
        if incoming {
            // Without the content's ink, a waiting piece hides its whole area.
            context.fill(Path(full), with: .color(.black))
            context.blendMode = .destinationOut
            for piece in pieces {
                let area = Self.area(of: piece.rect)
                context.fill(Path(area), with: Self.wipe(area: area, shown: plan.amount(piece, at: t), rightToLeft: plan.rightToLeft, showing: false))
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
        let feather = min(0.5, 48 / max(area.width, 1))
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

/// The content's surfaces under its skeleton: the cards, pills and tinted rows its pieces sit
/// on, without the pieces, which the skeleton stands for. A live copy of the content with its
/// text drawn invisibly and each picture and control cut out exactly, under its own skeleton
/// block.
///
/// While loading it shows whole. During a reveal it lies under the content and shows only where
/// pieces still wait: a waiting piece's ink is cut out of the content, grown a little so no soft
/// edge of a letter is left, and this fills the cut with the surface the piece sits on. It is
/// one view from the skeleton's first frame to the reveal's last, so nothing mounts as the
/// cascade starts.
struct SurfaceLayer<Content: View>: View {
    var content: Content
    /// The ink left once the text is drawn invisibly: pictures, controls and painted shapes.
    var ink: Image
    var size: CGSize
    /// While revealing, which pieces still wait.
    var plan: RevealPlan?
    /// Areas the content itself shows throughout; drawing them here too would double anything
    /// semi-transparent there, such as a picture's faded edge.
    var fixed: [CGRect] = []
    /// The stand-in's surfaces as they were traced. Once the data is in, `content` is the real
    /// content, whose surfaces must wait for their wipe like everything else: until then the
    /// waiting areas keep showing the stand-in's.
    var still: Image? = nil

    var body: some View {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
            surfaces
                .mask(alignment: .topLeading) {
                    if let plan, plan.ink != nil {
                        TimelineView(.animation) { timeline in
                            Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                                let t = plan.time(at: timeline.date)
                                for piece in plan.incoming {
                                    let area = RevealMask.area(of: piece.rect)
                                    let shown = plan.amount(piece, at: t)
                                    guard shown < 1 else { continue }
                                    context.fill(Path(area), with: RevealMask.wipe(area: area, shown: shown, rightToLeft: plan.rightToLeft, showing: false))
                                }
                                context.blendMode = .destinationOut
                                if still != nil {
                                    context.draw(ink, in: CGRect(origin: .zero, size: size))
                                } else {
                                    context.draw(plan.bareInk ?? ink, in: CGRect(origin: .zero, size: plan.inkSize))
                                }
                                for rect in fixed { context.fill(Path(rect), with: .color(.black)) }
                            }
                        }
                    } else {
                        Canvas(opaque: false, rendersAsynchronously: false) { context, canvas in
                            context.fill(Path(CGRect(origin: .zero, size: canvas)), with: .color(.black))
                            context.blendMode = .destinationOut
                            context.draw(ink, in: CGRect(origin: .zero, size: size))
                            for rect in fixed { context.fill(Path(rect), with: .color(.black)) }
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
    @ViewBuilder
    private var surfaces: some View {
        if let still {
            still.frame(width: size.width, height: size.height, alignment: .topLeading)
        } else {
            content
                .textRenderer(InvisibleText())
                .environment(\.isDrawingSkeleton, true)
        }
    }

    /// The stand-in's surfaces, drawn the way this layer draws them live.
    @MainActor
    static func still(of content: Content, size: CGSize, environment: EnvironmentValues, scale: CGFloat) -> Image? {
        guard #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) else { return nil }
        var env = environment
        env.isDrawingSkeleton = true
        return PieceTracer.picture(of: content.textRenderer(InvisibleText()), size: size, environment: env, scale: scale)
    }
}

/// Draws text as nothing, leaving the surfaces it sits on.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct InvisibleText: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {}
}

/// The incoming content's entrance: blur, offset, scale and rotation easing away.
struct EnterEffect: ViewModifier, Animatable {
    var enter: SkeletonReveal.Enter
    /// 1 at the start of the entrance, 0 once arrived.
    var rest: Double
    /// What was showing before the data came: an entrance moves only what arrives.
    var fixed: [CGRect] = []
    /// The content as it will rest, for the fixed areas while the rest of it moves.
    var still: Image? = nil

    nonisolated var animatableData: Double {
        get { rest }
        set { rest = newValue }
    }

    private var moves: Bool {
        enter.blur != 0 || enter.scale != 1 || enter.rotation != .zero || enter.offset != .zero
    }

    func body(content: Content) -> some View {
        let holding = rest > 0 && !fixed.isEmpty
        content
            .blur(radius: enter.blur * rest)
            .scaleEffect(1 + (enter.scale - 1) * rest)
            .rotationEffect(enter.rotation * rest)
            .offset(x: enter.offset.width * rest, y: enter.offset.height * rest)
            // Always masked, so the content keeps its identity whichever entrance is in use.
            .mask(alignment: .topLeading) {
                if holding {
                    Canvas(opaque: false, rendersAsynchronously: false) { context, canvas in
                        let o = RevealMask.overflow
                        let size = CGSize(width: canvas.width - 2 * o, height: canvas.height - 2 * o)
                        context.fill(Path(clip(in: size).offsetBy(dx: o, dy: o)), with: .color(.black))
                        if moves {
                            // Shown from the still instead, where it rests.
                            guard still != nil else { return }
                            context.blendMode = .destinationOut
                        }
                        for rect in fixed { context.fill(Path(rect.offsetBy(dx: o, dy: o)), with: .color(.black)) }
                    }
                    .padding(-RevealMask.overflow)
                } else {
                    Rectangle().fill(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(
                            x: enter.clip == .leading || enter.clip == .trailing ? 1 - rest : 1,
                            y: enter.clip == .top || enter.clip == .bottom ? 1 - rest : 1,
                            anchor: Self.anchor(for: enter.clip)
                        )
                        .padding(enter.clip == nil ? -RevealMask.overflow : 0)
                }
            }
            .overlay(alignment: .topLeading) {
                if holding, moves, let still {
                    still.mask(alignment: .topLeading) {
                        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                            let o = RevealMask.overflow
                            for rect in fixed { context.fill(Path(rect.offsetBy(dx: o, dy: o)), with: .color(.black)) }
                        }
                        .padding(-RevealMask.overflow)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }

    /// The part of the frame the clip has uncovered so far.
    private func clip(in size: CGSize) -> CGRect {
        let shown = 1 - rest
        let o = RevealMask.overflow
        switch enter.clip {
        case .top: return CGRect(x: 0, y: 0, width: size.width, height: size.height * shown)
        case .bottom: return CGRect(x: 0, y: size.height * rest, width: size.width, height: size.height * shown)
        case .leading: return CGRect(x: 0, y: 0, width: size.width * shown, height: size.height)
        case .trailing: return CGRect(x: size.width * rest, y: 0, width: size.width * shown, height: size.height)
        case nil: return CGRect(x: -o, y: -o, width: size.width + 2 * o, height: size.height + 2 * o)
        }
    }

    static func anchor(for edge: Edge?) -> UnitPoint {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        case nil: .center
        }
    }
}

/// Carries the animated progress of a crossfade or a wipe into the mask.
struct RevealLayer: ViewModifier, Animatable {
    var progress: Double
    var role: RevealRole
    var spec: SkeletonReveal
    var plan: RevealPlan?
    var shimmerAxis: CGVector
    /// Areas of the content that show as they are throughout.
    var fixed: [CGRect] = []

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// A custom wipe's `effect` on the incoming content at this moment.
    private var effect: SkeletonReveal.Enter {
        guard role == .incoming, case .custom(_, _, let effect?) = spec.wipe else { return .none }
        return effect(min(max(progress, 0), 1))
    }

    func body(content: Content) -> some View {
        let effect = effect
        content
            .blur(radius: effect.blur)
            .scaleEffect(effect.scale)
            .rotationEffect(effect.rotation)
            .offset(effect.offset)
            .mask(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    RevealMask(role: role, progress: min(max(progress, 0), 1), spec: spec, plan: plan, shimmerAxis: shimmerAxis)
                    if role == .incoming, !fixed.isEmpty {
                        // Drawn past the frame too, for what's shown beyond it.
                        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                            let o = RevealMask.overflow
                            for rect in fixed { context.fill(Path(rect.offsetBy(dx: o, dy: o)), with: .color(.black)) }
                        }
                        .padding(-RevealMask.overflow)
                    }
                }
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
        case .custom(let make, let outgoing, _):
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

