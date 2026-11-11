import Silhouette
import SwiftUI

@main
struct SilhouetteDemoApp: App {
    init() {
        #if os(iOS)
        FrameRecorder.startIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DemoIndex()
                // `-dark YES` or `-light YES` at launch, for screenshots, without changing the device.
                .preferredColorScheme(UserDefaults.standard.bool(forKey: "dark") ? .dark : UserDefaults.standard.bool(forKey: "light") ? .light : nil)
        }
    }
}

enum DemoRoute: String, CaseIterable, Identifiable, Hashable {
    case showcase, component, plain, own, hints, memory
    case reveals, images, size, ownReveal, async
    case theming, shimmerText, accessibility, debug

    var id: Self { self }

    var title: String {
        switch self {
        case .showcase: "Showcase"
        case .component: "From your component"
        case .plain: "Plain children"
        case .own: "Your own skeleton"
        case .hints: "Hints"
        case .memory: "Memory"
        case .reveals: "Reveal modes"
        case .images: "Images"
        case .size: "Changing size"
        case .ownReveal: "Your own reveal"
        case .async: "AsyncSkeleton"
        case .theming: "Theming"
        case .shimmerText: "ShimmerText"
        case .accessibility: "Accessibility"
        case .debug: "Debugging"
        }
    }

    var symbol: String {
        switch self {
        case .showcase: "sparkles.rectangle.stack"
        case .component: "person.crop.rectangle"
        case .plain: "text.alignleft"
        case .own: "chart.bar"
        case .hints: "hand.point.up.left"
        case .memory: "memorychip"
        case .reveals: "rectangle.on.rectangle.angled"
        case .images: "photo.on.rectangle"
        case .size: "arrow.up.and.down"
        case .ownReveal: "wand.and.stars"
        case .async: "arrow.triangle.2.circlepath"
        case .theming: "paintpalette"
        case .shimmerText: "text.badge.checkmark"
        case .accessibility: "accessibility"
        case .debug: "ladybug"
        }
    }

    @ViewBuilder @MainActor
    var page: some View {
        switch self {
        case .showcase: ShowcasePage()
        case .component: FromComponentPage()
        case .plain: PlainChildrenPage()
        case .own: OwnSkeletonPage()
        case .hints: HintsPage()
        case .memory: MemoryPage()
        case .reveals: RevealModesPage()
        case .images: ImagesPage()
        case .size: ChangingSizePage()
        case .ownReveal: OwnRevealPage()
        case .async: AsyncPage()
        case .theming: ThemingPage()
        case .shimmerText: ShimmerTextPage()
        case .accessibility: AccessibilityPage()
        case .debug: DebugPage()
        }
    }

    static let sections: [(String, [DemoRoute])] = [
        ("", [.showcase]),
        ("Skeletons", [.component, .plain, .own, .hints, .memory]),
        ("Reveals", [.reveals, .images, .size, .ownReveal, .async]),
        ("Styling and reference", [.theming, .shimmerText, .accessibility, .debug]),
    ]
}

struct DemoIndex: View {
    /// `-demo theming` at launch opens a page directly, for screenshots and recordings.
    @State private var path: [DemoRoute] = UserDefaults.standard.string(forKey: "demo").flatMap(DemoRoute.init(rawValue:)).map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(DemoRoute.sections, id: \.0) { title, routes in
                    Section(title) {
                        ForEach(routes) { route in
                            NavigationLink(value: route) {
                                Label(route.title, systemImage: route.symbol)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Silhouette")
            .navigationDestination(for: DemoRoute.self) { $0.page }
        }
    }
}
