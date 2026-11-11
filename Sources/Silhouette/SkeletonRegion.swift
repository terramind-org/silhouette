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

    /// 0 shows the skeleton, 1 the content. Animated for crossfades and wipes.
    @State private var progress: Double
    /// 1 at the start of an entrance, 0 once arrived.
    @State private var enterRest: Double = 0
    /// Whether the skeleton has waited out the reveal's hold and is showing.
    @State private var held = false
    @State private var heldSince: Date?
    @State private var hasRevealed = false
    @State private var isRevealing = false
    @State private var spec = SkeletonReveal.together
    @State private var plan: RevealPlan?
    @State private var frame: CGRect = .zero
    @State private var sizeWhileLoading: CGSize?
    @State private var moved: CGFloat?
    @State private var revealID = 0

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

    /// While loading, the content is never visible, whatever a reveal left behind; x-ray shows
    /// it faintly.
    private var incomingProgress: Double {
        guard isLoading else { return progress }
        return debug.contains(.xray) ? 0.3 : 0
    }

    private var showsSkeleton: Bool {
        (isLoading && held) || isRevealing
    }

    private var region: some View {
        content
            // New data of a different size eases to its new height. Scoped to the content, so it
            // never retimes the reveal around it.
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: 0.28), value: isLoading)
            .modifier(EnterEffect(enter: spec.enter, rest: enterRest))
            .modifier(RevealLayer(progress: incomingProgress, role: .incoming, spec: spec, plan: isLoading ? nil : plan, shimmerAxis: shimmerAxis))
            .accessibilityHidden(isLoading)
            .allowsHitTesting(!isLoading)
            .overlay(alignment: .topLeading) {
                if showsSkeleton {
                    skeletonLayer
                        .modifier(RevealLayer(progress: progress, role: .outgoing, spec: spec, plan: plan, shimmerAxis: shimmerAxis))
                        .transition(hasRevealed ? .identity : .opacity.animation(.easeOut(duration: 0.2)))
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
            .task(id: isLoading) { await waitOutHold() }
            .onChange(of: isLoading) { _, loading in
                if loading { startLoading() } else { finishLoading() }
            }
    }

    @ViewBuilder
    private var skeletonLayer: some View {
        ShimmerFill(groupFrame: frame)
            .mask {
                if let placeholder {
                    SkeletonShape(content: placeholder)
                } else {
                    SkeletonShape(content: content)
                }
            }
    }

    // MARK: Phases

    private func waitOutHold() async {
        guard isLoading, !held else { return }
        // The hold keeps a fast first load from flashing a skeleton. (Content that was already on
        // screen goes straight to its skeleton in `startLoading`.)
        let hold = min(max(reveal.hold, 0), 1)
        if hold > 0 {
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled, isLoading, !held else { return }
        }
        held = true
        heldSince = Date()
        sizeWhileLoading = frame.size
        warnIfUnsized()
    }

    private func startLoading() {
        moved = nil
        revealID += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isRevealing = false
            plan = nil
            progress = 0
            enterRest = 0
            // Content that was on screen goes straight to its skeleton, with no blank beat.
            held = hasRevealed
        }
        if held {
            heldSince = Date()
            sizeWhileLoading = frame.size
        }
    }

    private func finishLoading() {
        let wasShowing = held
        let screen = ScreenBounds.current
        // The pieces the skeleton showed, and the pieces of what replaces it.
        let skeletonPieces: [CGRect] = wasShowing ? tracePieces(of: placeholder.map { AnyView($0) } ?? AnyView(content), size: sizeWhileLoading ?? frame.size) : []
        let context = RevealContext(
            skeletonShownFor: wasShowing ? heldSince.map { Date().timeIntervalSince($0) } : nil,
            size: frame.size,
            pieces: skeletonPieces.count,
            isRefetch: hasRevealed,
            isInteracting: SkeletonInput.isInteracting,
            reduceMotion: reduceMotion
        )
        let resolved = reveal.resolved(for: context)
        hasRevealed = true
        revealID += 1
        let id = revealID

        let done = {
            guard id == revealID else { return }
            isRevealing = false
            held = false
            plan = nil
            if let before = sizeWhileLoading {
                moved = frame.size.height - before.height
                warnIfMoved(by: moved ?? 0)
            }
            if wasShowing {
                onReveal?()
                AccessibilityNotification.LayoutChanged().post()
            }
        }

        guard wasShowing, resolved.duration > 0 else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spec = resolved
                progress = 1
                enterRest = 0
            }
            done()
            return
        }

        if case .custom(let order) = resolved.order, resolved.wipe == nil {
            // Ordered: each piece fades in where its skeleton was, on the shared clock.
            let contentPieces = tracePieces(of: content, size: frame.size)
            let next = RevealPlan.make(
                order: order,
                content: contentPieces,
                skeleton: skeletonPieces,
                region: frame,
                screen: screen,
                late: RevealBatch.join(),
                delay: resolved.delay,
                fade: resolved.duration
            )
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spec = resolved
                plan = next
                progress = 1
                enterRest = resolved.enter == .none ? 0 : 1
                isRevealing = true
            }
            if resolved.enter != .none {
                withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: next.end)) { enterRest = 0 }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(next.end + 0.05))
                done()
            }
            return
        }

        // Together, or a wipe: one animated progress.
        var duration = resolved.duration
        if case .sweep = resolved.wipe {
            // At the shimmer's pace; content taller than a screen and a half crossfades instead.
            if frame.height > screen.height * 1.5 {
                var crossfade = resolved
                crossfade.wipe = nil
                crossfade.order = .together
                return run(crossfade, duration: 0.2, done: done)
            }
            let pace = ShimmerFill.pace(speed: theme.speed)
            duration = min(max(ShimmerFill.extent(of: frame.size, along: shimmerAxis) / pace, 0.25), 1)
        }
        run(resolved, duration: duration, done: done)
    }

    private func run(_ resolved: SkeletonReveal, duration: Double, done: @escaping () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            spec = resolved
            plan = nil
            enterRest = resolved.enter == .none ? 0 : 1
            isRevealing = true
        }
        let curve = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: duration).delay(resolved.delay)
        withAnimation(curve) {
            progress = 1
            enterRest = 0
        } completion: {
            done()
        }
    }

    private func tracePieces<V: View>(of view: V, size: CGSize) -> [CGRect] {
        PieceTracer.pieces(of: view, size: size, environment: environment)
    }

    // MARK: Development warnings

    private func warnIfMoved(by moved: CGFloat) {
        #if DEBUG
        guard abs(moved) >= 1 else { return }
        SampleTemplate.logger.notice("A skeleton (\(source.rawValue, privacy: .public)) was \(Int(abs(moved)), privacy: .public)pt \(moved > 0 ? "shorter" : "taller", privacy: .public) than its content, so the page moved when it arrived. Give the sample typical lengths.")
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
