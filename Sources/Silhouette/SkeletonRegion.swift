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
        modifier(SkeletonRegion(isLoading: isLoading, placeholder: Optional<EmptyView>.none, source: .content, label: label, onReveal: onReveal))
    }
}

/// A region of the screen that shows a skeleton while it loads and reveals its content after.
struct SkeletonRegion<Placeholder: View>: ViewModifier {
    var isLoading: Bool
    /// Drawn as the skeleton's shape instead of the content, when given.
    var placeholder: Placeholder?
    var source: SkeletonSource
    var label: Text?
    var onReveal: (() -> Void)?

    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    @Environment(\.skeletonReveal) private var reveal
    @Environment(\.skeletonTheme) private var theme
    @Environment(\.skeletonDebug) private var localDebug
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 shows the skeleton, 1 the content. Animated during a reveal.
    @State private var progress: Double
    /// Whether the skeleton has waited out the reveal's hold and is showing.
    @State private var held = false
    @State private var loadingSince: Date?
    @State private var heldSince: Date?
    @State private var hasRevealed = false
    @State private var isRevealing = false
    @State private var spec = SkeletonReveal.together
    @State private var frame: CGRect = .zero
    @State private var sizeWhileLoading: CGSize?
    @State private var moved: CGFloat?

    init(isLoading: Bool, placeholder: Placeholder?, source: SkeletonSource, label: Text?, onReveal: (() -> Void)?) {
        self.isLoading = isLoading
        self.placeholder = placeholder
        self.source = source
        self.label = label
        self.onReveal = onReveal
        _progress = State(initialValue: isLoading ? 0 : 1)
        _loadingSince = State(initialValue: isLoading ? Date() : nil)
    }

    func body(content: Content) -> some View {
        if isDrawingSkeleton {
            // Inside another region's skeleton: be part of its shape, nothing more.
            if let placeholder {
                content.opacity(0).overlay(alignment: .topLeading) { placeholder }
            } else {
                content
            }
        } else {
            region(content)
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

    @ViewBuilder
    private func region(_ content: Content) -> some View {
        content
            // New data of a different size eases to its new height. Scoped to the content, so it
            // never retimes the reveal around it.
            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: isLoading)
            .modifier(RevealEffect(progress: incomingProgress, spec: spec, role: .incoming, shimmerAxis: shimmerAxis))
            .accessibilityHidden(isLoading)
            .allowsHitTesting(!isLoading)
            .overlay(alignment: .topLeading) {
                if showsSkeleton {
                    skeletonLayer(content)
                        .modifier(RevealEffect(progress: progress, spec: spec, role: .outgoing, shimmerAxis: shimmerAxis))
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
    private func skeletonLayer(_ content: Content) -> some View {
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
    }

    private func startLoading() {
        loadingSince = Date()
        moved = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isRevealing = false
            progress = 0
            // Content that was on screen goes straight to its skeleton, with no blank beat.
            held = hasRevealed
        }
        if held {
            heldSince = Date()
            sizeWhileLoading = frame.size
        }
    }

    private func finishLoading() {
        let context = RevealContext(
            skeletonShownFor: held ? heldSince.map { Date().timeIntervalSince($0) } : nil,
            size: frame.size,
            isRefetch: hasRevealed,
            reduceMotion: reduceMotion
        )
        let resolved = reveal.resolved(for: context)
        let wasShowing = held
        spec = resolved
        hasRevealed = true

        let done = {
            isRevealing = false
            held = false
            if let before = sizeWhileLoading { moved = frame.size.height - before.height }
            if wasShowing {
                onReveal?()
                AccessibilityNotification.LayoutChanged().post()
            }
        }

        guard wasShowing, resolved.duration > 0 else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { progress = 1 }
            done()
            return
        }
        isRevealing = true
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: resolved.duration).delay(resolved.delay)) {
            progress = 1
        } completion: {
            done()
        }
    }
}
