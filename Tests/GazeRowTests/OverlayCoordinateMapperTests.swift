import CoreGraphics
import XCTest
@testable import GazeRow

/// `OverlayCoordinateMapper`의 screen → target-window 로컬 좌표 변환 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayCoordinateMapperTests: XCTestCase {

    private func makeSUT(
        targetFrame: CGRect = CGRect(x: 100, y: 200, width: 300, height: 400)
    ) -> OverlayCoordinateMapper {
        OverlayCoordinateMapper(targetFrame: targetFrame)
    }

    func test_localBounds_origin은_zero이고_size는_targetFrame과_동일() {
        // given
        let sut = makeSUT()

        // when
        let bounds = sut.localBounds

        // then
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 300, height: 400))
    }

    func test_mapScreenFrameToLocal_targetFrame원점_기준으로_offset() {
        // given
        let sut = makeSUT()
        let screenFrame = CGRect(x: 150, y: 250, width: 10, height: 20)

        // when
        let local = sut.mapScreenFrameToLocal(screenFrame)

        // then
        XCTAssertEqual(local, CGRect(x: 50, y: 50, width: 10, height: 20))
    }

    func test_mapScreenPointToLocal_targetFrame원점_기준으로_offset() {
        // given
        let sut = makeSUT()
        let screenPoint = CGPoint(x: 150, y: 250)

        // when
        let local = sut.mapScreenPointToLocal(screenPoint)

        // then
        XCTAssertEqual(local, CGPoint(x: 50, y: 50))
    }

    func test_targetBoundaryFrame_localBounds와_동일() {
        // given
        let sut = makeSUT()

        // when
        let boundary = sut.targetBoundaryFrame()

        // then
        XCTAssertEqual(boundary, sut.localBounds)
    }

    func test_targetFrame이_원점이면_screen좌표_그대로_유지() {
        // given
        let sut = makeSUT(targetFrame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let screenPoint = CGPoint(x: 42, y: 84)

        // when
        let local = sut.mapScreenPointToLocal(screenPoint)

        // then
        XCTAssertEqual(local, screenPoint)
    }
}
