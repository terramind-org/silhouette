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
        case .typical: 1.2
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
    private var task: Task<Void, Never>?

    init(_ make: @escaping () -> Value) {
        self.make = make
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
        let seconds = Response.current.seconds
        task = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            value = make()
        }
    }
}

/// One demo page: a short line on what it shows and which part of Skullet it mirrors, then the
/// demo itself. Tap the demo, or the toolbar button, to load it again.
struct DemoPage<Content: View>: View {
    var title: String
    var mirrors: String
    var note: String
    var reload: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Skullet: \(mirrors)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                content
                    .contentShape(.rect)
                    .onTapGesture(perform: reload)
                    .accessibilityAction(named: "Reload", reload)
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
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

/// A rounded card on the grouped background.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.quaternary))
    }
}

/// Initials on a coloured disc.
struct Avatar: View {
    var initials: String
    var color: Color
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(Text(initials).font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(.white))
            .accessibilityHidden(true)
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
