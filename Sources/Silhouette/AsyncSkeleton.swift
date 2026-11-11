import SwiftUI

/// Loads a value and shows a skeleton of your content until it arrives.
///
/// The native counterpart of a suspense boundary: give it the async work and the view, and it
/// runs the work when it appears, draws the skeleton from `sample` (or the shape last shown under
/// `id`) while it waits, and reveals the content in place.
///
/// ```swift
/// AsyncSkeleton(sample: Quote.sample) {
///     try await api.quoteOfTheDay()
/// } content: { quote in
///     QuoteCard(quote: quote)
/// }
/// ```
///
/// Change `trigger` to load again. While it reloads, the old content stays on screen.
public struct AsyncSkeleton<Value: Sendable, Content: View>: View {
    private let sample: Value?
    private let id: String?
    private let trigger: AnyHashable?
    private let label: Text?
    private let onReveal: (() -> Void)?
    private let load: @Sendable () async throws -> Value
    private let content: (Value) -> Content
    private let codec: ShapeCodec<Value>?

    @State private var value: Value?
    @State private var error: (any Error)?

    public init(
        sample: Value? = nil,
        id: String? = nil,
        trigger: AnyHashable? = nil,
        label: Text? = nil,
        onReveal: (() -> Void)? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line,
        load: @escaping @Sendable () async throws -> Value,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.init(sample: sample, id: id ?? "\(fileID):\(line)", trigger: trigger, label: label, onReveal: onReveal, codec: nil, load: load, content: content)
    }

    /// For `Codable` values, an `id` also remembers the layout across launches.
    public init(
        sample: Value? = nil,
        id: String? = nil,
        trigger: AnyHashable? = nil,
        label: Text? = nil,
        onReveal: (() -> Void)? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line,
        load: @escaping @Sendable () async throws -> Value,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Value: Codable {
        self.init(sample: sample, id: id ?? "\(fileID):\(line)", trigger: trigger, label: label, onReveal: onReveal, codec: .codable, load: load, content: content)
    }

    init(
        sample: Value?, id: String?, trigger: AnyHashable?, label: Text?, onReveal: (() -> Void)?,
        codec: ShapeCodec<Value>?, load: @escaping @Sendable () async throws -> Value, content: @escaping (Value) -> Content
    ) {
        self.sample = sample
        self.id = id
        self.trigger = trigger
        self.label = label
        self.onReveal = onReveal
        self.codec = codec
        self.load = load
        self.content = content
    }

    @Environment(\.isDrawingSkeleton) private var isDrawingSkeleton

    public var body: some View {
        Skeleton(value, sample: sample, id: id, isLoading: false, label: label, onReveal: onReveal, codec: codec, content: content)
            .failure(error) { error in
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task(id: trigger) {
                // A tracing copy inside another skeleton never starts work.
                guard !isDrawingSkeleton else { return }
                do {
                    let loaded = try await load()
                    error = nil
                    value = loaded
                } catch is CancellationError {
                } catch {
                    self.error = error
                }
            }
    }
}
