import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayWindowOverviewLayoutEngine 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-26
final class OverlayWindowOverviewLayoutTests: XCTestCase {

    func test_makeLayout_일반화면_6개후보는_3열2행이다() {
        // given
        let sut = OverlayWindowOverviewLayoutEngine()

        // when
        let layout = sut.makeLayout(
            itemCount: 6,
            availableSize: CGSize(width: 1440, height: 900)
        )

        // then
        XCTAssertEqual(layout.columnCount, 3)
        XCTAssertEqual(layout.rowCount, 2)
        XCTAssertEqual(layout.cardSize.width, 421.333_333_333_333_3, accuracy: 0.001)
        XCTAssertEqual(layout.cardSize.height, layout.cardSize.width / 1.56, accuracy: 0.001)
    }

    func test_makeLayout_좁은화면은_최소카드폭을_지키도록_2열로줄인다() {
        // given
        let sut = OverlayWindowOverviewLayoutEngine()

        // when
        let layout = sut.makeLayout(
            itemCount: 6,
            availableSize: CGSize(width: 800, height: 600)
        )

        // then
        XCTAssertEqual(layout.columnCount, 2)
        XCTAssertEqual(layout.rowCount, 3)
        XCTAssertGreaterThanOrEqual(layout.cardSize.width, 260)
    }

    func test_makeLayout_넓은화면_후보7개이상은_최대4열이다() {
        // given
        let sut = OverlayWindowOverviewLayoutEngine()

        // when
        let layout = sut.makeLayout(
            itemCount: 10,
            availableSize: CGSize(width: 1920, height: 1080)
        )

        // then
        XCTAssertEqual(layout.columnCount, 4)
        XCTAssertEqual(layout.rowCount, 3)
    }

    func test_makeLayout_후보가없으면_빈행과_안전한1열을반환한다() {
        // given
        let sut = OverlayWindowOverviewLayoutEngine()

        // when
        let layout = sut.makeLayout(
            itemCount: 0,
            availableSize: .zero
        )

        // then
        XCTAssertEqual(layout.columnCount, 1)
        XCTAssertEqual(layout.rowCount, 0)
        XCTAssertEqual(layout.cardSize, CGSize(width: 1, height: 1 / 1.56))
    }

    func test_makeLayout_후보1개는_1열1행이다() {
        // given
        let sut = OverlayWindowOverviewLayoutEngine()

        // when
        let layout = sut.makeLayout(
            itemCount: 1,
            availableSize: CGSize(width: 1440, height: 900)
        )

        // then
        XCTAssertEqual(layout.columnCount, 1)
        XCTAssertEqual(layout.rowCount, 1)
    }
}
