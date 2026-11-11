import SwiftUI

/// One line of text with a highlight passing over its letters, for work that's under way.
///
/// Use it for a single loading line, such as an AI tool call that's running. It shares the
/// skeletons' clock, so it shimmers in step with them, and it breathes gently under Reduce
/// Motion.
///
/// ```swift
/// ShimmerText("Looking at your sleep")
/// ShimmerText(isActive: call.isRunning) { Text(call.title).font(.callout) }
/// ```
public struct ShimmerText<Label: View>: View {
    private let isActive: Bool
    private let label: Label

    /// Shimmers any text, or any view, while `isActive` is true.
    public init(isActive: Bool = true, @ViewBuilder label: () -> Label) {
        self.isActive = isActive
        self.label = label()
    }

    public var body: some View {
        label
            .shimmer(isActive)
            .accessibilityAddTraits(isActive ? .updatesFrequently : [])
    }
}

extension ShimmerText where Label == Text {
    /// Shimmers a line of text while `isActive` is true.
    public init(_ title: LocalizedStringKey, isActive: Bool = true) {
        self.init(isActive: isActive) { Text(title) }
    }

    /// Shimmers a line of text while `isActive` is true.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, isActive: Bool = true) {
        self.init(isActive: isActive) { Text(title) }
    }
}

extension View {
    /// Passes the skeletons' shimmer over this view's own pixels while `isActive` is true.
    ///
    /// The view is dimmed to its secondary tone and a band of its full colour sweeps across it,
    /// in step with every skeleton on screen.
    public func shimmer(_ isActive: Bool = true) -> some View {
        modifier(Shimmering(isActive: isActive))
    }
}

private struct Shimmering: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            // The view rests at a quiet tone, and a band of it at full strength passes over.
            content
                .opacity(0.4)
                .overlay {
                    content
                        .mask {
                            ShimmerFill(paint: .highlightOnly(.black))
                                .skeletonTheme { $0.bandWidth = min($0.bandWidth, 140) }
                        }
                        .accessibilityHidden(true)
                }
        } else {
            content
        }
    }
}
