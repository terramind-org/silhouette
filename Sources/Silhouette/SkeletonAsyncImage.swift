import SwiftUI

/// A remote image that keeps its own skeleton until it has loaded, then fades in.
///
/// Images never hold back a reveal: the content around one reveals as soon as its data is
/// there, and each image still downloading keeps shimmering in its frame. Give it a size or an
/// aspect ratio, since an image has no size of its own until it loads.
///
/// ```swift
/// SkeletonAsyncImage(url: photo.url) { image in
///     image.resizable().scaledToFill()
/// }
/// .frame(width: 120, height: 120)
/// .clipShape(.rect(cornerRadius: 12))
/// ```
public struct SkeletonAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: (Image) -> Content

    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton
    @Environment(\.skeletonInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    public var body: some View {
        if isDrawingSkeleton {
            // Traced as one block, and never downloaded by the tracing copy.
            Rectangle().fill(ink)
        } else {
            AsyncImage(url: url, scale: scale, transaction: Transaction(animation: reduceMotion ? nil : .easeOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    content(image).transition(.opacity)
                case .failure:
                    // A quiet, still placeholder: nothing more is coming.
                    Rectangle().fill(.secondary.opacity(0.12))
                default:
                    ShimmerFill()
                }
            }
        }
    }
}

extension SkeletonAsyncImage where Content == Image {
    /// Shows the image as it is.
    public init(url: URL?, scale: CGFloat = 1) {
        self.init(url: url, scale: scale) { $0 }
    }
}
