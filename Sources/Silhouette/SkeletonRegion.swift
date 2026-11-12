import SwiftUI

extension View {
    /// Shows a skeleton in this view's exact shape while `isLoading` is true.
    ///
    /// Build the view from sample data while you wait, and Silhouette lays it out unseen and
    /// draws a skeleton over it: a bar for each line of text, a block for each image, control
    /// and painted shape. When `isLoading` turns false the content replaces its skeleton in
    /// place, so nothing on the page moves.
    ///
    /// ```swift
    /// ProfileCard(user: user ?? .sample)
    ///     .skeleton(isLoading: user == nil)
    /// ```
    ///
    /// Regions nest: an inner region loads on its own once its outer one has revealed.
    ///
    /// - Parameters:
    ///   - isLoading: Whether to show the skeleton.
    ///   - label: Read by VoiceOver in place of the content while it loads. "Loading" by default.
    ///   - onReveal: Called once the content has come in over a skeleton, for example to move
    ///     accessibility focus to it.
    public func skeleton(isLoading: Bool, label: Text? = nil, onReveal: (() -> Void)? = nil) -> some View {
        SkeletonRegion(content: self, placeholder: Optional<EmptyView>.none, isLoading: isLoading, source: .content, label: label, onReveal: onReveal)
    }
}

/// A region of the screen that shows a skeleton while it loads and reveals its content after.
struct SkeletonRegion<Content: View, Placeholder: View>: View {
    var content: Content
    /// Drawn as the skeleton's shape instead of the content, when given.
    var placeholder: Placeholder?
    var isLoading: Bool
    var source: SkeletonSource
    var label: Text?
    var onReveal: (() -> Void)?

    @Environment(\.self) private var environment
    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    @Environment(\.skeletonReveal) private var reveal
    @Environment(\.skeletonTheme) private var theme
    @Environment(\.skeletonDebug) private var localDebug
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How visible the content is: 0 under its skeleton, 1 revealed. Animated for crossfades,
    /// wipes and the fade back to a skeleton on reload.
    @State private var progress: Double
    /// 1 at the start of an entrance, 0 once arrived.
    @State private var enterRest: Double = 0
    /// Whether the skeleton is showing: past the reveal's hold, or back after a reload.
    @State private var held = false
    /// The skeleton coming up, and on a reload the content going, timed by drawn frames.
    @State private var fade: FrameFade?
    @State private var heldSince: Date?
    @State private var hasRevealed = false
    @State private var isRevealing = false
    @State private var spec = SkeletonReveal.together
    @State private var plan: RevealPlan?
    @State private var frame: CGRect = .zero
    /// The content's own height, measured inside the pinned frame.
    @State private var naturalHeight: CGFloat?
    /// While loading, the region keeps its skeleton's height, so data arriving can't move the
    /// page before the reveal starts; afterwards the pin lets go, eased.
    @State private var pinnedHeight: CGFloat?
    @State private var sizeWhileLoading: CGSize?
    @State private var moved: CGFloat?
    @State private var revealID = 0
    /// What of the content stays out of its surfaces while it loads, for ``SurfaceLayer``.
    @State private var surfaceInk: Image?
    @State private var surfaceSize: CGSize = .zero
    /// The skeleton's pieces, traced ahead with the surfaces so a reveal doesn't have to.
    @State private var tracedSkeleton: [CGRect]?
    /// The skeleton's shape as an image, traced with the surfaces: drawn from its first frame,
    /// where the live shape takes a frame or two to appear.
    @State private var skeletonImage: Image?

    /// Sizes that differ by less than half a point trace the same.
    static func same(_ a: CGSize, _ b: CGSize) -> Bool {
        abs(a.width - b.width) < 0.5 && abs(a.height - b.height) < 0.5
    }

    /// How long content takes to fade back to its skeleton on reload, and the skeleton to come in.
    static var exitFade: Double { 0.22 }

    init(content: Content, placeholder: Placeholder?, isLoading: Bool, source: SkeletonSource, label: Text?, onReveal: (() -> Void)?) {
        self.content = content
        self.placeholder = placeholder
        self.isLoading = isLoading
        self.source = source
        self.label = label
        self.onReveal = onReveal
        _progress = State(initialValue: isLoading ? 0 : 1)
    }

    var body: some View {
        if isDrawingSkeleton {
            // Inside another region's skeleton: be part of its shape, nothing more.
            if let placeholder {
                content.opacity(0).overlay(alignment: .topLeading) { placeholder }
            } else {
                content
            }
        } else {
            region
        }
    }

    private var debug: SkeletonDebugOptions {
        localDebug.union(SkeletonDebugCenter.shared.options)
    }

    private var shimmerAxis: CGVector {
        theme.direction.unitVector(layoutDirection: layoutDirection)
    }

    /// The content's visibility. While loading it is only ever fading out (after a reload), or
    /// faint under x-ray.
    private var incomingProgress: Double {
        guard isLoading else { return progress }
        return max(progress, debug.contains(.xray) ? 0.3 : 0)
    }

    private var showsSkeleton: Bool {
        (isLoading && held) || isRevealing
    }

    private var region: some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                naturalHeight = height
                if isLoading { pinnedHeight = height }
            }
            .modifier(EnterEffect(enter: spec.enter, rest: enterRest))
            .modifier(RevealLayer(progress: incomingProgress, role: .incoming, spec: spec, plan: isLoading ? nil : plan, shimmerAxis: shimmerAxis))
            .modifier(FrameFadeMask(fade: fade?.fadesOutContent == true ? fade : nil, fadingIn: false))
            .accessibilityHidden(isLoading)
            .allowsHitTesting(!isLoading)
            // The content changes at once, unseen; only this frame eases from the skeleton's
            // height to the content's, so nothing crossfades and the page never jumps.
            .frame(height: pinnedHeight, alignment: .top)
            .background(alignment: .topLeading) {
                if showsSkeleton, let cut = surfaceInk ?? plan?.bareInk {
                    SurfaceLayer(content: content, ink: cut, size: surfaceSize, plan: isLoading ? nil : plan)
                        .frame(height: pinnedHeight, alignment: .top)
                        .modifier(FrameFadeMask(fade: fade, fadingIn: true))
                }
            }
            .overlay(alignment: .topLeading) {
                if showsSkeleton {
                    skeletonLayer
                        // While a reload fades the content off, the content keeps `progress` at 1 under
                        // its own fade, and the skeleton is already fully up under its own.
                        .modifier(RevealLayer(progress: fade?.fadesOutContent == true ? 0 : progress, role: .outgoing, spec: spec, plan: plan, shimmerAxis: shimmerAxis))
                        .modifier(FrameFadeMask(fade: fade, fadingIn: true, leads: true))
                }
            }
            .overlay {
                if isLoading {
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(label ?? Text("Loading"))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .overlay {
                if debug.contains(.outlines) {
                    if isLoading {
                        DebugOutline(state: .loading(source))
                    } else if let moved {
                        DebugOutline(state: .revealed(moved: moved))
                    }
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: frame.size) { _, size in
                if isLoading, held, !Self.same(size, surfaceSize) { traceSurfaces() }
            }
            .task(id: isLoading) { await waitOutHold() }
            .onChange(of: isLoading) { _, loading in
                if loading { startLoading() } else { finishLoading() }
            }
    }

    @ViewBuilder
    private var skeletonLayer: some View {
        ShimmerFill(groupFrame: frame)
            .mask(alignment: .topLeading) {
                if let skeletonImage, Self.same(surfaceSize, frame.size) {
                    skeletonImage
                } else if let placeholder {
                    SkeletonShape(content: placeholder)
                } else {
                    SkeletonShape(content: content)
                }
            }
    }

    // MARK: Loading

    private func waitOutHold() async {
        guard isLoading, !held else { return }
        // The hold keeps a fast first load from flashing a skeleton. (After a reload the skeleton
        // comes back in `startLoading`, once the content has faded out.)
        guard !hasRevealed else { return }
        let hold = min(max(reveal.hold, 0), 1)
        if hold > 0 {
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled, isLoading, !held else { return }
        }
        showSkeleton()
        warnIfUnsized()
    }

    /// - Parameter fadingOutContent: On a reload, the content fades off as the skeleton comes up.
    private func showSkeleton(fadingOutContent: Bool = false) {
        if surfaceInk == nil || !Self.same(surfaceSize, frame.size) {
            // On screen the surfaces come with the skeleton; below it they can wait.
            if frame.intersects(ScreenBounds.current) { traceSurfaces() } else { traceWhenIdle() }
        }
        held = true
        heldSince = Date()
        sizeWhileLoading = frame.size
        guard !reduceMotion else { return }
        // Timed by drawn frames: the frame that mounts a page of skeletons takes a moment to
        // draw, and a fade on the wall clock would be over before it showed.
        let next = FrameFade(duration: Self.exitFade, fadesOutContent: fadingOutContent)
        fade = next
        let id = revealID
        Task { @MainActor in
            let giveUp = Date().addingTimeInterval(Self.exitFade * 3 + 1)
            while next.clock.elapsed < next.duration, Date() < giveUp {
                try? await Task.sleep(for: .seconds(0.03))
            }
            guard id == revealID, fade === next else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if fadingOutContent { progress = 0 }
                fade = nil
            }
        }
    }

    /// The surfaces' cut, and then, when the page is quiet, the skeleton's pieces for the reveal.
    private func traceSurfaces() {
        // Sharp, and grown by half a point, so the cut meets the skeleton's own edge with no
        // fringe of the picture or control it stands for.
        let scale = min(environment.displayScale, 2)
        surfaceSize = frame.size
        tracedSkeleton = nil
        // Only when the offscreen trace drew something: otherwise the live shape draws the skeleton.
        skeletonImage = PieceTracer.shape(of: placeholder.map { AnyView($0) } ?? AnyView(content), size: frame.size, environment: environment, scale: scale)
            .flatMap { PieceTracer.hasCoverage($0) ? $0 : nil }
            .map { Image(decorative: $0, scale: scale) }
        #if DEBUG
        if skeletonImage == nil, frame.width >= 1, frame.height >= 1 {
            SampleTemplate.logger.notice("A skeleton at y \(Int(frame.minY), privacy: .public) couldn't be traced offscreen, so it's drawn live and its reveal crossfades. Views backed by UIKit or AppKit, or reading environment objects that aren't in the environment, can't be drawn offscreen.")
        }
        #endif
        surfaceInk = PieceTracer.bareRender(of: content, size: frame.size, environment: environment, scale: scale)
            .flatMap { PieceTracer.coverage(of: $0, page: environment.colorScheme == .dark ? 0 : 1, grow: 1) }
            .map { Image(decorative: $0, scale: scale) }
        let id = revealID
        IdleWork.enqueue {
            guard id == revealID, Self.same(surfaceSize, frame.size), tracedSkeleton == nil else { return false }
            tracedSkeleton = tracePieces(of: placeholder.map { AnyView($0) } ?? AnyView(content), size: frame.size)
            return true
        }
    }

    private func traceWhenIdle() {
        let id = revealID
        IdleWork.enqueue {
            guard id == revealID, surfaceInk == nil || !Self.same(surfaceSize, frame.size) else { return false }
            traceSurfaces()
            return true
        }
    }

    private func startLoading() {
        moved = nil
        revealID += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isRevealing = false
            plan = nil
            enterRest = 0
            pinnedHeight = naturalHeight
        }
        guard hasRevealed else {
            withTransaction(transaction) { progress = 0 }
            return
        }
        guard !reduceMotion else {
            withTransaction(transaction) { progress = 0 }
            showSkeleton()
            return
        }
        // Content that was on screen fades off its skeleton, which comes up underneath it as it
        // goes, so the page never empties.
        showSkeleton(fadingOutContent: true)
    }

    // MARK: Revealing

    private func finishLoading() {
        let wasShowing = held
        fade = nil
        let screen = ScreenBounds.current
        revealID += 1
        let id = revealID
        let isRefetch = hasRevealed
        hasRevealed = true
        let context = RevealContext(
            skeletonShownFor: wasShowing ? heldSince.map { Date().timeIntervalSince($0) } : nil,
            size: frame.size,
            isRefetch: isRefetch,
            isInteracting: SkeletonInput.isInteracting,
            reduceMotion: reduceMotion
        )
        // Off screen there's nothing to see arrive: show it at once and skip the tracing.
        let onScreen = frame.intersects(screen)
        // A cascade still needs to know how many pieces there are, for `choose`.
        let skeletonSize = sizeWhileLoading ?? frame.size
        let skeletonPieces: [CGRect] = !(wasShowing && onScreen) ? []
            : (Self.same(surfaceSize, skeletonSize) ? tracedSkeleton : nil)
            ?? tracePieces(of: placeholder.map { AnyView($0) } ?? AnyView(content), size: skeletonSize)
        var counted = context
        counted.pieces = skeletonPieces.count
        var resolved = reveal.resolved(for: counted)
        // Content that can't be traced offscreen (a view that only exists in the live hierarchy,
        // say) has no pieces to cascade. Crossfade it rather than show it all at once.
        if wasShowing, onScreen, case .custom = resolved.order, resolved.wipe == nil, skeletonPieces.isEmpty {
            resolved.order = .together
            resolved.duration = max(resolved.duration, 0.25)
        }

        guard wasShowing, onScreen, resolved.duration > 0 else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spec = resolved
                progress = 1
                enterRest = 0
                held = false
                pinnedHeight = nil
            }
            done(id: id, revealed: wasShowing)
            return
        }

        if case .custom(let order) = resolved.order, resolved.wipe == nil {
            // Ordered: hold the skeleton until every reveal landing alongside this one is in,
            // then each piece wipes in on one cascade down the page.
            let region = frame
            let contentPieces = tracePieces(of: content, size: frame.size)
            // One pixel a point is enough: the ink is grown past the letters' edges, and the wipe
            // is feathered.
            let inkScale: CGFloat = 1
            let inkRender = PieceTracer.inkRender(of: content, size: frame.size, environment: environment, scale: inkScale)
            let bareRender = PieceTracer.bareRender(of: content, size: frame.size, environment: environment, scale: inkScale)
            let page: Double = environment.colorScheme == .dark ? 0 : 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spec = resolved
                isRevealing = true
                progress = 0
            }
            let global = (contentPieces + skeletonPieces).map { $0.offsetBy(dx: region.minX, dy: region.minY) }
            Task { @MainActor in
                // The pixel work runs off the main thread, alongside the batch's wait, so the
                // cascade's clock starts only once there's nothing left to hold up its frames.
                async let masks = Task.detached(priority: .userInitiated) { () -> (CGImage?, CGImage?) in
                    (inkRender.flatMap { PieceTracer.coverage(of: $0, page: page) },
                     bareRender.flatMap { PieceTracer.coverage(of: $0, page: page, grow: 1) })
                }.value
                let (pageRows, batch) = await RevealBatch.joinBatch(global)
                let (inkMask, bareCut) = await masks
                guard id == revealID else { return }
                var next = RevealPlan.make(
                    order: order,
                    content: contentPieces,
                    skeleton: skeletonPieces,
                    region: region,
                    screen: screen,
                    pageRows: pageRows,
                    delay: resolved.delay,
                    fade: resolved.duration,
                    rightToLeft: layoutDirection == .rightToLeft
                )
                next.ink = inkMask.map { Image(decorative: $0, scale: inkScale) }
                // On a refetch the surfaces were traced from this same data: their cut is sharper.
                next.bareInk = isRefetch && Self.same(surfaceSize, region.size) ? surfaceInk : bareCut.map { Image(decorative: $0, scale: inkScale) }
                next.inkSize = region.size
                RevealBatch.queue(&next, region: region, batch: batch)
                withTransaction(transaction) {
                    plan = next
                    progress = 1
                    enterRest = resolved.enter == .none ? 0 : 1
                }
                if resolved.enter != .none {
                    withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: next.end)) { enterRest = 0 }
                }
                releaseHeight()
                try? await Task.sleep(for: .seconds(next.end + 0.05))
                // A stall slows the cascade's own clock; finish when it has run, not the wall's.
                // (Never past a few times its length, should its layers stop being drawn.)
                let giveUp = Date().addingTimeInterval(next.end * 3 + 1)
                while id == revealID, next.clock.elapsed < next.end, Date() < giveUp {
                    try? await Task.sleep(for: .seconds(0.05))
                }
                guard id == revealID else { return }
                finish(id: id)
            }
            return
        }

        // Together, or a wipe: one animated progress.
        var duration = resolved.duration
        var chosen = resolved
        if case .sweep = resolved.wipe {
            // At the shimmer's pace; content taller than a screen and a half crossfades instead.
            if frame.height > screen.height * 1.5 {
                chosen.wipe = nil
                chosen.order = .together
                duration = 0.2
            } else {
                let pace = ShimmerFill.pace(speed: theme.speed)
                duration = min(max(ShimmerFill.extent(of: frame.size, along: shimmerAxis) / pace, 0.25), 1)
            }
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            spec = chosen
            plan = nil
            enterRest = chosen.enter == .none ? 0 : 1
            isRevealing = true
        }
        releaseHeight()
        let curve = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: duration).delay(chosen.delay)
        withAnimation(curve) {
            progress = 1
            enterRest = 0
        } completion: {
            guard id == revealID else { return }
            finish(id: id)
        }
    }

    /// Lets the pinned height go, easing to the content's own.
    private func releaseHeight() {
        guard pinnedHeight != nil else { return }
        if reduceMotion {
            pinnedHeight = nil
        } else {
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.28)) { pinnedHeight = nil }
        }
    }

    private func finish(id: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isRevealing = false
            held = false
            plan = nil
        }
        done(id: id, revealed: true)
    }

    private func done(id: Int, revealed: Bool) {
        // Ready for a reload: traced once the page has settled, so the work never lands under
        // a cascade or a reload's fade.
        IdleWork.enqueue {
            guard id == revealID, !isLoading else { return false }
            traceSurfaces()
            return true
        }
        if let before = sizeWhileLoading {
            moved = (naturalHeight ?? frame.height) - before.height
            warnIfMoved(by: moved ?? 0)
        }
        if revealed {
            onReveal?()
            AccessibilityNotification.LayoutChanged().post()
        }
    }

    private func tracePieces<V: View>(of view: V, size: CGSize) -> [CGRect] {
        PieceTracer.pieces(of: view, size: size, environment: environment)
    }

    // MARK: Development warnings

    private func warnIfMoved(by moved: CGFloat) {
        #if DEBUG
        guard abs(moved) >= 1 else { return }
        SampleTemplate.logger.notice("A skeleton (\(source.rawValue, privacy: .public)) at y \(Int(frame.minY), privacy: .public) was \(Int(abs(moved)), privacy: .public)pt \(moved > 0 ? "shorter" : "taller", privacy: .public) than its content, so the page moved when it arrived. Give the sample typical lengths.")
        #endif
    }

    private func warnIfUnsized() {
        #if DEBUG
        if frame.height < 1 || frame.width < 1 {
            SampleTemplate.logger.notice("A skeleton has no size while loading, so there's nothing to draw. Give images and empty views a frame or an aspect ratio.")
        }
        #endif
    }
}

/// A fade timed by the frames drawn, not the wall clock. See ``RevealClock``.
final class FrameFade {
    let clock = RevealClock()
    let start = Date()
    let duration: Double
    /// Also fades the content out, on a reload.
    let fadesOutContent: Bool

    init(duration: Double, fadesOutContent: Bool) {
        self.duration = duration
        self.fadesOutContent = fadesOutContent
    }

    /// - Parameter leads: The skeleton's own frames move the fade on; the others follow, so the
    ///   content never fades ahead of a skeleton that hasn't been drawn yet.
    func amount(at date: Date, leads: Bool) -> Double {
        let t = leads ? clock.time(at: date, start: start) : clock.elapsed
        let x = min(max(t / duration, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

/// Fades a layer by a ``FrameFade``. The mask is always there, so the layer keeps its identity.
struct FrameFadeMask: ViewModifier {
    var fade: FrameFade?
    var fadingIn: Bool
    var leads = false

    func body(content: Content) -> some View {
        content.mask {
            if let fade {
                TimelineView(.animation) { timeline in
                    let shown = fade.amount(at: timeline.date, leads: leads)
                    Rectangle().fill(.black).opacity(fadingIn ? shown : 1 - shown)
                }
            } else {
                Rectangle().fill(.black)
            }
        }
    }
}
