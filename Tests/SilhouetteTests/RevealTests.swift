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

    func testSmartCascadesEverythingThatShowedASkeleton() {
        // Small, refetched or large, a reveal that had a skeleton comes in row by row: never a
        // crossfade, so the skeleton and the content never show at once in one place.
        XCTAssertTrue(SkeletonReveal.smart.resolved(for: context()).isOrdered)
        XCTAssertTrue(SkeletonReveal.smart.resolved(for: context(height: 60, pieces: 2)).isOrdered)
        XCTAssertTrue(SkeletonReveal.smart.resolved(for: context(refetch: true)).isOrdered)
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context()).duration, 0.3, accuracy: 1e-9)
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

    private func piece(_ rect: CGRect, row: Int = 0, rows: Int = 10, regionRow: Int = 0, regionRows: Int = 4) -> RevealPiece {
        RevealPiece(rect: rect, reveal: CGRect(x: 0, y: 100, width: 400, height: 400), unit: rect, isSecondary: false,
                    row: row, rows: rows, regionRow: regionRow, regionRows: regionRows, screen: screen)
    }

    func testByRowGivesEachRowItsOwnBeat() throws {
        let rect = CGRect(x: 0, y: 300, width: 200, height: 16)
        XCTAssertEqual(try XCTUnwrap(RevealPiece.byRow(piece(rect, row: 0))), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(RevealPiece.byRow(piece(rect, row: 3))), 0.12, accuracy: 1e-9, "40 ms apart")
    }

    func testALongPageTightensTheBeatSoTheCascadeStaysUnderASecond() throws {
        let rect = CGRect(x: 0, y: 300, width: 200, height: 16)
        let last = try XCTUnwrap(RevealPiece.byRow(piece(rect, row: 29, rows: 30)))
        XCTAssertEqual(last, 0.45, accuracy: 1e-9)
    }

    func testByRowShowsOffScreenRowsAtOnce() {
        XCTAssertNil(RevealPiece.byRow(piece(CGRect(x: 0, y: 900, width: 400, height: 40))))
    }

    func testByPositionCascadesWithinTheRegion() throws {
        let rect = CGRect(x: 0, y: 300, width: 200, height: 16)
        XCTAssertEqual(try XCTUnwrap(RevealPiece.byPosition(piece(rect, regionRow: 2))), 0.08, accuracy: 1e-9)
    }

    // MARK: Plans

    func testRowsMergeAnAvatarWithItsNameButKeepParagraphLinesApart() {
        let avatar = CGRect(x: 0, y: 0, width: 40, height: 40)
        let name = CGRect(x: 50, y: 4, width: 120, height: 14)
        let handle = CGRect(x: 50, y: 22, width: 80, height: 10)
        let line1 = CGRect(x: 0, y: 60, width: 300, height: 14)
        let line2 = CGRect(x: 0, y: 78, width: 260, height: 14)
        let rows = Rows.of([avatar, name, handle, line1, line2])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], avatar.union(name).union(handle))
        XCTAssertEqual(Rows.index(of: line2, in: rows), 2)
    }

    func testOnePageCascadesTopToBottomAcrossRegions() throws {
        // Two cards landing together: the lower card's rows come after every row of the upper.
        let upper = CGRect(x: 0, y: 100, width: 300, height: 60)
        let lower = CGRect(x: 0, y: 200, width: 300, height: 60)
        let upperPieces = [CGRect(x: 10, y: 10, width: 200, height: 14), CGRect(x: 10, y: 34, width: 180, height: 14)]
        let lowerPieces = [CGRect(x: 10, y: 10, width: 200, height: 14), CGRect(x: 10, y: 34, width: 180, height: 14)]
        let page = Rows.of(upperPieces.map { $0.offsetBy(dx: upper.minX, dy: upper.minY) } + lowerPieces.map { $0.offsetBy(dx: lower.minX, dy: lower.minY) })
        let a = RevealPlan.make(order: RevealPiece.byRow, content: upperPieces, skeleton: upperPieces, region: upper, screen: screen, pageRows: page, delay: 0, fade: 0.25)
        let b = RevealPlan.make(order: RevealPiece.byRow, content: lowerPieces, skeleton: lowerPieces, region: lower, screen: screen, pageRows: page, delay: 0, fade: 0.25)
        let upperDelays = a.incoming.compactMap(\.delay), lowerDelays = b.incoming.compactMap(\.delay)
        XCTAssertEqual(upperDelays, [0, 0.04])
        XCTAssertEqual(lowerDelays, [0.08, 0.12])
        XCTAssertEqual(b.end, 0.12 + 0.25, accuracy: 1e-9)
        // A bar and the line that replaces it share their timing exactly.
        XCTAssertEqual(a.incoming.map(\.delay), a.outgoing.map(\.delay))
    }

    func testEaseMatchesCSS() {
        XCTAssertEqual(RevealPlan.ease(0), 0, accuracy: 1e-6)
        XCTAssertEqual(RevealPlan.ease(1), 1, accuracy: 1e-6)
        XCTAssertGreaterThan(RevealPlan.ease(0.5), 0.75, "ease front-loads the change")
    }

    @MainActor
    func testRevealsLandingTogetherWaitAndShareOneSetOfRows() async {
        async let first = RevealBatch.join([CGRect(x: 0, y: 0, width: 10, height: 10)])
        async let second = RevealBatch.join([CGRect(x: 0, y: 50, width: 10, height: 10)])
        let (a, b) = await (first, second)
        XCTAssertEqual(a.count, 2)
        XCTAssertEqual(a, b)
    }

    @MainActor
    func testTheWipeNeverShowsTheBarAndTheLineAtOnce() throws {
        // Halfway through a line's wipe: on every pixel of the line, the content and its
        // skeleton add up to one, and neither is half visible except along the soft edge.
        let line = CGRect(x: 20, y: 20, width: 200, height: 16)
        var plan = RevealPlan(incoming: [.init(rect: line, delay: 0)], outgoing: [.init(rect: line, delay: 0)], fade: 10, start: Date())
        plan.clock = RevealClock(fixed: 4.5)
        let size = CGSize(width: 240, height: 56)
        let incoming = try Rendered(RevealMask(role: .incoming, progress: 1, spec: .sequence, plan: plan, shimmerAxis: CGVector(dx: 1, dy: 0)), size: size)
        let outgoing = try Rendered(RevealMask(role: .outgoing, progress: 1, spec: .sequence, plan: plan, shimmerAxis: CGVector(dx: 1, dy: 0)).padding(0.01), size: size)
        var both = 0
        for x in stride(from: 21.0, to: 219.0, by: 2) {
            let a = incoming.alpha(at: CGPoint(x: x, y: 28)), b = outgoing.alpha(at: CGPoint(x: x, y: 28))
            XCTAssertEqual(a + b, 1, accuracy: 0.08, "at x \(x)")
            if a > 0.1 && b > 0.1 { both += 1 }
        }
        XCTAssertLessThanOrEqual(both, 26, "only the soft edge, about 48 pt, is shared")
        XCTAssertGreaterThan(incoming.alpha(at: CGPoint(x: 30, y: 28)), 0.95, "the leading end is in")
        XCTAssertLessThan(incoming.alpha(at: CGPoint(x: 210, y: 28)), 0.05, "the trailing end isn't yet")
    }

    @MainActor
    func testAWaitingLineHidesOnlyItsInkNotTheCardBehindIt() throws {
        // The line's ink covers half its height; before its wipe, the ink is hidden and the rest
        // of the line's area (the card's surface) stays visible.
        let line = CGRect(x: 20, y: 20, width: 200, height: 16)
        let inkRect = CGRect(x: 20, y: 24, width: 200, height: 8)
        let size = CGSize(width: 240, height: 56)
        let content = Canvas { context, _ in context.fill(Path(inkRect), with: .color(.black)) }
        var plan = RevealPlan.make(order: { _ in 5 }, content: [line], skeleton: [line], region: CGRect(origin: .zero, size: size),
                                   screen: screen, pageRows: [line], delay: 0, fade: 0.25)
        var env = EnvironmentValues()
        env.colorScheme = .light
        plan.ink = PieceTracer.ink(of: content, size: size, environment: env, scale: 2)
        plan.inkSize = size
        plan.start = Date()
        let mask = try Rendered(RevealMask(role: .incoming, progress: 1, spec: .sequence, plan: plan, shimmerAxis: CGVector(dx: 1, dy: 0)).padding(0.02), size: size)
        XCTAssertLessThan(mask.alpha(at: CGPoint(x: 100, y: 28)), 0.05, "the waiting ink is hidden")
        XCTAssertGreaterThan(mask.alpha(at: CGPoint(x: 100, y: 17)), 0.95, "the surface around it isn't")
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
    func testACustomWipeCanGiveTheSkeletonItsOwnMask() throws {
        let spec = SkeletonReveal(wipe: .custom({ _ in .init(stops: [.init(color: .black, location: 0)]) }, outgoing: { _ in .init(stops: [.init(color: .clear, location: 0.5)]) }))
        let out = try XCTUnwrap(WipeEffect.mask(spec: spec, progress: 0.3, role: .outgoing, shimmerAxis: CGVector(dx: 1, dy: 0)))
        XCTAssertEqual(out.stops.first?.location, 0.5)
    }

    @MainActor
    func testTogetherHasNoWipe() {
        XCTAssertNil(WipeEffect.mask(spec: .together, progress: 0.5, role: .incoming, shimmerAxis: CGVector(dx: 1, dy: 0)))
    }

    @MainActor
    func testARaisedDarkSurfaceIsntTracedButATintIs() throws {
        for (fill, traced) in [(Color(white: 0.105), false), (Color.green.opacity(0.4), true)] {
            let view = fill.frame(width: 60, height: 40).frame(width: 80, height: 40)
            let r = try Rendered(SkeletonShape(content: view).environment(\.colorScheme, .dark), size: CGSize(width: 80, height: 40), colorScheme: .dark)
            XCTAssertEqual(r.alpha(at: CGPoint(x: 30, y: 20)), traced ? 1 : 0, accuracy: 0.05, "\(fill)")
        }
    }

    @MainActor
    func testALaterBatchNeverStartsAboveALineStillWaiting() async {
        // An earlier batch's cascade is still on its way down when a reveal lower on the page
        // lands: that reveal waits for the line above it.
        let region = CGRect(x: 0, y: 0, width: 300, height: 400)
        let first = [CGRect(x: 0, y: 0, width: 200, height: 14), CGRect(x: 0, y: 200, width: 200, height: 14)]
        let (rows, a) = await RevealBatch.joinBatch(first)
        var early = RevealPlan.make(order: RevealPiece.byRow, content: first, skeleton: first, region: region, screen: screen, pageRows: rows, delay: 0, fade: 0.25)
        RevealBatch.queue(&early, region: region, batch: a)
        let late = [CGRect(x: 0, y: 300, width: 200, height: 14)]
        let (lateRows, b) = await RevealBatch.joinBatch(late)
        var next = RevealPlan.make(order: RevealPiece.byRow, content: late, skeleton: late, region: region, screen: screen, pageRows: lateRows, delay: 0, fade: 0.25)
        RevealBatch.queue(&next, region: region, batch: b)
        let lineAbove = early.start.addingTimeInterval(early.incoming[1].delay ?? 0)
        let lineBelow = next.start.addingTimeInterval(next.incoming[0].delay ?? 0)
        XCTAssertGreaterThan(lineBelow.timeIntervalSince(lineAbove), 0.05)
    }

    func testAStallSlowsTheCascadeRatherThanSkippingIt() {
        let clock = RevealClock()
        let start = Date()
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(1 / 60), start: start), 1 / 60, accuracy: 0.001)
        // Half a second without a frame drawn moves the cascade on by one short step, not half a second.
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(0.5), start: start), 1 / 60 + RevealClock.longestStep, accuracy: 0.001)
        // Frames drawn on time keep time.
        XCTAssertEqual(clock.time(at: start.addingTimeInterval(0.5 + 1 / 60), start: start), 2 / 60 + RevealClock.longestStep, accuracy: 0.001)
    }

    func testTheTestingSwitchMakesEveryRevealInstant() {
        UserDefaults.standard.set(true, forKey: "SilhouetteInstant")
        defer { UserDefaults.standard.removeObject(forKey: "SilhouetteInstant") }
        let context = RevealContext(skeletonShownFor: 2, size: CGSize(width: 300, height: 200), isRefetch: false, isInteracting: false, reduceMotion: false)
        XCTAssertEqual(SkeletonReveal.smart.resolved(for: context).duration, 0)
        XCTAssertEqual(ShimmerFill.animation(for: SkeletonTheme(), reduceMotion: false), SkeletonAnimation.none)
    }

    func testAWipeEffectIsAskedForEachMoment() {
        let wipe = SkeletonReveal.Wipe.custom({ _ in .init(stops: []) }, effect: { p in .init(blur: 8 * (1 - p)) })
        guard case .custom(_, _, let effect?) = wipe else { return XCTFail("no effect") }
        XCTAssertEqual(effect(0).blur, 8)
        XCTAssertEqual(effect(1).blur, 0)
        XCTAssertEqual(SkeletonReveal.Enter.unveil.clip, .top)
    }

    func testAModifiersContentIsKnownToBeUntraceable() {
        struct Wrap: ViewModifier { func body(content: Content) -> some View { content } }
        XCTAssertTrue(SkeletonRegion<_ViewModifier_Content<Wrap>, EmptyView>.isProxy(_ViewModifier_Content<Wrap>.self))
        XCTAssertFalse(SkeletonRegion<Text, EmptyView>.isProxy(Text.self))
    }

    @MainActor
    func testRegionsArrivingTogetherShareABatchHoweverLongTheyTakeToTrace() async {
        let first = RevealBatch.reserve()
        let second = RevealBatch.reserve()
        XCTAssertTrue(first === second)
        async let a = first.join([CGRect(x: 0, y: 0, width: 10, height: 10)])
        // The second region spends longer than the window tracing before it arrives.
        try? await Task.sleep(for: .seconds(0.3))
        let b = await second.join([CGRect(x: 0, y: 400, width: 10, height: 10)])
        let rowsA = await a
        XCTAssertEqual(rowsA.count, 2)
        XCTAssertEqual(rowsA, b)
    }
}
