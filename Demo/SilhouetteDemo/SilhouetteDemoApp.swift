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
            DemoRoot()
                // `-dark YES` or `-light YES` at launch, for screenshots, without changing the device.
                .preferredColorScheme(UserDefaults.standard.bool(forKey: "dark") ? .dark : UserDefaults.standard.bool(forKey: "light") ? .light : nil)
                .tint(Palette.accent)
        }
    }
}

enum DemoRoute: String, CaseIterable, Identifiable, Hashable {
    case index
    case component, plain, own, hints, memory
    case reveals, images, size, ownReveal, async
    case theming, shimmerText, accessibility, debug
    case sleep, today, plates

    var id: Self { self }

    var title: String {
        switch self {
        case .index: "Features"
        case .component: "From your view"
        case .plain: "Any view, with a flag"
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
        case .sleep: "Last night"
        case .today: "Today"
        case .plates: "Plates"
        }
    }

    var symbol: String {
        switch self {
        case .index: "list.bullet"
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
        case .sleep: "moon.stars"
        case .today: "sun.max"
        case .plates: "fork.knife"
        }
    }

    @ViewBuilder @MainActor
    var page: some View {
        switch self {
        case .index: FeatureIndex()
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
        case .sleep: SleepPage()
        case .today: TodayPage()
        case .plates: PlatesPage()
        }
    }

    static let sections: [(String, [DemoRoute])] = [
        ("Skeletons", [.component, .plain, .own, .hints, .memory]),
        ("Reveals", [.reveals, .images, .size, .ownReveal, .async]),
        ("Styling and reference", [.theming, .shimmerText, .accessibility, .debug]),
    ]
}

/// The showcase, with every feature page a push away. `-demo <route>` at launch opens a page.
struct DemoRoot: View {
    @State private var path: [DemoRoute] = UserDefaults.standard.string(forKey: "demo").flatMap(DemoRoute.init(rawValue:)).map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            ShowcasePage(path: $path)
                .navigationDestination(for: DemoRoute.self) { $0.page }
        }
    }
}

struct FeatureIndex: View {
    var body: some View {
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
        .navigationTitle("Features")
    }
}
