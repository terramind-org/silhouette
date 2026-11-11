import SwiftUI

/// Shows your content once its data arrives, and a skeleton of it until then.
///
/// Pass the data, which is `nil` while it loads, and a sample of it. While `data` is `nil`,
/// your content is built from the sample, laid out unseen, and traced into a skeleton in its
/// place. Your content only ever receives real data on screen.
///
/// ```swift
/// Skeleton(user, sample: .sample) { user in
///     ProfileCard(user: user)
/// }
/// ```
///
/// The skeleton is drawn from the closest data there is: the data already on screen, the data
/// last shown under the same `id`, a shape remembered from an earlier launch (for `Codable`
/// data with an `id`), then the sample.
public struct Skeleton<Value, Content: View>: View {
    private let data: Value?
    private let sample: Value?
    private let id: String?
    private let isLoading: Bool
    private let label: Text?
    private let onReveal: (() -> Void)?
    private let content: (Value) -> Content
    private let codec: ShapeCodec<Value>?

    private var customSkeleton: AnyView?
    private var isEmpty = false
    private var emptyContent: AnyView?
    private var error: (any Error)?
    private var errorContent: ((any Error) -> AnyView)?

    @State private var lastShown: Value?

    /// - Parameters:
    ///   - data: The data to show. The skeleton shows while it's `nil`.
    ///   - sample: Stands in for the data to draw the first skeleton. Give it typical lengths.
    ///   - id: Remembers the shape last shown under this key, so the next skeleton is exact.
    ///   - isLoading: Shows the skeleton even over data, for example while a refetch replaces it.
    ///   - label: Read by VoiceOver while loading. "Loading" by default.
    ///   - onReveal: Called once the content has come in over a skeleton.
    ///   - content: Your view, built from the data.
    public init(
        _ data: Value?,
        sample: Value? = nil,
        id: String? = nil,
        isLoading: Bool = false,
        label: Text? = nil,
        onReveal: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.init(data, sample: sample, id: id, isLoading: isLoading, label: label, onReveal: onReveal, codec: nil, content: content)
    }

    /// For `Codable` data, an `id` also remembers the layout across launches: a copy of the data
    /// with its letters, digits and numbers replaced, never the data itself.
    public init(
        _ data: Value?,
        sample: Value? = nil,
        id: String? = nil,
        isLoading: Bool = false,
        label: Text? = nil,
        onReveal: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Value: Codable {
        self.init(data, sample: sample, id: id, isLoading: isLoading, label: label, onReveal: onReveal, codec: .codable, content: content)
    }

    init(
        _ data: Value?, sample: Value?, id: String?, isLoading: Bool, label: Text?, onReveal: (() -> Void)?,
        codec: ShapeCodec<Value>?, content: @escaping (Value) -> Content
    ) {
        self.data = data
        self.sample = sample
        self.id = id
        self.isLoading = isLoading
        self.label = label
        self.onReveal = onReveal
        self.codec = codec
        self.content = content
    }

    // MARK: Options

    /// Draws this instead of a measured skeleton, for content that doesn't trace well.
    public func placeholder<P: View>(@ViewBuilder _ placeholder: () -> P) -> Self {
        var copy = self
        copy.customSkeleton = AnyView(placeholder())
        return copy
    }

    /// Shows `message` in place of the content when the data has arrived but is empty.
    public func empty<E: View>(_ isEmpty: Bool, @ViewBuilder message: () -> E) -> Self {
        var copy = self
        copy.isEmpty = isEmpty
        copy.emptyContent = AnyView(message())
        return copy
    }

    /// Shows your view for an error in place of the content.
    public func failure<F: View>(_ error: (any Error)?, @ViewBuilder content: @escaping (any Error) -> F) -> Self {
        var copy = self
        copy.error = error
        copy.errorContent = { AnyView(content($0)) }
        return copy
    }

    // MARK: Body

    public var body: some View {
        if let error, let errorContent {
            errorContent(error)
        } else if isEmpty, data != nil, let emptyContent {
            emptyContent
        } else {
            loadingRegion
        }
    }

    private var loading: Bool { data == nil || isLoading }

    @ViewBuilder
    private var loadingRegion: some View {
        let standIn = closestData
        SkeletonRegion(
            content: Group {
                if let shown = loading ? (standIn?.value ?? data) : data {
                    content(shown)
                } else {
                    FallbackLines()
                }
            },
            placeholder: placeholder(standIn: standIn?.value),
            isLoading: loading,
            source: customSkeleton != nil ? .custom : (standIn?.source ?? .fallback),
            label: label,
            onReveal: onReveal
        )
        .onAppear {
            if standIn == nil, loading { SampleTemplate.warnNothingToMeasure(Value.self) }
            if let data { remember(data) }
        }
        .onChange(of: data == nil) { _, isNil in
            if !isNil, let data { remember(data) }
        }
    }

    /// What the skeleton is drawn from while revealing: the custom skeleton, or the stand-in it
    /// was showing, so the outgoing skeleton keeps its shape while the new content fades in.
    private func placeholder(standIn: Value?) -> AnyView? {
        if let customSkeleton { return customSkeleton }
        if !loading, let standIn { return AnyView(content(standIn)) }
        return nil
    }

    private var closestData: (value: Value, source: SkeletonSource)? {
        if isLoading, let data { return (data, .onScreen) }
        if let lastShown { return (lastShown, .onScreen) }
        if let id {
            if let value = SkeletonMemory.lastShown(id: id, as: Value.self) { return (value, .lastShown) }
            if let codec, let value = codec.load(id) { return (value, .remembered) }
        }
        if let sample { return (sample, .sample) }
        return nil
    }

    private func remember(_ value: Value) {
        lastShown = value
        if let id {
            SkeletonMemory.remember(value, id: id)
            codec?.save(value, id)
        }
        if sample == nil { SampleTemplate.logMissingSample(for: value) }
    }
}

/// Saves and loads a value's scrubbed shape, for `Codable` values.
struct ShapeCodec<Value> {
    var save: @MainActor (Value, String) -> Void
    var load: @MainActor (String) -> Value?
}

extension ShapeCodec where Value: Codable {
    static var codable: ShapeCodec {
        ShapeCodec(
            save: { value, id in
                // Keep the shape only if it still decodes, so an enum or an identifier that the
                // scrubber broke falls back to the sample instead of failing later.
                guard let data = try? ShapeScrubber.scrub(value),
                      (try? JSONDecoder().decode(Value.self, from: data)) != nil else { return }
                SkeletonMemory.defaults.set(data, forKey: SkeletonMemory.defaultsPrefix + id)
            },
            load: { id in SkeletonMemory.remembered(id: id, as: Value.self) }
        )
    }
}

/// Three lines, drawn when there's nothing to measure.
struct FallbackLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBox(width: .fraction(1))
            SkeletonBox(width: .fraction(0.92))
            SkeletonBox(width: .fraction(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
