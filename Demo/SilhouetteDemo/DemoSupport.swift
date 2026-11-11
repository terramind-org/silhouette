import Observation
import Silhouette
import SwiftUI

/// How long the demo's fake network takes, like the response switch on Skullet's site.
enum Response: String, CaseIterable, Identifiable {
    case fast, typical, slow
    var id: Self { self }

    var seconds: Double {
        switch self {
        case .fast: 0.1
        case .typical: 1.4
        case .slow: 3
        }
    }

    static var current: Response {
        Response(rawValue: UserDefaults.standard.string(forKey: "response") ?? "") ?? .typical
    }
}

/// A value that arrives after the current response time, and can be fetched again.
@MainActor @Observable
final class DemoLoad<Value> {
    private(set) var value: Value?
    private let make: () -> Value
    /// Scales the response time, so cards on one page land at slightly different moments.
    private let latency: Double
    private var task: Task<Void, Never>?

    init(latency: Double = 1, _ make: @escaping () -> Value) {
        self.make = make
        self.latency = latency
        reload()
    }

    /// Clears the value and fetches it again.
    func reload() {
        value = nil
        refetch()
    }

    /// Fetches again while the old value stays on screen.
    func refetch() {
        task?.cancel()
        let seconds = Response.current.seconds * latency
        task = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            value = make()
        }
    }
}

/// One feature page: a title and a line on what it shows, the demo, and the code.
struct DemoPage<Content: View>: View {
    var title: String
    var note: String
    var reload: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.system(size: 30, weight: .bold))
                    Text(note).font(.system(size: 16)).foregroundStyle(Palette.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .skeletonTracksScrolling()
        .background(Palette.page.ignoresSafeArea())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // `-autoreload 4` loads the page again every four seconds, for recordings.
            let every = UserDefaults.standard.double(forKey: "autoreload")
            guard every > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if !Task.isCancelled { reload() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reload", systemImage: "arrow.clockwise", action: reload)
                    .accessibilityIdentifier("reload")
            }
        }
    }
}

/// A demo you can tap to load again, with a quiet caption under it.
struct Reloadable<Content: View>: View {
    var caption: String = "Tap to reload"
    var reload: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) {
            content
                .contentShape(.rect)
                .onTapGesture(perform: reload)
                .accessibilityAction(named: "Reload", reload)
            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondary.opacity(0.8))
        }
    }
}

/// A short code sample under a demo.
struct CodeNote: View {
    var code: String
    init(_ code: String) { self.code = code }

    var body: some View {
        Text(code)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline))
    }
}

/// The response-time picker that sits above demos where timing matters.
struct ResponsePicker: View {
    @AppStorage("response") private var response: Response = .typical

    var body: some View {
        Picker("Response", selection: $response) {
            ForEach(Response.allCases) { Text($0.rawValue.capitalized).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

/// A segmented choice with a label.
struct Choice<T: Hashable>: View {
    var title: String
    @Binding var selection: T
    var options: [(T, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(Palette.secondary)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
