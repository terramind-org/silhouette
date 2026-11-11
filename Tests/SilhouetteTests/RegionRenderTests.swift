import SwiftUI
import XCTest
@testable import Silhouette

private struct Profile {
    var name: String
    var bio: String
    static let sample = Profile(name: "Sample Person", bio: "A typical length of bio, long enough to wrap onto a second line.")
}

private struct ProfileCard: View {
    var profile: Profile
    var avatar: Color = .orange
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(avatar).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name).font(.headline)
                Text(profile.bio).font(.subheadline)
            }
        }
        .frame(width: 280, alignment: .topLeading)
    }
}

@MainActor
final class RegionRenderTests: XCTestCase {
    /// The skeleton layer is the content's own shape: drawn where the avatar and lines are, and
    /// empty between them.
    func testSkeletonLayerFollowsTheContent() throws {
        let card = ProfileCard(profile: .sample)
        let layer = ShimmerFill()
            .skeletonTheme { $0.animation = .none; $0.light = SkeletonColors(base: .black, highlight: .clear) }
            .mask { SkeletonShape(content: card) }
        let r = try Rendered(ZStack(alignment: .topLeading) { card.opacity(0); layer }, size: CGSize(width: 280, height: 90))
        XCTAssertGreaterThan(r.alpha(at: CGPoint(x: 22, y: 22)), 0.9, "avatar block")
        XCTAssertEqual(r.alpha(at: CGPoint(x: 52, y: 30)), 0, accuracy: 0.05, "the gutter between avatar and text")
        // Down the text column, the name and each bio line are separate bars.
        let column = (0..<90).map { r.alpha(at: CGPoint(x: 120, y: Double($0) + 0.5)) > 0.5 }
        let bars = zip(column, column.dropFirst()).filter { !$0 && $1 }.count + (column.first == true ? 1 : 0)
        XCTAssertGreaterThanOrEqual(bars, 3, "separate bars, not one block")
    }

    /// While loading, the real content is drawn invisibly: only the skeleton shows.
    ///
    /// Named to run before any test that renders visible content: on macOS 27, ImageRenderer
    /// draws a view under `.opacity(0)` once it has drawn a visible view in the same process.
    func testHiddenWhileLoading() throws {
        let loading = ProfileCard(profile: .sample, avatar: .purple)
            .skeleton(isLoading: true)
            .skeletonTheme { $0.animation = .none; $0.light = SkeletonColors(base: .clear, highlight: .clear) }
        let r = try Rendered(loading, size: CGSize(width: 280, height: 90))
        XCTAssertEqual(r.alpha(at: CGPoint(x: 22, y: 22)), 0, accuracy: 0.05)
    }

    func testLoadedShowsTheContent() throws {
        let loaded = ProfileCard(profile: .sample, avatar: .teal).skeleton(isLoading: false)
        let r = try Rendered(loaded, size: CGSize(width: 280, height: 90))
        XCTAssertGreaterThan(r.alpha(at: CGPoint(x: 22, y: 22)), 0.9)
    }

    func testSkeletonBoxSizes() throws {
        let box = SkeletonBox(width: .fraction(0.5), height: 20)
            .skeletonTheme { $0.animation = .none; $0.light = SkeletonColors(base: .black, highlight: .clear) }
            .frame(width: 200, height: 40, alignment: .topLeading)
        let r = try Rendered(box, size: CGSize(width: 200, height: 40))
        XCTAssertEqual(r.coveredWidth(row: 10), 100, accuracy: 2)
        XCTAssertEqual(r.alpha(at: CGPoint(x: 50, y: 30)), 0, accuracy: 0.05)
    }

    func testHintsReplaceAndIgnore() throws {
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("Ignored").font(.system(size: 30)).skeletonIgnored()
            Text("Block").font(.system(size: 30)).frame(width: 200, height: 40, alignment: .leading).skeletonBlock()
        }
        .frame(width: 200, height: 80, alignment: .topLeading)
        let r = try Rendered(SkeletonShape(content: view), size: CGSize(width: 200, height: 80))
        XCTAssertEqual(r.coveredWidth(row: 20), 0, "ignored text leaves no bar")
        XCTAssertEqual(r.coveredWidth(row: 60), 200, accuracy: 1, "a block fills its frame")
    }
}
