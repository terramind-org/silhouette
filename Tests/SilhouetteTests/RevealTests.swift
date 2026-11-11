import SwiftUI
import XCTest
@testable import Silhouette

final class RevealTests: XCTestCase {
    private func context(shown: Double? = 0.5, height: CGFloat = 400, pieces: Int = 12, refetch: Bool = false, interacting: Bool = false, reduceMotion: Bool = false) -> RevealContext {
        RevealContext(skeletonShownFor: shown, size: CGSize(width: 300, height: height), pieces: pieces, isRefetch: refetch, isInteracting: interacting, reduceMotion: reduceMotion)
    }

    private func isTogether(_ spec: SkeletonReveal) -> Bool {
        if case .together = spec.order { return spec.wipe == nil }
        return false
    }

    // MARK: smart

    func testSmartIsInstantWhenTheSkeletonNeverShowedOrSomeoneIsScrolling() {
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context(shown: nil)).duration, 0)
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context(interacting: true)).duration, 0)
    }

    func testSmartQuicklyCrossfadesARefetch() {
        let spec = SkeletonReveal.smart.resolved(for: context(refetch: true))
        XCTAssertTrue(isTogether(spec))
        XCTAssertEqual(spec.duration, 0.12, accuracy: 0.001)
    }

    func testSmartRevealsSmallContentWhole() {
        XCTAssertTrue(isTogether(SkeletonReveal.smart.resolved(for: context(height: 60))))
        XCTAssertTrue(isTogether(SkeletonReveal.smart.resolved(for: context(pieces: 3))))
    }

    func testSmartCascadesLargeContentByRow() {
        XCTAssertTrue(SkeletonReveal.smart.resolved(for: context()).isOrdered)
    }

    func testSmartHoldsFastDataBack() {
        XCTAssertEqual(SkeletonReveal.smart.hold, 0.15, accuracy: 0.001)
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context()).hold, 0.15, accuracy: 0.001)
    }

    func testDelaysAndDurationsStopAtOneSecond() {
        let slow = SkeletonReveal(delay: 4, duration: 9).resolved(for: context())
        XCTAssertEqual(slow.delay, 1)
        XCTAssertEqual(slow.duration, 1)
    }

    func testReduceMotionIsInstant() {
        var fancy = SkeletonReveal.sequence
        fancy.enter = .blur
        XCTAssertEqual(fancy.resolved(for: context(reduceMotion: true)).duration, 0)
    }

    // MARK: Orders

    private let screen = CGRect(x: 0, y: 0, width: 400, height: 800)

    private func piece(_ rect: CGRect, unit: CGRect? = nil, secondary: Bool = false, late: Double = 0) -> RevealPiece {
        RevealPiece(rect: rect, reveal: CGRect(x: 0, y: 100, width: 400, height: 400), unit: unit, isSecondary: secondary, late: late, screen: screen)
    }

    func testByPositionGoesDownThenAcrossOverThreeHundredTwentyMilliseconds() throws {
        let top = try XCTUnwrap(RevealPiece.byPosition(piece(CGRect(x: 0, y: 100, width: 50, height: 10))))
        let lower = try XCTUnwrap(RevealPiece.byPosition(piece(CGRect(x: 0, y: 300, width: 50, height: 10))))
        let right = try XCTUnwrap(RevealPiece.byPosition(piece(CGRect(x: 200, y: 100, width: 50, height: 10))))
        let last = try XCTUnwrap(RevealPiece.byPosition(piece(CGRect(x: 400, y: 500, width: 50, height: 10))))
        XCTAssertEqual(top, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(lower, right, "down counts four times as much as across")
        XCTAssertEqual(last, 0.32, accuracy: 1e-9)
    }

    func testByRowTimesRowsByTheScreenSoRegionsCascadeTogether() throws {
        let row = CGRect(x: 0, y: 400, width: 400, height: 40)
        let main = try XCTUnwrap(RevealPiece.byRow(piece(CGRect(x: 0, y: 400, width: 200, height: 16), unit: row)))
        let caption = try XCTUnwrap(RevealPiece.byRow(piece(CGRect(x: 0, y: 420, width: 120, height: 10), unit: row, secondary: true)))
        XCTAssertEqual(main, 0.16, accuracy: 1e-9, "halfway down the screen, halfway through the cascade")
        XCTAssertEqual(caption - main, 0.06, accuracy: 1e-9, "smaller text a beat behind")
        let lateJoiner = try XCTUnwrap(RevealPiece.byRow(piece(CGRect(x: 0, y: 400, width: 200, height: 16), unit: row, late: 0.1)))
        XCTAssertEqual(lateJoiner, 0.06, accuracy: 1e-9, "a reveal landing later joins the cascade where it has got to")
    }

    func testByRowShowsOffScreenRowsAtOnce() {
        let below = CGRect(x: 0, y: 900, width: 400, height: 40)
        XCTAssertNil(RevealPiece.byRow(piece(below, unit: below)))
    }

    // MARK: Plans

    func testUnitsGroupPiecesThatSitTogether() {
        let avatar = CGRect(x: 0, y: 0, width: 40, height: 40)
        let name = CGRect(x: 50, y: 4, width: 120, height: 14)
        let handle = CGRect(x: 50, y: 22, width: 80, height: 10)
        let bio = CGRect(x: 0, y: 60, width: 300, height: 14)
        let units = PieceTracer.units(of: [avatar, name, handle, bio])
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(units[0], avatar.union(name).union(handle))
    }

    func testPlanTimesEachPieceAndMarksSmallerText() throws {
        let name = CGRect(x: 50, y: 4, width: 120, height: 16)
        let handle = CGRect(x: 50, y: 24, width: 80, height: 10)
        let plan = RevealPlan.make(
            order: RevealPiece.byRow, content: [name, handle], skeleton: [name, handle],
            region: CGRect(x: 0, y: 0, width: 300, height: 40), screen: screen, late: 0, delay: 0, fade: 0.2
        )
        let nameDelay = try XCTUnwrap(plan.incoming[0].delay)
        let handleDelay = try XCTUnwrap(plan.incoming[1].delay)
        XCTAssertEqual(handleDelay - nameDelay, 0.06, accuracy: 1e-9)
        XCTAssertEqual(plan.end, handleDelay + 0.2, accuracy: 1e-9)
        XCTAssertEqual(plan.amount(plan.incoming[0], at: nameDelay), 0, accuracy: 1e-9)
        XCTAssertEqual(plan.amount(plan.incoming[0], at: nameDelay + 0.2), 1, accuracy: 1e-9)
    }

    func testEaseMatchesCSS() {
        XCTAssertEqual(RevealPlan.ease(0), 0, accuracy: 1e-6)
        XCTAssertEqual(RevealPlan.ease(1), 1, accuracy: 1e-6)
        XCTAssertGreaterThan(RevealPlan.ease(0.5), 0.75, "ease front-loads the change")
    }

    @MainActor
    func testBatchJoinsRevealsLandingTogether() {
        let t0 = Date(timeIntervalSinceReferenceDate: 10_000)
        XCTAssertEqual(RevealBatch.join(at: t0), 0)
        XCTAssertEqual(RevealBatch.join(at: t0.addingTimeInterval(0.1)), 0.1, accuracy: 1e-9)
        XCTAssertEqual(RevealBatch.join(at: t0.addingTimeInterval(0.5)), 0, "a later reveal starts a new cascade")
    }

    @MainActor
    func testPiecesAreTracedFromTheRealLayout() {
        let card = HStack(alignment: .top, spacing: 12) {
            Circle().fill(.orange).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ada Lovelace").font(.system(size: 17, weight: .semibold))
                Text("Analyst").font(.system(size: 13))
            }
        }
        .padding(8)
        .frame(width: 260, height: 70, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        let pieces = PieceTracer.pieces(of: card, size: CGSize(width: 260, height: 70), environment: EnvironmentValues())
        XCTAssertEqual(pieces.count, 3, "avatar, name and role: \(pieces)")
        XCTAssertEqual(pieces.first?.width ?? 0, 40, accuracy: 2)
    }

    // MARK: Wipes

    @MainActor
    func testOutgoingWipeIsTheInverse() throws {
        let incoming = try XCTUnwrap(WipeEffect.mask(spec: .sweep, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
        let outgoing = try XCTUnwrap(WipeEffect.mask(spec: .sweep, progress: 0.5, role: .outgoing, shimmerAxis: CGVector(dx: 1, dy: 0)))
        for (a, b) in zip(incoming.stops, outgoing.stops) {
            let sum = a.color.resolve(in: EnvironmentValues()).opacity + b.color.resolve(in: EnvironmentValues()).opacity
            XCTAssertEqual(Double(sum), 1, accuracy: 0.01)
        }
    }

    @MainActor
    func testSweepEndsFullyUncoveredAndFollowsTheShimmer() throws {
        let done = try XCTUnwrap(WipeEffect.mask(spec: .sweep, progress: 1, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
        XCTAssertTrue(done.stops.allSatisfy { $0.color.resolve(in: EnvironmentValues()).opacity > 0.99 })
        let down = try XCTUnwrap(WipeEffect.mask(spec: .sweep, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 0, dy: 1)))
        XCTAssertEqual(down.startPoint, UnitPoint(x: 0.5, y: 0))
    }

    @MainActor
    func testTogetherHasNoWipe() {
        XCTAssertNil(WipeEffect.mask(spec: .together, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
    }
}
