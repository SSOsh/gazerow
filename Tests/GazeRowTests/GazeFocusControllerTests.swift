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

    func test_nearestItem_히스테리시스_margin안이면_현재focus유지() {
        // given: A(mid 50,50), B(mid 60,50). gaze(56,50) → B가 더 가깝지만 차이는 2pt.
        let sut = GazeFocusController(hysteresisMargin: 10)
        let a = FocusItem(id: 0, label: "A", frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        let b = FocusItem(id: 1, label: "B", frame: CGRect(x: 50, y: 40, width: 20, height: 20))

        // when
        let item = sut.nearestItem(to: CGPoint(x: 56, y: 50), in: [a, b], current: a)

        // then: margin(10) 안이라 현재 focus(A) 유지
        XCTAssertEqual(item?.id, 0)
    }

    func test_nearestItem_히스테리시스_margin밖이면_새후보로전환() {
        // given
        let sut = GazeFocusController(hysteresisMargin: 10)
        let a = FocusItem(id: 0, label: "A", frame: CGRect(x: 40, y: 40, width: 20, height: 20))
        let b = FocusItem(id: 1, label: "B", frame: CGRect(x: 50, y: 40, width: 20, height: 20))

        // when: gaze가 B 중심(60,50)에 붙어 차이가 margin을 넘음
        let item = sut.nearestItem(to: CGPoint(x: 62, y: 50), in: [a, b], current: a)

        // then
        XCTAssertEqual(item?.id, 1)
    }

    func test_nearestItem_현재focus가_최대거리밖이면_관성없이_전환() {
        // given
        let sut = GazeFocusController(maximumActivationDistance: 30, hysteresisMargin: 100)
        let a = FocusItem(id: 0, label: "A", frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        let b = FocusItem(id: 1, label: "B", frame: CGRect(x: 90, y: 90, width: 20, height: 20))

        // when: gaze는 B 근처, 현재 focus(A)는 최대거리 밖
        let item = sut.nearestItem(to: CGPoint(x: 100, y: 100), in: [a, b], current: a)

        // then: 관성을 풀고 B로 전환
        XCTAssertEqual(item?.id, 1)
    }

    private var items: [FocusItem] {
        [
            FocusItem(id: 0, label: "A", frame: CGRect(x: 0, y: 0, width: 20, height: 20)),
            FocusItem(id: 1, label: "B", frame: CGRect(x: 95, y: 95, width: 20, height: 20))
        ]
    }
}
