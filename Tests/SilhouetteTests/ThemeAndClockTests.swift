import SwiftUI
import XCTest
@testable import Silhouette

final class ThemeAndClockTests: XCTestCase {
    func testPhaseComesFromTheWallClockSoLateSkeletonsJoinInStep() {
        let date = Date(timeIntervalSinceReferenceDate: 1000.425)
        // Two skeletons asking at the same moment get the same phase, whenever they appeared.
        XCTAssertEqual(SkeletonClock.phase(at: date, period: 1.7), SkeletonClock.phase(at: date, period: 1.7))
        XCTAssertEqual(SkeletonClock.phase(at: Date(timeIntervalSinceReferenceDate: 17), period: 1.7), 0, accuracy: 1e-9)
        XCTAssertEqual(SkeletonClock.phase(at: Date(timeIntervalSinceReferenceDate: 17.85), period: 1.7), 0.5, accuracy: 1e-9)
    }

    func testPulseBreathesBetweenZeroAndOne() {
        XCTAssertEqual(SkeletonClock.pulse(at: Date(timeIntervalSinceReferenceDate: 0), period: 2), 0, accuracy: 1e-9)
        XCTAssertEqual(SkeletonClock.pulse(at: Date(timeIntervalSinceReferenceDate: 1), period: 2), 1, accuracy: 1e-9)
    }

    func testSpeedsMatchSkullet() {
        XCTAssertEqual(SkeletonSpeed.slow.shimmerLoop, 4)
        XCTAssertEqual(SkeletonSpeed.fast.shimmerLoop, 2)
        XCTAssertEqual(SkeletonSpeed.slow.pulseLoop, 2.4)
        XCTAssertEqual(SkeletonSpeed.fast.pulseLoop, 1.2)
        XCTAssertEqual(SkeletonSpeed.seconds(0.01).shimmerLoop, 0.2, "a loop never collapses to nothing")
    }

    func testShimmerKeepsOnePaceOnAnyWidth() {
        // One loop crosses a 1280-point screen in 70% of its time, whatever the screen's width.
        XCTAssertEqual(ShimmerFill.pace(speed: .slow), 1280 / (0.7 * 4), accuracy: 1e-6)
        XCTAssertEqual(ShimmerFill.pace(speed: .fast), 2 * ShimmerFill.pace(speed: .slow), accuracy: 1e-6)
    }

    func testDirectionsFollowTheLayoutDirection() {
        let ltr = ShimmerDirection.leadingToTrailing.unitVector(layoutDirection: .leftToRight)
        let rtl = ShimmerDirection.leadingToTrailing.unitVector(layoutDirection: .rightToLeft)
        XCTAssertEqual(ltr.dx, 1, accuracy: 1e-9)
        XCTAssertEqual(rtl.dx, -1, accuracy: 1e-9)
        XCTAssertEqual(ShimmerDirection.topToBottom.unitVector(layoutDirection: .leftToRight).dy, 1, accuracy: 1e-9)
    }

    func testRadii() {
        XCTAssertEqual(SkeletonRadius.pill.value(forHeight: 20), 10)
        XCTAssertEqual(SkeletonRadius.points(30).value(forHeight: 20), 10, "never rounder than a pill")
        XCTAssertGreaterThan(SkeletonRadius.auto.value(forHeight: 20), 0)
        XCTAssertLessThan(SkeletonRadius.auto.value(forHeight: 20), 10)
    }

    func testColorsFollowTheSchemeUnlessForced() {
        var theme = SkeletonTheme()
        XCTAssertEqual(theme.colors(for: .dark), theme.dark)
        theme.colorScheme = .light
        XCTAssertEqual(theme.colors(for: .dark), theme.light)
    }

    func testFontRatiosOrderCapAboveXHeight() {
        XCTAssertGreaterThan(FontRatios.capHeight, FontRatios.xHeight)
        XCTAssertLessThan(FontRatios.capHeight, 1)
    }
}
