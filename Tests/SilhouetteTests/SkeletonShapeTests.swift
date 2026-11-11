import SwiftUI
import XCTest
@testable import Silhouette

@MainActor
final class SkeletonShapeTests: XCTestCase {
    func testEachWrappedLineBecomesItsOwnBar() throws {
        let text = Text("The skeleton is traced from the real layout, one bar for each line it wraps to.")
            .font(.system(size: 20))
        let r = try Rendered(SkeletonShape(content: text.frame(maxWidth: .infinity, alignment: .leading)), size: CGSize(width: 200, height: 160))
        let bands = r.bands()
        XCTAssertGreaterThanOrEqual(bands.count, 3, "expected one bar per wrapped line, got \(bands)")
        // Bars are separated by the gap between lines, not merged into one block.
        for band in bands { XCTAssertLessThan(band.count, 30) }
    }

    func testTextBarsAreSolidEvenWhenTheTextIsFaint() throws {
        let text = Text("Faint secondary text").font(.system(size: 24)).foregroundStyle(.secondary.opacity(0.4))
        let r = try Rendered(SkeletonShape(content: text.frame(maxWidth: .infinity, alignment: .leading)), size: CGSize(width: 300, height: 40))
        let band = try XCTUnwrap(r.bands().first)
        let mid = CGFloat(band.lowerBound + band.upperBound) / 2
        XCTAssertEqual(r.alpha(at: CGPoint(x: 20, y: mid)), 1, accuracy: 0.05)
    }

    func testShapesAndTintedFillsBecomeBlocks() throws {
        let view = HStack(spacing: 20) {
            Circle().fill(.blue).frame(width: 40, height: 40)
            RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.4)).frame(width: 60, height: 40)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let r = try Rendered(SkeletonShape(content: view), size: CGSize(width: 200, height: 40))
        XCTAssertEqual(r.alpha(at: CGPoint(x: 20, y: 20)), 1, accuracy: 0.05, "circle centre")
        XCTAssertEqual(r.alpha(at: CGPoint(x: 1, y: 1)), 0, accuracy: 0.05, "outside the circle's corner")
        XCTAssertEqual(r.alpha(at: CGPoint(x: 90, y: 20)), 1, accuracy: 0.05, "a tinted chip draws a full block")
    }

    func testPageColouredSurfacesAreContainersNotBlocks() throws {
        for scheme in [ColorScheme.light, .dark] {
            let page: Color = scheme == .dark ? .black : .white
            let card = VStack(alignment: .leading) {
                Text("A line inside a card").font(.system(size: 22))
            }
            .frame(width: 260, height: 80, alignment: .topLeading)
            .background(page, in: RoundedRectangle(cornerRadius: 16))
            let r = try Rendered(SkeletonShape(content: card).environment(\.colorScheme, scheme), size: CGSize(width: 260, height: 80), colorScheme: scheme)
            XCTAssertEqual(r.alpha(at: CGPoint(x: 200, y: 60)), 0, accuracy: 0.05, "\(scheme): the card's own surface isn't traced")
            XCTAssertEqual(r.alpha(at: CGPoint(x: 20, y: 14)), 1, accuracy: 0.05, "\(scheme): its text is")
        }
    }

    func testCapHeightBarsAreShorterThanAscenderBars() throws {
        func barHeight(_ metrics: SkeletonTextMetrics) throws -> Int {
            let view = SkeletonShape(content: Text("Hxg").font(.system(size: 40)).frame(maxWidth: .infinity, alignment: .leading))
                .skeletonTheme { $0.text = metrics }
            return try XCTUnwrap(Rendered(view, size: CGSize(width: 120, height: 60)).bands().first).count
        }
        guard #available(iOS 18, macOS 15, *) else { throw XCTSkip("Text metrics need the iOS 18 text renderer") }
        let full = try barHeight(SkeletonTextMetrics(top: .ascender, bottom: .descender))
        let cap = try barHeight(SkeletonTextMetrics(top: .capHeight, bottom: .baseline))
        let x = try barHeight(SkeletonTextMetrics(top: .xHeight, bottom: .baseline))
        XCTAssertGreaterThan(full, cap)
        XCTAssertGreaterThan(cap, x)
    }
}
