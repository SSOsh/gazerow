import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayLabelPlacer 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
final class OverlayLabelPlacerTests: XCTestCase {

    func test_place_겹침이_없으면_후보_위쪽_모서리에_배치해_occlusion을_피함() {
        // given
        let sut = makePlacer()
        let candidate = CGRect(x: 100, y: 100, width: 40, height: 20)

        // when
        let frame = sut.place(over: candidate, placed: [], in: bounds)

        // then
        XCTAssertEqual(frame, CGRect(x: 100, y: 74, width: 30, height: 20))
        XCTAssertFalse(frame.intersects(candidate))
    }

    func test_place_같은_위치_후보는_이미_놓인_label과_겹치지_않게_배치() {
        // given
        let sut = makePlacer()
        let candidate = CGRect(x: 100, y: 100, width: 40, height: 20)
        let first = sut.place(over: candidate, placed: [], in: bounds)

        // when
        let second = sut.place(over: candidate, placed: [first], in: bounds)

        // then
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(first.intersects(second))
    }

    func test_place_작은_후보도_label이_후보를_가리지_않음() {
        // given
        let sut = makePlacer()
        let candidate = CGRect(x: 200, y: 200, width: 10, height: 10)

        // when
        let frame = sut.place(over: candidate, placed: [], in: bounds)

        // then
        XCTAssertFalse(frame.intersects(candidate))
    }

    func test_place_경계에서도_bounds_안으로_clamp() {
        // given
        let sut = makePlacer(edgeInset: 4)
        let candidate = CGRect(x: 0, y: 0, width: 10, height: 10)
        let smallBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

        // when
        let frame = sut.place(over: candidate, placed: [], in: smallBounds)

        // then
        XCTAssertGreaterThanOrEqual(frame.minX, 4)
        XCTAssertGreaterThanOrEqual(frame.minY, 4)
        XCTAssertLessThanOrEqual(frame.maxX, smallBounds.maxX - 4)
        XCTAssertLessThanOrEqual(frame.maxY, smallBounds.maxY - 4)
    }

    func test_place_shiftLimit이_0이고_모든_위치가_막히면_centered로_폴백() {
        // given
        let sut = makePlacer(edgeInset: 0, collisionShiftLimit: 0)
        let candidate = CGRect(x: 0, y: 0, width: 30, height: 20)
        let tightBounds = CGRect(x: 0, y: 0, width: 30, height: 20)
        let blocker = CGRect(x: 0, y: 0, width: 30, height: 20)

        // when
        let frame = sut.place(over: candidate, placed: [blocker], in: tightBounds)

        // then
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 30, height: 20))
        XCTAssertTrue(frame.intersects(blocker))
    }

    private var bounds: CGRect {
        CGRect(x: 0, y: 0, width: 400, height: 400)
    }

    private func makePlacer(
        edgeInset: CGFloat = 0,
        collisionShiftLimit: Int = 12
    ) -> OverlayLabelPlacer {
        OverlayLabelPlacer(
            labelSize: CGSize(width: 30, height: 20),
            labelSpacing: 6,
            edgeInset: edgeInset,
            collisionShiftLimit: collisionShiftLimit
        )
    }
}
