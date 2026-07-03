import CoreGraphics
import XCTest
@testable import GazeRow

/// GazeFocusController 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeFocusControllerTests: XCTestCase {

    func test_nearestItem_gazePoint에_가장가까운_item반환() {
        // given
        let sut = GazeFocusController()

        // when
        let item = sut.nearestItem(
            to: CGPoint(x: 102, y: 102),
            in: items
        )

        // then
        XCTAssertEqual(item?.id, 1)
    }

    func test_nearestItem_최대거리밖이면_nil() {
        // given
        let sut = GazeFocusController(maximumActivationDistance: 10)

        // when
        let item = sut.nearestItem(
            to: CGPoint(x: 300, y: 300),
            in: items
        )

        // then
        XCTAssertNil(item)
    }

    private var items: [FocusItem] {
        [
            FocusItem(id: 0, label: "A", frame: CGRect(x: 0, y: 0, width: 20, height: 20)),
            FocusItem(id: 1, label: "B", frame: CGRect(x: 95, y: 95, width: 20, height: 20))
        ]
    }
}
