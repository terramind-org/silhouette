import SwiftUI
import XCTest
@testable import Silhouette

final class RevealTests: XCTestCase {
    private func context(shown: Double? = 0.5, height: CGFloat = 400, refetch: Bool = false, reduceMotion: Bool = false) -> RevealContext {
        RevealContext(skeletonShownFor: shown, size: CGSize(width: 300, height: height), isRefetch: refetch, reduceMotion: reduceMotion)
    }

    func testSmartIsInstantWhenTheSkeletonNeverShowed() {
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context(shown: nil)).duration, 0)
    }

    func testSmartCrossfadesSmallContentAndRefetches() {
        let small = SkeletonReveal.smart.resolved(for: context(height: 80))
        XCTAssertNil(small.wipe)
        guard case .together = small.order else { return XCTFail("small content should crossfade") }
        let refetch = SkeletonReveal.smart.resolved(for: context(refetch: true))
        guard case .together = refetch.order else { return XCTFail("a refetch should crossfade") }
    }

    func testSmartSequencesLargeContent() {
        guard case .sequence = SkeletonReveal.smart.resolved(for: context(height: 500)).order else {
            return XCTFail("large content should come in as a sequence")
        }
    }

    func testSmartHoldsFastDataBack() {
        XCTAssertEqual(SkeletonReveal.smart.hold, 0.15, accuracy: 0.001)
        // The hold survives `choose`, which picks only the reveal.
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context()).hold, 0.15, accuracy: 0.001)
    }

    func testDelaysAndDurationsStopAtOneSecond() {
        let slow = SkeletonReveal(delay: 4, duration: 9).resolved(for: context())
        XCTAssertEqual(slow.delay, 1)
        XCTAssertEqual(slow.duration, 1)
    }

    func testReduceMotionIsAPlainShortCrossfade() {
        var fancy = SkeletonReveal.sequence
        fancy.enter = .blur
        let calm = fancy.resolved(for: context(reduceMotion: true))
        XCTAssertEqual(calm.enter, .none)
        XCTAssertNil(calm.wipe)
        XCTAssertEqual(calm.duration, 0.2, accuracy: 0.001)
        guard case .together = calm.order else { return XCTFail() }
    }

    @MainActor
    func testSequenceMaskUncoversTopBeforeBottom() throws {
        let mask = try XCTUnwrap(RevealEffect.mask(spec: .sequence, progress: 0.4, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
        let first = mask.stops.first!.color.resolve(in: EnvironmentValues()).opacity
        let last = mask.stops.last!.color.resolve(in: EnvironmentValues()).opacity
        XCTAssertGreaterThan(first, last)
        XCTAssertEqual(mask.startPoint, .top)
    }

    @MainActor
    func testOutgoingMaskIsTheInverse() throws {
        let incoming = try XCTUnwrap(RevealEffect.mask(spec: .sweep, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
        let outgoing = try XCTUnwrap(RevealEffect.mask(spec: .sweep, progress: 0.5, role: .outgoing, shimmerAxis: CGVector(dx: 1, dy: 0)))
        for (a, b) in zip(incoming.stops, outgoing.stops) {
            let sum = a.color.resolve(in: EnvironmentValues()).opacity + b.color.resolve(in: EnvironmentValues()).opacity
            XCTAssertEqual(Double(sum), 1, accuracy: 0.01)
        }
    }

    @MainActor
    func testRevealEndsFullyUncovered() throws {
        for spec in [SkeletonReveal.sequence, .sweep] {
            let mask = try XCTUnwrap(RevealEffect.mask(spec: spec, progress: 1, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
            XCTAssertTrue(mask.stops.allSatisfy { $0.color.resolve(in: EnvironmentValues()).opacity > 0.99 })
        }
    }

    @MainActor
    func testTogetherIsAPlainCrossfade() {
        XCTAssertNil(RevealEffect.mask(spec: .together, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
    }

    @MainActor
    func testSweepFollowsTheShimmerDirection() throws {
        let down = try XCTUnwrap(RevealEffect.mask(spec: .sweep, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 0, dy: 1)))
        XCTAssertEqual(down.startPoint, UnitPoint(x: 0.5, y: 0))
        XCTAssertEqual(down.endPoint, UnitPoint(x: 0.5, y: 1))
    }
}
