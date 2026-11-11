import Observation
import SwiftUI

/// What the debug overlay shows.
public struct SkeletonDebugOptions: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Outlines every loading region: blue while it loads, with where its skeleton came from,
    /// then green if nothing moved when the content arrived, or red with how far it moved.
    public static let outlines = SkeletonDebugOptions(rawValue: 1 << 0)
    /// Shows what was measured: the hidden content shows faintly through its skeleton.
    public static let xray = SkeletonDebugOptions(rawValue: 1 << 1)
    public static let all: SkeletonDebugOptions = [.outlines, .xray]
}

/// Where a skeleton's shape came from, as the debug overlay labels it.
public enum SkeletonSource: String, Sendable {
    /// The data already on screen, loading again.
    case onScreen = "on screen"
    /// The data last shown under the same id, earlier in this launch.
    case lastShown = "last shown"
    /// A shape remembered from an earlier launch.
    case remembered
    /// The sample you passed.
    case sample
    /// Your own skeleton.
    case custom
    /// The content as it is, for `.skeleton(isLoading:)`.
    case content
    /// Three placeholder lines: there was nothing to measure.
    case fallback
}

/// Turns the debug overlay on for the whole app, as `-SilhouetteDebug YES` does at launch.
@MainActor
public func setSkeletonDebug(_ options: SkeletonDebugOptions) {
    SkeletonDebugCenter.shared.options = options
}

@MainActor @Observable
final class SkeletonDebugCenter {
    static let shared = SkeletonDebugCenter()
    var options: SkeletonDebugOptions

    private init() {
        // `-SilhouetteDebug YES` (or `xray`) in the scheme's launch arguments.
        let value = UserDefaults.standard.string(forKey: "SilhouetteDebug")?.lowercased()
        switch value {
        case "xray": options = .all
        case "yes", "true", "1", "outlines": options = .outlines
        default: options = []
        }
    }
}

extension EnvironmentValues {
    /// What the debug overlay shows for skeletons below this view.
    @Entry public var skeletonDebug: SkeletonDebugOptions = []
}

extension View {
    /// Outlines every loading region below this view, and whether its content moved on reveal.
    ///
    /// Pass `.xray` as well to see the hidden content through its skeleton.
    public func skeletonDebug(_ options: SkeletonDebugOptions = .outlines) -> some View {
        environment(\.skeletonDebug, options)
    }
}

/// The outline and tag the debug overlay draws over one region.
struct DebugOutline: View {
    enum State: Equatable {
        case loading(SkeletonSource)
        case revealed(moved: CGFloat)
    }

    var state: State

    var body: some View {
        let (color, tag) = style
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: state == .loading(.content) ? [4, 3] : []))
            .overlay(alignment: .topTrailing) {
                Text(tag)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .offset(y: -8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var style: (Color, String) {
        switch state {
        case .loading(let source): (.blue, source.rawValue)
        case .revealed(let moved) where abs(moved) < 0.5: (.green, "no move")
        case .revealed(let moved): (.red, String(format: "moved %+.0fpt", moved))
        }
    }
}
